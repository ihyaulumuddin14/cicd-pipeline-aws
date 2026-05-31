# ============================================================
# main.tf – Core Infrastructure for CI/CD Pipeline
# ============================================================

# ------------------------------------------------------------
# Data Sources – AWS Academy Default VPC & Subnets
# AWS Academy memakai default VPC, tidak perlu buat baru.
# ------------------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Latest Ubuntu 22.04 LTS AMI (diambil otomatis sesuai region)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical official

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ------------------------------------------------------------
# EC2 Instance – Jenkins Server
# ------------------------------------------------------------

resource "aws_instance" "jenkins" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  associate_public_ip_address = true

  user_data = file("${path.module}/user-data-jenkins.sh")

  root_block_device {
    volume_size           = 20
    volume_type           = "gp2"
    delete_on_termination = true
  }

  tags = {
    Name    = "${var.project_name}-jenkins"
    Project = "tanstack-demo-cicd"
    Role    = "jenkins"
  }
}

# ------------------------------------------------------------
# EC2 Instance – SonarQube Server
# SonarQube butuh minimal 2 vCPU & 2 GB RAM → t2.medium cukup
# ------------------------------------------------------------

resource "aws_instance" "sonarqube" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.sonarqube.id]
  associate_public_ip_address = true

  user_data = file("${path.module}/user-data-sonarqube.sh")

  root_block_device {
    volume_size           = 20
    volume_type           = "gp2"
    delete_on_termination = true
  }

  tags = {
    Name    = "${var.project_name}-sonarqube"
    Project = "tanstack-demo-cicd"
    Role    = "sonarqube"
  }
}

# ------------------------------------------------------------
# EC2 Instance – Docker Deployment Server
# Tempat menjalankan aplikasi via docker-compose
# ------------------------------------------------------------

resource "aws_instance" "docker" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.docker.id]
  associate_public_ip_address = true

  user_data = file("${path.module}/user-data-docker.sh")

  root_block_device {
    volume_size           = 20
    volume_type           = "gp2"
    delete_on_termination = true
  }

  tags = {
    Name    = "${var.project_name}-docker"
    Project = "tanstack-demo-cicd"
    Role    = "docker-deploy"
  }
}

# ------------------------------------------------------------
# GitHub Repository Webhook
#
# Otomatis dibuat oleh Terraform setelah Jenkins EC2 berdiri.
# Terraform secara otomatis menunggu EC2 selesai dibuat (karena
# kita referensikan public_ip Jenkins) sebelum membuat webhook.
#
# Webhook URL format: http://<jenkins-ip>:8080/github-webhook/
# Events: push, pull_request
# ------------------------------------------------------------

resource "github_repository_webhook" "jenkins" {
  repository = var.github_repo

  configuration {
    url          = "http://${aws_instance.jenkins.public_ip}:8080/github-webhook/"
    content_type = "json"
    insecure_ssl = false
  }

  active = true
  events = ["push", "pull_request"]

  # Pastikan Jenkins EC2 sudah ada sebelum webhook dibuat
  depends_on = [aws_instance.jenkins]
}
