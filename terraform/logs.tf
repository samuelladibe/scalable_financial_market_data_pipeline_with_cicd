# =================================================================
# CLOUDWATCH LOG GROUPS
# These log groups must exist before ECS tasks can write to them.
# =================================================================

# Log Group for Financial App / Scheduler
resource "aws_cloudwatch_log_group" "financial_app_task_log_group" {
  name              = "/ecs/financial-app-task"
  retention_in_days = 7
}

# Log Group for Financial DB / Exporter
resource "aws_cloudwatch_log_group" "financial_db_task_log_group" {
  name              = "/ecs/financial-db-task"
  retention_in_days = 7
}

# Log Group for Financial Redis
resource "aws_cloudwatch_log_group" "financial_redis_task_log_group" {
  name              = "/ecs/financial-redis-task"
  retention_in_days = 7
}

# Log Group for Scheduler
# Note: Reusing the same Log Group as the App task definition for simplicity
resource "aws_cloudwatch_log_group" "scheduler_task_log_group" {
  name              = "/ecs/scheduler-task"
  retention_in_days = 7
}

# Log Group for Prometheus
resource "aws_cloudwatch_log_group" "prometheus_task_log_group" {
  name              = "/ecs/prometheus-task"
  retention_in_days = 7
}

# Log Group for Grafana
resource "aws_cloudwatch_log_group" "grafana_task_log_group" {
  name              = "/ecs/grafana-task"
  retention_in_days = 7
}
