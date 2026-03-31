variable "aws_region" {
  description = "AWS region where all resources will be deployed."
  type        = string
  default     = "eu-north-1"
}

variable "app_name" {
  description = "Application name used as a prefix for all resource names."
  type        = string
  default     = "inventory-tracker"
}

variable "environment" {
  description = "Deployment environment label (e.g. test, staging, prod)."
  type        = string
  default     = "test"
}

# ── Networking ────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "CIDR blocks for the public subnets (one per AZ) — used by the ALB."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnets" {
  description = "CIDR blocks for the private app subnets (one per AZ) — used by Fargate tasks."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "private_db_subnets" {
  description = "CIDR blocks for the private database subnets (one per AZ) — used by RDS."
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
}

# ── Database ──────────────────────────────────────────────────────────────────

variable "db_username" {
  description = "Master username for the RDS PostgreSQL instance."
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Master password for the RDS PostgreSQL instance. Pass via TF_VAR_db_password — never commit."
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Name of the initial database to create inside the RDS instance."
  type        = string
  default     = "inventory_tracker"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

# ── ECS / Fargate ─────────────────────────────────────────────────────────────

variable "container_cpu" {
  description = "CPU units to allocate to each Fargate task (1024 = 1 vCPU)."
  type        = number
  default     = 512
}

variable "container_memory" {
  description = "Memory (MiB) to allocate to each Fargate task."
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Number of Fargate task instances to keep running."
  type        = number
  default     = 1
}

variable "container_port" {
  description = "Port the Next.js container listens on."
  type        = number
  default     = 3000
}

# ── Build & Source ────────────────────────────────────────────────────────────

variable "source_zip_key" {
  description = "The key (filename) of the source ZIP package within the S3 bucket."
  type        = string
  default     = "source.zip"
}

# ── GitHub OIDC ───────────────────────────────────────────────────────────────

variable "github_repo" {
  description = "Target GitHub repository in the format 'username/repo-name'. Scopes the OIDC trust policy."
  type        = string
  default     = "vutt-code/Inventorytracker"
}

# ── Domain & SSL ──────────────────────────────────────────────────────────────

variable "domain_name" {
  description = "The registered domain name for the application (e.g. example.com)."
  type        = string
}

# ── Authentication ────────────────────────────────────────────────────────────

variable "auth_secret" {
  description = "NextAuth Secret string"
  type        = string
  sensitive   = true
}

variable "google_client_id" {
  description = "Google OAuth Client ID"
  type        = string
  sensitive   = true
}

variable "google_client_secret" {
  description = "Google OAuth Client Secret"
  type        = string
  sensitive   = true
}

variable "initial_allowed_emails" {
  description = "Comma separated list of emails for initial access"
  type        = string
  sensitive   = true
}

variable "auth_url" {
  description = "The public absolute URL for NextAuth (e.g. https://your-domain.com)"
  type        = string
  sensitive   = true
}

variable "auth_trust_host" {
  description = "Configure NextAuth to trust proxy hosts"
  type        = string
  default     = "true"
}

variable "gemini_api_key" {
  description = "Google Gemini API key for the integrated Assistant"
  type        = string
  sensitive   = true
}
