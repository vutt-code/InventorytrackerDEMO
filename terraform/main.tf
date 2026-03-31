locals {
  azs = ["${var.aws_region}a", "${var.aws_region}b"]
}

# ─────────────────────────────────────────────────────────────────────────────
# VPC  (official module)
# ─────────────────────────────────────────────────────────────────────────────
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.app_name}-vpc"
  cidr = var.vpc_cidr
  azs  = local.azs

  public_subnets  = var.public_subnets
  private_subnets = concat(var.private_app_subnets, var.private_db_subnets)

  # Single NAT GW — cost-optimised for test environment
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Subnet name tags so we can identify app vs db subnets
  private_subnet_tags = {
    Type = "private"
  }
  public_subnet_tags = {
    Type = "public"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Security Groups
# ─────────────────────────────────────────────────────────────────────────────
# NOTE: Inline ingress/egress blocks that cross-reference each other's .id
# create a Terraform dependency cycle. SG shells are declared empty; rules
# are attached via separate aws_security_group_rule resources below.

resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "Allow HTTP inbound to the Application Load Balancer"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group" "app" {
  name        = "app-sg"
  description = "Allow traffic from ALB to Fargate tasks"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group" "db" {
  name        = "db-sg"
  description = "Allow PostgreSQL from Fargate app tasks only"
  vpc_id      = module.vpc.vpc_id
}

# ── ALB rules ────────────────────────────────────────────────────────────────
resource "aws_security_group_rule" "alb_ingress_http" {
  # tfsec:ignore:aws-vpc-no-public-ingress-sgr
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  description       = "HTTP from internet"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb_ingress_https" {
  # tfsec:ignore:aws-vpc-no-public-ingress-sgr
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  description       = "HTTPS from internet"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb_egress_to_app" {
  security_group_id        = aws_security_group.alb.id
  type                     = "egress"
  description              = "Forward to Fargate tasks on container port"
  from_port                = var.container_port
  to_port                  = var.container_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
}

# ── App rules ─────────────────────────────────────────────────────────────────
resource "aws_security_group_rule" "app_ingress_from_alb" {
  security_group_id        = aws_security_group.app.id
  type                     = "ingress"
  description              = "Container port from ALB"
  from_port                = var.container_port
  to_port                  = var.container_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "app_egress_https" {
  # tfsec:ignore:aws-vpc-no-public-egress-sgr
  security_group_id = aws_security_group.app.id
  type              = "egress"
  description       = "HTTPS out (ECR image pull, Secrets Manager via NAT)"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "app_egress_to_db" {
  security_group_id        = aws_security_group.app.id
  type                     = "egress"
  description              = "PostgreSQL to RDS"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.db.id
}

# ── DB rules ──────────────────────────────────────────────────────────────────
resource "aws_security_group_rule" "db_ingress_from_app" {
  security_group_id        = aws_security_group.db.id
  type                     = "ingress"
  description              = "PostgreSQL from Fargate"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
}

# ─────────────────────────────────────────────────────────────────────────────
# RDS PostgreSQL  (official module)
# ─────────────────────────────────────────────────────────────────────────────
module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${var.app_name}-db"

  engine            = "postgres"
  engine_version    = "15"
  instance_class    = var.db_instance_class
  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true # Security guardrail — always enabled

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  # IMPORTANT: must be false so Terraform controls the password via var.db_password.
  # The rds module v6 defaults this to true, which causes AWS to generate a random
  # password and silently ignore our var.db_password — breaking our DATABASE_URL secret.
  manage_master_user_password = false

  # Subnets: last 2 of module.vpc.private_subnets are the DB subnets
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]

  publicly_accessible = false
  multi_az            = false # Single-AZ for test environment

  backup_retention_period = 7
  skip_final_snapshot     = true  # Allows clean terraform destroy
  deletion_protection     = false # Test environment

  family               = "postgres15"
  major_engine_version = "15"

  parameters = [
    {
      name  = "log_connections"
      value = "1"
    }
  ]
}


resource "aws_db_subnet_group" "main" {
  name        = "${var.app_name}-db-subnet-group"
  description = "RDS subnet group for ${var.app_name}"
  # Use the last 2 private subnets designated for the DB tier
  subnet_ids = slice(module.vpc.private_subnets, 2, 4)
}

# ─────────────────────────────────────────────────────────────────────────────
# Secrets Manager — DATABASE_URL
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_secretsmanager_secret" "db_url" {
  name        = "${var.app_name}/app-db-url"
  description = "Prisma DATABASE_URL for the Inventory Tracker application"
  # Allows immediate recreation after terraform destroy (test environment only)
  recovery_window_in_days = 0
  # Ensures we can recreate it even if a previous one exists
  force_overwrite_replica_secret = true
}


