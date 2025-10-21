
terraform {
  backend "s3" {
    bucket         = "amzon-cfaproject-terraform-state-bucket"
    key            = "dev/ecs-fargate.tfstate"              # Bucket path to state file on AWS S3
    region         = "eu-north-1"
    dynamodb_table = "cfaproject-tf-locks"
    encrypt        = true
  }
}