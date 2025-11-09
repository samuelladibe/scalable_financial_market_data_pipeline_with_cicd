# =================================================================
# CODEBUILD IAM ROLE (Shared by all six CodeBuild projects)
# This role gives CodeBuild permissions to log, access ECR, and use S3 for source/artifacts.
# =================================================================
resource "aws_iam_role" "codebuild_role" {
  name = "financial-pipeline-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      },
    ]
  })
}

# Policy defining CodeBuild's necessary permissions (UPDATED ECR RESOURCE)
resource "aws_iam_policy" "codebuild_policy" {
  name        = "financial-pipeline-codebuild-policy"
  description = "Permissions for CodeBuild to push images to all ECR repos, update ECS, and log to CloudWatch"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # 1. CloudWatch Logs
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      },
      # 2. ECR Access (Critical: Allows CodeBuild to push to *all* repositories)
      {
        Effect   = "Allow"
        Action   = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/*"
      },
      # 3. S3 Access (For CodePipeline artifacts)
      {
        Effect   = "Allow"
        Action   = [ "s3:GetObject", "s3:GetObjectVersion", "s3:PutObject" ]
        Resource = [
          "arn:aws:s3:::codepipeline-${data.aws_region.current.name}-*",
          "arn:aws:s3:::financial-pipeline-artifacts/*"
        ]
      },
      # 4. ECS Deployment Permissions (Used by the final CodePipeline deploy stage)
      {
        Effect   = "Allow"
        Action   = [
            "ecs:DescribeServices", "ecs:CreateTaskSet", "ecs:UpdateService",
            "ecs:DeleteTaskSet", "ecs:DescribeTaskDefinition", "iam:PassRole"
        ]
        Resource = [
            "arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:service/*/*",
            "arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_attach" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_policy.arn
}

# =================================================================
# CODEBUILD PROJECT DEFINITIONS (One project for each custom service)
# =================================================================

# 1. APPLICATION (Django App)
resource "aws_codebuild_project" "app_build" {
  name          = "financial-pipeline-app-build"
  description   = "Builds the Django application Docker image and pushes to ECR"
  service_role  = aws_iam_role.codebuild_role.arn

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true

    environment_variable {
        name = "AWS_ACCOUNT_ID"
        value = data.aws_caller_identity.current.account_id
        }
    environment_variable {
        name = "AWS_REGION"
        value = data.aws_region.current.name
        }
    environment_variable {
        name = "IMAGE_TAG"
        value = "latest"
        }
    environment_variable { 
        name = "ECR_REPOSITORY_URL"
        value = aws_ecr_repository.app_repo.repository_url
        }
    environment_variable { 
        name = "CONTAINER_NAME"
        value = "financial-app-container"
        }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "app/buildspec.yml" # Assumes buildspec is in the 'app' subdirectory
  }

  artifacts { type = "CODEPIPELINE" }
}

# 2. SCHEDULER (Worker/Cron)
resource "aws_codebuild_project" "scheduler_build" {
  name          = "financial-pipeline-scheduler-build"
  description   = "Builds the Scheduler/Worker Docker image and pushes to ECR"
  service_role  = aws_iam_role.codebuild_role.arn

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true

    environment_variable { 
        name = "AWS_ACCOUNT_ID" 
        value = data.aws_caller_identity.current.account_id
        }
    environment_variable { 
        name = "AWS_REGION" 
        value = data.aws_region.current.name
        }
    environment_variable { 
        name = "IMAGE_TAG"
        value = "latest"
        }
    environment_variable {
        name = "ECR_REPOSITORY_URL"
        value = aws_ecr_repository.scheduler_repo.repository_url
        }
    environment_variable {
        name = "CONTAINER_NAME"
        value = "financial-scheduler-container"
        }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "scheduler/buildspec.yml" # Assumes buildspec is in the 'scheduler' subdirectory
  }

  artifacts { type = "CODEPIPELINE" }
}


