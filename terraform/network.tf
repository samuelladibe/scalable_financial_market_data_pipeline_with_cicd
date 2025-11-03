# Data source to get the current region
data "aws_region" "current" {}

# Data source to get the current caller identity (account ID)
data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  # Fetches available AZs in the current region
  state = "available"
}

# Use the official AWS VPC module for a complete, production-ready network
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0" # Use a stable version

  name = "financial-pipeline-vpc"
  cidr = "10.0.0.0/16" # Total IP range for the VPC

  # Select two Availability Zones for high availability
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  # Public Subnets (for Load Balancer, NAT Gateway)
  public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]

  # Private Subnets (for ECS Fargate Tasks)
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24"]

  # Configuration for private subnets to access the internet (e.g., pulling Docker images)
  enable_nat_gateway = true
  single_nat_gateway = true # Saves cost by deploying one NAT Gateway

  # Enable DNS resolution
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = "Development"
    Project     = "FinancialPipeline"
  }
}

# --- VPC Endpoints ---

# Security Group for VPC Endpoints (allows HTTPS from within the VPC)
resource "aws_security_group" "vpc_endpoint_sg" {
  name        = "vpc-endpoint-sg"
  description = "Allow HTTPS traffic for VPC Endpoints"
  vpc_id      = module.vpc.vpc_id

  # Ingress: Allow 443 from anywhere inside the VPC
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block] # Allow traffic only from within the VPC
  }

  # Egress: Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vpc-endpoint-sg"
  }
}

# 1. ECR API Endpoint (Interface)
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]

  tags = {
    Name = "ecr-api-vpc-endpoint"
  }
}

# 2. ECR Docker Registry Endpoint (Interface)
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]

  tags = {
    Name = "ecr-dkr-vpc-endpoint"
  }
}

# 3. S3 Gateway Endpoint (CRITICAL: Required by ECR Interface Endpoints for authentication)
resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  # Attach routages tables to guarantee the S3 traffic is captured
  route_table_ids = concat(module.vpc.private_route_table_ids, module.vpc.public_route_table_ids)

  # Explicit Politics to guarantee ECR/S3 access
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:*"
        Resource  = "*"
      },
    ]
  })

  tags = {
    Name = "s3-gateway-vpc-endpoint"
  }
}

# 4. CloudWatch Logs Endpoint (Interface) - Needed for Fargate logging
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]

  tags = {
    Name = "logs-vpc-endpoint"
  }
}
