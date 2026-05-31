# ============================================================
# security-groups.tf – Security Groups for CI/CD Pipeline
# ============================================================

# ---- Jenkins Security Group ----
resource "aws_security_group" "jenkins" {
  name        = "${var.project_name}-jenkins-sg"
  description = "Security group for Jenkins CI server"
  vpc_id      = data.aws_vpc.default.id

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # Jenkins Web UI
  ingress {
    description = "Jenkins Web UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Jenkins JNLP Agent port
  ingress {
    description = "Jenkins JNLP Agents"
    from_port   = 50000
    to_port     = 50000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic (needed to clone repos, download plugins, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-jenkins-sg"
    Project = "tanstack-demo-cicd"
  }
}

# ---- SonarQube Security Group ----
resource "aws_security_group" "sonarqube" {
  name        = "${var.project_name}-sonarqube-sg"
  description = "Security group for SonarQube server"
  vpc_id      = data.aws_vpc.default.id

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # SonarQube Web UI – accessible from Jenkins and developers
  ingress {
    description = "SonarQube Web UI"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sonarqube-sg"
    Project = "tanstack-demo-cicd"
  }
}

# ---- Docker Deployment Server Security Group ----
resource "aws_security_group" "docker" {
  name        = "${var.project_name}-docker-sg"
  description = "Security group for Docker deployment server"
  vpc_id      = data.aws_vpc.default.id

  # SSH – needs to accept connections from Jenkins for deployment
  ingress {
    description = "SSH (Jenkins + Admin)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP – serve the web app
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS – serve the web app
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # App port (common Node.js/React dev port)
  ingress {
    description = "App Port 3000"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # App port 8000 (common Python/other frameworks)
  ingress {
    description = "App Port 8000"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-docker-sg"
    Project = "tanstack-demo-cicd"
  }
}
