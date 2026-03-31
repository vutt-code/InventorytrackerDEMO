output "app_url" {
  description = "HTTP URL of the Application Load Balancer — open this in your browser."
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecr_repository_url" {
  description = "ECR repository URI. Use this to tag and push your Docker image."
  value       = aws_ecr_repository.app.repository_url
}

output "rds_endpoint" {
  description = "RDS PostgreSQL hostname (internal — not publicly accessible)."
  value       = module.rds.db_instance_address
}

output "ecs_cluster_name" {
  description = "ECS cluster name. Used in aws ecs run-task and update-service commands."
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name. Used in force-new-deployment commands."
  value       = aws_ecs_service.app.name
}

output "private_app_subnet_a" {
  description = "First private app subnet ID — used when running one-off Fargate migration tasks."
  value       = module.vpc.private_subnets[0]
}

output "sg_app_id" {
  description = "App security group ID — passed to one-off Fargate migration task runs."
  value       = aws_security_group.app.id
}

output "secrets_manager_arn" {
  description = "ARN of the DATABASE_URL secret in AWS Secrets Manager."
  value       = aws_secretsmanager_secret.db_url.arn
}

output "source_bucket_name" {
  description = "Name of the S3 bucket for source code uploads."
  value       = aws_s3_bucket.source.id
}

output "codebuild_project_name" {
  description = "Name of the CodeBuild project for cloud builds."
  value       = aws_codebuild_project.app_builder.name
}

