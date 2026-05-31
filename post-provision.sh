#!/bin/bash
# ============================================================
# post-provision.sh
# Jalankan setelah: terraform apply
# Script ini mencetak ringkasan lengkap semua resource
# ============================================================
# Cara pakai:
#   chmod +x post-provision.sh
#   ./post-provision.sh
# ============================================================

# Warna terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║     CI/CD Pipeline – Post-Provision Summary                  ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ---- Ambil output dari Terraform ----
echo -e "${YELLOW}[INFO] Mengambil output dari Terraform...${NC}"

JENKINS_IP=$(terraform output -raw jenkins_public_ip 2>/dev/null)       || { echo -e "${RED}[ERROR] Jalankan dari direktori Terraform!${NC}"; exit 1; }
SONAR_IP=$(terraform output -raw sonarqube_public_ip 2>/dev/null)
DOCKER_IP=$(terraform output -raw docker_public_ip 2>/dev/null)
KEY_NAME=$(terraform output -json jenkins_ssh_command 2>/dev/null | python3 -c "import sys,json; s=json.load(sys.stdin); print(s.split('-i ')[1].split(' ')[0])" 2>/dev/null || echo "<your-key>.pem")
WEBHOOK_URL=$(terraform output -raw github_webhook_url 2>/dev/null)

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  SERVER INFORMATION${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${CYAN}🔧 JENKINS SERVER${NC}"
echo -e "   Public IP  : ${GREEN}${JENKINS_IP}${NC}"
echo -e "   Web UI     : ${GREEN}http://${JENKINS_IP}:8080${NC}"
echo -e "   SSH        : ${BLUE}ssh -i ${KEY_NAME} ubuntu@${JENKINS_IP}${NC}"
echo ""

echo -e "${CYAN}📊 SONARQUBE SERVER${NC}"
echo -e "   Public IP  : ${GREEN}${SONAR_IP}${NC}"
echo -e "   Web UI     : ${GREEN}http://${SONAR_IP}:9000${NC}"
echo -e "   SSH        : ${BLUE}ssh -i ${KEY_NAME} ubuntu@${SONAR_IP}${NC}"
echo -e "   Login      : ${YELLOW}admin / admin${NC} (wajib ganti setelah login pertama)"
echo ""

echo -e "${CYAN}🐳 DOCKER DEPLOYMENT SERVER${NC}"
echo -e "   Public IP  : ${GREEN}${DOCKER_IP}${NC}"
echo -e "   App URL    : ${GREEN}http://${DOCKER_IP}${NC}"
echo -e "   SSH        : ${BLUE}ssh -i ${KEY_NAME} ubuntu@${DOCKER_IP}${NC}"
echo ""

echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${CYAN}🔗 GITHUB WEBHOOK${NC}"
echo -e "   Webhook URL : ${GREEN}${WEBHOOK_URL}${NC}"
echo -e "   Status      : ${GREEN}✅ Otomatis dikonfigurasi oleh Terraform${NC}"
echo -e "   Events      : push, pull_request"
echo ""
echo -e "   ${YELLOW}Cara verifikasi di GitHub:${NC}"
echo -e "   → Buka: https://github.com/ihyaulumuddin14/tanstack-demo/settings/hooks"
echo -e "   → Cari webhook dengan URL: ${WEBHOOK_URL}"
echo -e "   → Status harus: ${GREEN}✅ (centang hijau)${NC}"
echo ""

echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${CYAN}🔑 GET JENKINS INITIAL PASSWORD:${NC}"
echo ""
echo -e "   ${BOLD}ssh -i ${KEY_NAME} ubuntu@${JENKINS_IP} 'sudo cat /var/lib/jenkins/secrets/initialAdminPassword'${NC}"
echo ""

echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${YELLOW}⚠️  CHECKLIST LANGKAH SELANJUTNYA:${NC}"
echo ""
echo -e "   ${BOLD}[ ]${NC} 1. Tunggu 5-10 menit agar semua server selesai inisialisasi"
echo -e "   ${BOLD}[ ]${NC} 2. Jalankan command 'Get Jenkins Initial Password' di atas"
echo -e "   ${BOLD}[ ]${NC} 3. Buka Jenkins UI: http://${JENKINS_IP}:8080"
echo -e "   ${BOLD}[ ]${NC} 4. Selesaikan wizard Jenkins (Install Suggested Plugins)"
echo -e "   ${BOLD}[ ]${NC} 5. Buka SonarQube: http://${SONAR_IP}:9000 → login admin/admin → ganti password"
echo -e "   ${BOLD}[ ]${NC} 6. Buat project SonarQube 'tanstack-demo' → generate token"
echo -e "   ${BOLD}[ ]${NC} 7. Konfigurasi Jenkins (ikuti README.md Section 2)"
echo -e "   ${BOLD}[ ]${NC} 8. Buat Freestyle Project 'tanstack-demo-pipeline' di Jenkins"
echo -e "   ${BOLD}[ ]${NC} 9. Test pipeline dengan push ke GitHub"
echo -e "   ${BOLD}[ ]${NC} 10. Verifikasi webhook di GitHub settings"
echo ""

echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}📖 Baca README.md untuk panduan lengkap konfigurasi Jenkins!${NC}"
echo ""

# ---- Cek status server (opsional) ----
echo -e "${YELLOW}[INFO] Memeriksa koneksi ke server (mungkin belum siap)...${NC}"
echo ""

for SERVER_INFO in "Jenkins:${JENKINS_IP}:8080" "SonarQube:${SONAR_IP}:9000" "Docker:${DOCKER_IP}:80"; do
  IFS=':' read -r NAME IP PORT <<< "${SERVER_INFO}"
  if curl -s --connect-timeout 3 "http://${IP}:${PORT}" > /dev/null 2>&1; then
    echo -e "   ${NAME} (http://${IP}:${PORT}) : ${GREEN}✅ Online${NC}"
  else
    echo -e "   ${NAME} (http://${IP}:${PORT}) : ${YELLOW}⏳ Belum siap (normal jika baru deploy)${NC}"
  fi
done

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Selesai! Ikuti README.md untuk konfigurasi selanjutnya.     ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