resource "aws_secretsmanager_secret_version" "db_url" {
  secret_id = aws_secretsmanager_secret.db_url.id
  # We URL-encode the password to handle special characters and add connection limits 
  # to prevent RDS pool exhaustion on the small db.t3.micro instance.
  secret_string = "postgresql://${var.db_username}:${urlencode(var.db_password)}@${module.rds.db_instance_address}:5432/${var.db_name}?connection_limit=1&pool_timeout=30&connect_timeout=10"
}

# ─────────────────────────────────────────────────────────────────────────────
# Secrets Manager — Gemini API Key
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_secretsmanager_secret" "gemini_api" {
  name                           = "${var.app_name}/gemini-api"
  description                    = "Google Gemini API key for the AI Chatbot"
  recovery_window_in_days        = 0
  force_overwrite_replica_secret = true
}

resource "aws_secretsmanager_secret_version" "gemini_api" {
  secret_id     = aws_secretsmanager_secret.gemini_api.id
  secret_string = var.gemini_api_key
}


# ─────────────────────────────────────────────────────────────────────────────
# ECR — Container Registry
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_ecr_repository" "app" {
  name                 = var.app_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  force_delete = true # Allows clean terraform destroy even with images
}

# ─────────────────────────────────────────────────────────────────────────────
# CloudWatch Log Group
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "ecs" {
  # tfsec:ignore:aws-cloudwatch-log-group-customer-key
  name              = "/ecs/${var.app_name}"
  retention_in_days = 7
}

# ─────────────────────────────────────────────────────────────────────────────
# IAM — ECS Task Execution Role (least privilege)
# ─────────────────────────────────────────────────────────────────────────────
data "aws_iam_policy_document" "ecs_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_trust.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Inline policy — scoped to this specific secret only (least privilege)
data "aws_iam_policy_document" "secrets_read" {
  statement {
    sid     = "AllowReadInventorySecret"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_secretsmanager_secret.db_url.arn,
      aws_secretsmanager_secret.gemini_api.arn
    ]
  }
}

resource "aws_iam_role_policy" "secrets_read" {
  name   = "secrets-read-policy"
  role   = aws_iam_role.ecs_task_execution.id
  policy = data.aws_iam_policy_document.secrets_read.json
}

# ─────────────────────────────────────────────────────────────────────────────
# ECS Cluster
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled" # Keep costs low in test env; enable for prod
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# ECS Task Definition
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_ecs_task_definition" "app" {
  family                   = var.app_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "inventory-app"
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "PORT", value = tostring(var.container_port) },
        { name = "HOSTNAME", value = "0.0.0.0" },
        { name = "AUTH_SECRET", value = var.auth_secret },
        { name = "GOOGLE_CLIENT_ID", value = var.google_client_id },
        { name = "GOOGLE_CLIENT_SECRET", value = var.google_client_secret },
        { name = "INITIAL_ALLOWED_EMAILS", value = var.initial_allowed_emails },
        { name = "AUTH_URL", value = var.auth_url },
        { name = "AUTH_TRUST_HOST", value = var.auth_trust_host }
      ]

      secrets = [
        {
          name      = "DATABASE_URL"
          valueFrom = aws_secretsmanager_secret.db_url.arn
        },
        {
          name      = "GEMINI_API_KEY"
          valueFrom = aws_secretsmanager_secret.gemini_api.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://127.0.0.1:3000/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])
}

# ─────────────────────────────────────────────────────────────────────────────
# Domain & DNS (Route 53)
# ─────────────────────────────────────────────────────────────────────────────
data "aws_route53_zone" "selected" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "apex" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# SSL/TLS Certificate (ACM)
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_acm_certificate" "main" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.selected.zone_id
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# ─────────────────────────────────────────────────────────────────────────────
# Application Load Balancer
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_lb" "main" {
  # tfsec:ignore:aws-elb-alb-not-public
  name               = "${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets

  drop_invalid_header_fields = true
}

