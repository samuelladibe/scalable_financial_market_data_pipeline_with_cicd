# terraform/ecs.tf

# 1. ECR Repository for Django app image
resource "aws_ecr_repository" "app_repo" {
  name                 = "financial-pipeline-app-repo"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

# 2. ECS Cluster (Fargate Compute)
resource "aws_ecs_cluster" "main_cluster" {
  name = "financial-pipeline-cluster"
}