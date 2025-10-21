# terraform/output.tf

# Output the ECR repository URI so the deploy-app workflow knows where to push the image
output "ecr_repository_uri" {
  value = aws_ecr_repository.app_repo.repository_url
}

# Output the Cluster Name for the ECS deployment action
output "ecs_cluster_name" {
  value = aws_ecs_cluster.main_cluster.name
}

# Output Subnet IDs for ECS/Fargate
output "private_subnet_ids" {
  value = module.vpc.private_subnets
}

# Output Subnet IDs for RDS
output "database_subnet_ids" {
  value = module.vpc.database_subnets
}

