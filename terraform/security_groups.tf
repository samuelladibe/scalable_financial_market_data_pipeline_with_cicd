# VPC ID reference from your network.tf file
locals {
  vpc_id = module.vpc.vpc_id
}

# =================================================================
# SECURITY GROUP FOR FINANCIAL DB (Private)
# =================================================================
resource "aws_security_group" "db_sg" {
  name        = "financial-db-sg"
  description = "Allows internal access to Postgres (5432)"
  vpc_id      = local.vpc_id

  # Authorize security group protecing ECR/Logs Endpoints
  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.vpc_endpoint_sg.id]
    description     = "Allow ECR/Logs pull via VPC Endpoint on 443"
  }
  
  # NEW: General Egress Rule for Fargate tasks in private subnets to reach NAT Gateway (for quay.io and general internet)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic via NAT Gateway"
  }
}

# =================================================================
# SECURITY GROUP FOR FINANCIAL REDIS (Private)
# =================================================================
resource "aws_security_group" "redis_sg" {
  name        = "financial-redis-sg"
  description = "Allows internal access to Redis (6379)"
  vpc_id      = local.vpc_id

  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.vpc_endpoint_sg.id]
    description     = "Allow ECR/Logs pull via VPC Endpoint on 443"
  }

  # NEW: General Egress Rule for Fargate tasks in private subnets to reach NAT Gateway (for quay.io and general internet)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic via NAT Gateway"
  }
}

# =================================================================
# SECURITY GROUP FOR APPLICATION AND SCHEDULER (Internal/Public Facing)
# =================================================================
resource "aws_security_group" "app_sg" {
  name        = "financial-app-sg"
  description = "Allows LB/Internet access (8000) and permits connection to internal services"
  vpc_id      = local.vpc_id

  # Ingress Rule: Allows ALL inbound traffic on the Django port (8000) for testing or from the Load Balancer
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Typically restricted to the Load Balancer's SG
  }

  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.vpc_endpoint_sg.id]
    description     = "Allow ECR/Logs pull via VPC Endpoint on 443"
  }

  # General Egress (for Scheduler et external application calls) - Existed previously, kept here
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Tous protocoles
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic (needed for NAT Gateway/Internet access)"
  }
}

# =================================================================
# SECURITY GROUP FOR MONITORING STACK (Prometheus & Grafana)
# =================================================================
resource "aws_security_group" "monitoring_sg" {
  name        = "financial-monitoring-sg"
  description = "Allows public access to Grafana (3000) and internal access to Prometheus (9090)"
  vpc_id      = local.vpc_id

  # Ingress Rule: Grafana (Web UI)
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ingress Rule: Prometheus (Web UI/API)
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.vpc_endpoint_sg.id]
    description     = "Allow ECR/Logs pull via VPC Endpoint on 443"
  }

  # Egress général (pour les requêtes de scraping externes ou mises à jour) - Existed previously, kept here
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Tous protocoles
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic (needed for NAT Gateway/Internet access)"
  }
}

# Self-referencing Ingress Rules for internal communication:

# 1. Allow App SG to talk to DB SG
resource "aws_security_group_rule" "app_to_db" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app_sg.id
  security_group_id        = aws_security_group.db_sg.id
  description              = "Allow App/Scheduler access to Postgres"
}

# 2. Allow App SG to talk to Redis SG
resource "aws_security_group_rule" "app_to_redis" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app_sg.id
  security_group_id        = aws_security_group.redis_sg.id
  description              = "Allow App/Scheduler access to Redis"
}

# 3. Allow Monitoring SG to talk to DB/App (for scraping) - Prometheus scraping DB Exporter
resource "aws_security_group_rule" "monitoring_to_db_exporter" {
  type                     = "ingress"
  from_port                = 9187 # Port for the Postgres Exporter sidecar
  to_port                  = 9187
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.monitoring_sg.id
  security_group_id        = aws_security_group.db_sg.id
  description              = "Allow Prometheus to scrape Postgres Exporter (9187)"
}