resource "aws_lb_target_group" "app" {
  name        = "${var.app_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

# HTTP listener — redirects to HTTPS
resource "aws_lb_listener" "http" {
  # tfsec:ignore:aws-elb-http-not-used
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS listener — forwards to Fargate tasks
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.main.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# ECS Service
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_ecs_service" "app" {
  name            = "${var.app_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    # App subnets: first 2 of the private subnets
    subnets          = slice(module.vpc.private_subnets, 0, 2)
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "inventory-app"
    container_port   = var.container_port
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # Grace period for ALB health checks during startup (Next.js can be slow to start)
  health_check_grace_period_seconds = 120

  depends_on = [
    aws_lb_listener.http,
    aws_lb_listener.https,
    aws_iam_role_policy_attachment.ecs_task_execution_managed,
    aws_iam_role_policy.secrets_read,
  ]
}

# ─────────────────────────────────────────────────────────────────────────────
# S3 — Source Code Storage
# ─────────────────────────────────────────────────────────────────────────────
resource "random_id" "bucket_suffix" {
  byte_length = 6
}

resource "aws_s3_bucket" "source" {
  # tfsec:ignore:aws-s3-enable-bucket-logging
  bucket        = "${var.app_name}-source-${random_id.bucket_suffix.hex}"
  force_destroy = true # Allows clean terraform destroy even with ZIP source present
}

resource "aws_s3_bucket_versioning" "source" {
  bucket = aws_s3_bucket.source.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "source" {
  bucket = aws_s3_bucket.source.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "source" {
  bucket = aws_s3_bucket.source.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ─────────────────────────────────────────────────────────────────────────────
# IAM — CodeBuild Service Role
# ─────────────────────────────────────────────────────────────────────────────
data "aws_iam_policy_document" "codebuild_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codebuild" {
  name               = "${var.app_name}-codebuild-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_trust.json
}

data "aws_iam_policy_document" "codebuild_policy" {
  statement {
    sid = "AllowLogging"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }

  statement {
    sid = "AllowECRAuth"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }

  statement {
    sid = "AllowECRPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload"
    ]
    resources = [
      aws_ecr_repository.app.arn
    ]
  }

  statement {
    sid = "AllowS3Read"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:ListBucketVersions"
    ]
    resources = [
      aws_s3_bucket.source.arn,
      "${aws_s3_bucket.source.arn}/*"
    ]
  }

  statement {
    sid = "AllowECSUpdate"
    actions = [
      "ecs:UpdateService"
    ]
    resources = [
      aws_ecs_service.app.id
    ]
  }

  statement {
    sid = "AllowECSRunTask"
    actions = [
      "ecs:RunTask",
      "ecs:DescribeTasks",
      "iam:PassRole"
    ]
    resources = ["*"] # Permissions needed to trigger the one-off migration task
  }
}

resource "aws_iam_role_policy" "codebuild" {
  name   = "${var.app_name}-codebuild-policy"
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.codebuild_policy.json
}

# ─────────────────────────────────────────────────────────────────────────────
# AWS CodeBuild Project
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_codebuild_project" "app_builder" {
  # tfsec:ignore:aws-codebuild-project-encryption
  # tfsec:ignore:aws-codebuild-privileged-mode
  name          = "${var.app_name}-builder"
  description   = "Builds the Next.js Docker image and pushes to ECR"
  build_timeout = 15
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type     = "S3"
    location = aws_s3_bucket.source.bucket
    name     = var.source_zip_key
  }

  # This is the "source" for CodeBuild to pull the ZIP from S3
  source {
    type     = "S3"
    location = "${aws_s3_bucket.source.bucket}/${var.source_zip_key}"

    buildspec = <<-EOF
      version: 0.2
      phases:
        pre_build:
          commands:
            - echo Logging in to Amazon ECR...
            - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $REPOSITORY_URI
        build:
          commands:
            - echo Build started on `date`
            - echo Building the Docker image...
            - docker build -t $REPOSITORY_URI:latest .
        post_build:
          commands:
            - echo Build completed on `date`
            - echo Pushing the Docker image...
            - docker push $REPOSITORY_URI:latest
            - echo Running database migrations...
            - |
              MIGRATE_TASK_ARN=$(aws ecs run-task --cluster $ECS_CLUSTER --task-definition $TASK_FAMILY --region $AWS_DEFAULT_REGION --launch-type FARGATE \
                --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUP],assignPublicIp=DISABLED}" \
                --overrides '{"containerOverrides": [{"name": "inventory-app", "command": ["npx", "prisma@6", "migrate", "deploy"]}]}' \
                --query 'tasks[0].taskArn' --output text)
              echo "Waiting for migration task $MIGRATE_TASK_ARN..."
              aws ecs wait tasks-stopped --cluster $ECS_CLUSTER --tasks $MIGRATE_TASK_ARN --region $AWS_DEFAULT_REGION
              EXIT_CODE=$(aws ecs describe-tasks --cluster $ECS_CLUSTER --tasks $MIGRATE_TASK_ARN --region $AWS_DEFAULT_REGION --query 'tasks[0].containers[0].exitCode' --output text)
              if [ "$EXIT_CODE" -ne "0" ]; then
                echo "Migration failed with exit code $EXIT_CODE"
                exit 1
              fi
            - echo Updating ECS service...
            - aws ecs update-service --cluster $ECS_CLUSTER --service $ECS_SERVICE --force-new-deployment
      EOF
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "REPOSITORY_URI"
      value = aws_ecr_repository.app.repository_url
    }

    environment_variable {
      name  = "ECS_CLUSTER"
      value = aws_ecs_cluster.main.name
    }

    environment_variable {
      name  = "ECS_SERVICE"
      value = aws_ecs_service.app.name
    }

    environment_variable {
      name  = "TASK_FAMILY"
      value = aws_ecs_task_definition.app.family
    }

    environment_variable {
      name  = "SUBNETS"
      value = join(",", slice(module.vpc.private_subnets, 0, 2))
    }

    environment_variable {
      name  = "SECURITY_GROUP"
      value = aws_security_group.app.id
    }
  }

  # Build commands are handled via an inline buildspec for simplicity
  # source_version = "main" # Not needed for S3 source
}
