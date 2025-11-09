# =================================================================
# 1. ECS TASK EXECUTION ROLE (CRITICAL: Used by Fargate agent)
# Handles pulling ECR images, pushing logs to CloudWatch, and pulling secrets.
# =================================================================

resource "aws_iam_role" "ecs_execution_role" {
  name = "financial-pipeline-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Custom Policy for Fargate Execution: Combines ECR pull and full CloudWatch Log access.
resource "aws_iam_policy" "ecs_fargate_execution_policy" {
  name        = "financial-pipeline-ecs-fargate-execution-policy"
  description = "Allows ECS Execution Role to pull images from ECR and manage CloudWatch logs"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ECR Permissions (for pulling images)
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories" 
        ]
        Resource = "*"
      },
      # CloudWatch Logs Permissions (for logging)
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:PutRetentionPolicy" # Added to resolve the error and ensure full log control
        ]
        # Restrict to the specific log groups created in logs.tf
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/*"
      },
    ]
  })
}

# Replace the Managed Policy attachment with the Custom Policy attachment
resource "aws_iam_role_policy_attachment" "ecs_execution_policy_attach" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.ecs_fargate_execution_policy.arn
}

# =================================================================
# 2. ECS TASK ROLE (Optional, but best practice: grants permissions *to* the containers, e.g., S3 access)
# =================================================================

resource "aws_iam_role" "ecs_task_role" {
  name = "financial-pipeline-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# You can attach specific policies here (e.g., S3 read/write permissions)
resource "aws_iam_role_policy_attachment" "example_s3_read_only" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}