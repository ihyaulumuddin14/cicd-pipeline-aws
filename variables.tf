# ============================================================
# variables.tf – Input Variables for CI/CD Pipeline
# ============================================================

# ---- AWS Settings ----

variable "aws_region" {
  description = "AWS region to deploy resources (AWS Academy default: us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type for Jenkins, SonarQube, and Docker servers"
  type        = string
  default     = "t2.medium"
}

variable "key_name" {
  description = "Name of the existing AWS Key Pair (the .pem filename without extension, e.g. 'vockey')"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into servers. Use 0.0.0.0/0 for open, or your IP for security."
  type        = string
  default     = "0.0.0.0/0"
}

# ---- GitHub Settings ----

variable "github_token" {
  description = <<-EOT
    GitHub Personal Access Token (PAT).
    Create at: https://github.com/settings/tokens
    Required scopes: repo, admin:repo_hook
  EOT
  type      = string
  sensitive = true
}

variable "github_owner" {
  description = "GitHub username or organization that owns the repository"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name without the owner prefix (e.g. 'tanstack-demo')"
  type        = string
  default     = "tanstack-demo"
}

# ---- Project Settings ----

variable "project_name" {
  description = "Project name used for naming AWS resources and tags"
  type        = string
  default     = "tanstack-demo-cicd"
}
