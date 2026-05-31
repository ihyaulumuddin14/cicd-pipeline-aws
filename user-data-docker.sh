#!/bin/bash
# ============================================================
# user-data-docker.sh
# Docker Deployment Server Bootstrap Script
# Dijalankan otomatis saat EC2 pertama kali start
# ============================================================
set -e
exec > /var/log/user-data.log 2>&1

echo "=========================================="
echo "  Docker Server Setup – $(date)"
echo "=========================================="

# ---- Update & Install Prerequisites ----
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

apt-get install -y \
  curl \
  wget \
  git \
  unzip \
  apt-transport-https \
  ca-certificates \
  gnupg \
  lsb-release

# ---- Install Docker CE ----
echo "[INFO] Installing Docker CE..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "[INFO] Docker version: $(docker --version)"

# Add ubuntu user to docker group
usermod -aG docker ubuntu

systemctl enable docker
systemctl start docker

# ---- Install Docker Compose (standalone binary) ----
echo "[INFO] Installing Docker Compose standalone..."
COMPOSE_VERSION="v2.27.0"
curl -fsSL \
  "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-x86_64" \
  -o /usr/local/bin/docker-compose

chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

echo "[INFO] Docker Compose version: $(docker-compose --version)"

# ---- Create App Deployment Directory ----
echo "[INFO] Creating deployment directory structure..."
mkdir -p /opt/app/web-profile
chown -R ubuntu:ubuntu /opt/app

# ---- Create Helper Deploy Script ----
cat > /opt/app/deploy.sh << 'DEPLOY_SCRIPT'
#!/bin/bash
# ===========================================
# deploy.sh – Deploy web-profile via docker-compose
# Called by Jenkins after code push
# ===========================================
set -e

APP_DIR="/opt/app/web-profile"
REPO_URL="https://github.com/ihyaulumuddin14/tanstack-demo.git"

echo "[DEPLOY] Starting deployment – $(date)"
echo "[DEPLOY] Working directory: ${APP_DIR}"

# Clone repo if not exists, otherwise pull latest
if [ -d "${APP_DIR}/.git" ]; then
  echo "[DEPLOY] Pulling latest changes..."
  cd "${APP_DIR}"
  git fetch origin
  git reset --hard origin/main 2>/dev/null || git reset --hard origin/master
else
  echo "[DEPLOY] Cloning repository..."
  git clone "${REPO_URL}" "${APP_DIR}"
  cd "${APP_DIR}"
fi

# Stop existing containers
echo "[DEPLOY] Stopping existing containers..."
docker-compose down --remove-orphans 2>/dev/null || true

# Build and start containers
echo "[DEPLOY] Building and starting containers..."
docker-compose up -d --build

echo "[DEPLOY] Deployment complete – $(date)"
echo "[DEPLOY] Running containers:"
docker-compose ps
DEPLOY_SCRIPT

chmod +x /opt/app/deploy.sh
chown ubuntu:ubuntu /opt/app/deploy.sh

# ---- Write Info File ----
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "UNKNOWN")

cat > /home/ubuntu/docker-info.txt << EOF
==========================================
  Docker Server – Setup Complete
  $(date)
==========================================
Public IP     : ${PUBLIC_IP}
App URL       : http://${PUBLIC_IP}:3000
App Dir       : /opt/app/web-profile
Deploy Script : /opt/app/deploy.sh

Docker        : $(docker --version)
Compose       : $(docker-compose --version)

Log File      : /var/log/user-data.log
------------------------------------------
Test Docker:
  docker ps
  docker-compose -f /opt/app/web-profile/docker-compose.yml ps
==========================================
EOF

chown ubuntu:ubuntu /home/ubuntu/docker-info.txt

echo "=========================================="
echo "  Docker Server Setup Complete – $(date)"
echo "  App URL: http://${PUBLIC_IP}"
echo "=========================================="