# 3. PROMETHEUS (Monitoring)
resource "aws_codebuild_project" "prometheus_build" {
  name          = "financial-pipeline-prometheus-build"
  description   = "Builds the Prometheus Docker image (with config) and pushes to ECR"
  service_role  = aws_iam_role.codebuild_role.arn

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true

    environment_variable {
        name = "AWS_ACCOUNT_ID"
        value = data.aws_caller_identity.current.account_id
        }
    environment_variable {
        name = "AWS_REGION"
        value = data.aws_region.current.name
        }
    environment_variable {
        name = "IMAGE_TAG"
        value = "latest"
        }
    environment_variable {
        name = "ECR_REPOSITORY_URL"
        value = aws_ecr_repository.prometheus_repo.repository_url
        }
    environment_variable {
        name = "CONTAINER_NAME"
        value = "prometheus-container"
        }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "prometheus/buildspec.yml" # Assumes buildspec is in the 'prometheus' subdirectory
  }

  artifacts { type = "CODEPIPELINE" }
}

# 4. GRAFANA (Monitoring Dashboard)
resource "aws_codebuild_project" "grafana_build" {
  name          = "financial-pipeline-grafana-build"
  description   = "Builds the Grafana Docker image (with config) and pushes to ECR"
  service_role  = aws_iam_role.codebuild_role.arn

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true

    environment_variable {
        name = "AWS_ACCOUNT_ID"
        value = data.aws_caller_identity.current.account_id
        }
    environment_variable {
        name = "AWS_REGION"
        value = data.aws_region.current.name
        }
    environment_variable {
        name = "IMAGE_TAG"
        value = "latest"
        }
    environment_variable {
        name = "ECR_REPOSITORY_URL"
        value = aws_ecr_repository.grafana_repo.repository_url
        }
    environment_variable {
        name = "CONTAINER_NAME"
        value = "grafana-container"
        }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "grafana/buildspec.yml" # Assumes buildspec is in the 'grafana' subdirectory
  }

  artifacts { type = "CODEPIPELINE" }
}

# 5. DB (PostgreSQL) - Required if custom init scripts/config are baked in
resource "aws_codebuild_project" "db_build" {
  name          = "financial-pipeline-db-build"
  description   = "Builds the PostgreSQL Docker image and pushes to ECR"
  service_role  = aws_iam_role.codebuild_role.arn

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true

    environment_variable {
        name = "AWS_ACCOUNT_ID"
        value = data.aws_caller_identity.current.account_id
        }
    environment_variable {
        name = "AWS_REGION"
        value = data.aws_region.current.name
        }
    environment_variable {
        name = "IMAGE_TAG"
        value = "latest"
        }
    environment_variable {
        name = "ECR_REPOSITORY_URL" 
        value = aws_ecr_repository.db_repo.repository_url
        }
    environment_variable {
        name = "CONTAINER_NAME"
        value = "db-container"
        }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "db/buildspec.yml" # Assumes buildspec is in the 'db' subdirectory
  }

  artifacts { type = "CODEPIPELINE" }
}


# 6. REDIS
resource "aws_codebuild_project" "redis_build" {
  name          = "financial-pipeline-redis-build"
  description   = "Builds the Redis Docker image and pushes to ECR"
  service_role  = aws_iam_role.codebuild_role.arn

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true

    environment_variable {
        name = "AWS_ACCOUNT_ID"
        value = data.aws_caller_identity.current.account_id
        }
    environment_variable {
        name = "AWS_REGION"
        value = data.aws_region.current.name
        }
    environment_variable { 
        name = "IMAGE_TAG"
        value = "latest"
        }
    environment_variable { 
        name = "ECR_REPOSITORY_URL"
        value = aws_ecr_repository.redis_repo.repository_url
        }
    environment_variable {
        name = "CONTAINER_NAME"
        value = "redis-container"
        }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "redis/buildspec.yml" # Assumes buildspec is in the 'redis' subdirectory
  }

  artifacts { type = "CODEPIPELINE" }
}
