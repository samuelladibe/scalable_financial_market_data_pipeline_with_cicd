# terraform/ecs.tf

# =================================================================
# ECS INFRASTRUCTURE DEFINITIONS
# =================================================================

# 1. ECR Repository for Django app image (kept from your original file)
resource "aws_ecr_repository" "app_repo" {
  name                 = "financial-pipeline-app-repo"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

# 2. ECS Cluster (kept from your original file)
resource "aws_ecs_cluster" "main_cluster" {
  name = "financial-pipeline-cluster"
}

# Assume other ECR repositories are defined here or referenced from output.tf
resource "aws_ecr_repository" "scheduler_repo" { name = "financial-pipeline-scheduler-repo" }
resource "aws_ecr_repository" "prometheus_repo" { name = "prometheus-repo" }
resource "aws_ecr_repository" "grafana_repo" { name = "grafana-repo" }
resource "aws_ecr_repository" "db_repo" { name = "financial-pipeline-db-repo" }
resource "aws_ecr_repository" "redis_repo" { name = "financial-pipeline-redis-repo" }


# =================================================================
# 1. FINANCIAL PIPELINE APP SERVICE (API/Web)
# =================================================================
resource "aws_ecs_task_definition" "financial_app_task" {
  family                   = "financial-app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"] # Using FARGATE for simplicity
  cpu                      = "1024"      # 1 vCPU
  memory                   = "2048"      # 2 GB
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn # Reference from iam.tf
  task_role_arn            = aws_iam_role.ecs_task_role.arn      # Reference from iam.tf

  container_definitions = jsonencode([
    {
      name      = "financial-app-container",
      image     = "${aws_ecr_repository.app_repo.repository_url}:latest",
      essential = true,
      portMappings = [{
        containerPort = 8000,
        protocol      = "tcp"
      }],
      environment = [
        { name = "DB_HOST", value = "financial-db-service" },
        { name = "REDIS_HOST", value = "financial-redis-service" }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = "/ecs/financial-app-task",
          "awslogs-region"        = "eu-north-1", # Change to your region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "financial_app_service" {
  name            = "financial-app-service"
  cluster         = aws_ecs_cluster.main_cluster.name
  task_definition = aws_ecs_task_definition.financial_app_task.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    # Use private subnets defined in network.tf
    subnets          = module.vpc.private_subnets 
    # Use the SG defined in security_groups.tf
    security_groups  = [aws_security_group.app_sg.id]
    assign_public_ip = false # Tasks in private subnets should not have public IPs
  }
  
  # Requires a deployment controller for FARGATE
  deployment_controller {
    type = "ECS"
  }
}

# =================================================================
# 2. FINANCIAL PIPELINE DB SERVICE (PostgreSQL + postgres_exporter Sidecar)
# =================================================================
resource "aws_ecs_task_definition" "financial_db_task" {
  family                   = "financial-db-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "financial-db-container",
      image     = "${aws_ecr_repository.db_repo.repository_url}:latest",
      essential = true,
      portMappings = [{
        containerPort = 5432,
        protocol      = "tcp"
      }],
      environment = [
        { name = "POSTGRES_USER", value = "user" },
        { name = "POSTGRES_PASSWORD", value = "password" }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = "/ecs/financial-db-task",
          "awslogs-region"        = "eu-north-1",
          "awslogs-stream-prefix" = "ecs"
        }
      }
    },
    {
      name      = "postgres-exporter-container",
      image     = "quay.io/prometheuscommunity/postgres-exporter:latest",
      essential = false,
      portMappings = [{
        containerPort = 9187,
        protocol      = "tcp"
      }],
      environment = [
        # Note: Exporter uses 'localhost' as it's in the same task
        { name = "DATA_SOURCE_NAME", value = "postgresql://user:password@localhost:5432/db?sslmode=disable" } 
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = "/ecs/financial-db-task",
          "awslogs-region"        = "eu-north-1",
          "awslogs-stream-prefix" = "exporter"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "financial_db_service" {
  name            = "financial-db-service"
  cluster         = aws_ecs_cluster.main_cluster.name
  task_definition = aws_ecs_task_definition.financial_db_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets # If using dedicated database subnets, then change to the specific database subnets
    security_groups  = [aws_security_group.db_sg.id]
    assign_public_ip = false
  }
  depends_on = [aws_ecs_cluster.main_cluster] # wait the main_cluster service to be running
}

# =================================================================
# 3. FINANCIAL PIPELINE REDIS SERVICE
# =================================================================
resource "aws_ecs_task_definition" "financial_redis_task" {
  family                   = "financial-redis-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "financial-redis-container",
      image     = "${aws_ecr_repository.redis_repo.repository_url}:latest",
      essential = true,
      portMappings = [{
        containerPort = 6379,
        protocol      = "tcp"
      }],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = "/ecs/financial-redis-task",
          "awslogs-region"        = "eu-north-1",
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "financial_redis_service" {
  name            = "financial-redis-service"
  cluster         = aws_ecs_cluster.main_cluster.name
  task_definition = aws_ecs_task_definition.financial_redis_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.redis_sg.id]
    assign_public_ip = false
  }
}

# =================================================================
# 4. FINANCIAL PIPELINE CRON SCHEDULER SERVICE
# Note: Should use the same SG as the App to connect to DB/Redis
# =================================================================
resource "aws_ecs_task_definition" "scheduler_task" {
  family                   = "scheduler-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "scheduler-container",
      image     = "${aws_ecr_repository.scheduler_repo.repository_url}:latest",
      essential = true,
      command   = ["/usr/bin/supervisord"],
      environment = [
        { name = "DB_HOST", value = "financial-db-service" }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = "/ecs/scheduler-task",
          "awslogs-region"        = "eu-north-1",
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "scheduler_service" {
  name            = "scheduler-service"
  cluster         = aws_ecs_cluster.main_cluster.name
  task_definition = aws_ecs_task_definition.scheduler_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.app_sg.id] # Reusing App SG for DB/Redis access
    assign_public_ip = false
  }
}


# =================================================================
# 5. PROMETHEUS SERVICE
# =================================================================
resource "aws_ecs_task_definition" "prometheus_task" {
  family                   = "prometheus-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "prometheus-container",
      image     = "${aws_ecr_repository.prometheus_repo.repository_url}:latest",
      essential = true,
      portMappings = [{
        containerPort = 9090,
        protocol      = "tcp"
      }],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = "/ecs/prometheus-task",
          "awslogs-region"        = "eu-north-1",
          "awslogs-stream-prefix" = "ecs"
        }
      }
      # Add volume mounting for persistent config/data here
    }
  ])
}

resource "aws_ecs_service" "prometheus_service" {
  name            = "prometheus-service"
  cluster         = aws_ecs_cluster.main_cluster.name
  task_definition = aws_ecs_task_definition.prometheus_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.public_subnets # Monitoring can be public if needed
    security_groups  = [aws_security_group.monitoring_sg.id]
    assign_public_ip = true
  }
}

# =================================================================
# 6. GRAFANA SERVICE
# =================================================================
resource "aws_ecs_task_definition" "grafana_task" {
  family                   = "grafana-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "grafana-container",
      image     = "${aws_ecr_repository.grafana_repo.repository_url}:latest",
      essential = true,
      portMappings = [{
        containerPort = 3000,
        protocol      = "tcp"
      }],
      environment = [
        { name = "GF_AUTH_ANONYMOUS_ENABLED", value = "true" }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = "/ecs/grafana-task",
          "awslogs-region"        = "eu-north-1",
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "grafana_service" {
  name            = "grafana-service"
  cluster         = aws_ecs_cluster.main_cluster.name
  task_definition = aws_ecs_task_definition.grafana_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.public_subnets # Monitoring can be public if needed
    security_groups  = [aws_security_group.monitoring_sg.id]
    assign_public_ip = true
  }
}
