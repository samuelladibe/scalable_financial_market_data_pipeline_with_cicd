# terraform/network.tf

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

  # Isolated/Database Subnets (for RDS Postgres)
  database_subnets = ["10.0.21.0/24", "10.0.22.0/24"]

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