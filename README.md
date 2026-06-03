# CI/CD Pipeline: Jenkins + SonarQube + Docker di AWS Academy

### Project: [tanstack-demo](https://github.com/ihyaulumuddin14/tanstack-demo) | Terraform Automated Infrastructure

---

## Daftar Isi

1. [Arsitektur Overview](#1-arsitektur-overview)
2. [Prasyarat](#2-prasyarat)
3. [Quick Start – Terraform](#3-quick-start--terraform)
4. [After terraform apply – GitHub Webhook](#4-after-terraform-apply--github-webhook)
5. [Manual Configuration Jenkins Web UI](#5-manual-configuration-jenkins-web-ui)
   - [5.1 Login Jenkins Pertama Kali](#51-login-jenkins-pertama-kali)
   - [5.2 Install Suggested Plugins](#52-install-suggested-plugins)
   - [5.3 Buat Admin User](#53-buat-admin-user)
   - [5.4 SonarQube – Login & Ganti Password](#54-sonarqube--login--ganti-password)
   - [5.5 SonarQube – Buat Project & Generate Token](#55-sonarqube--buat-project--generate-token)
   - [5.6 Jenkins – Tambahkan Credential SonarQube Token](#56-jenkins--tambahkan-credential-sonarqube-token)
   - [5.7 Jenkins – Configure System (SonarQube Server)](#57-jenkins--configure-system-sonarqube-server)
   - [5.8 Jenkins – Global Tool Configuration (SonarQube Scanner)](#58-jenkins--global-tool-configuration-sonarqube-scanner)
   - [5.9 Jenkins – Tambahkan Credential SSH (Docker Server)](#59-jenkins--tambahkan-credential-ssh-docker-server)
   - [5.10 Jenkins – Configure System (Publish Over SSH)](#510-jenkins--configure-system-publish-over-ssh)
   - [5.11 Jenkins – Buat Freestyle Project](#511-jenkins--buat-freestyle-project)
   - [5.12 Source Code Management (Git)](#512-source-code-management-git)
   - [5.13 Build Triggers (GitHub Webhook)](#513-build-triggers-github-webhook)
   - [5.14 Build Environment](#514-build-environment)
   - [5.15 Build Steps – SonarQube Analysis](#515-build-steps--sonarqube-analysis)
   - [5.16 Build Steps – Deploy ke Docker Server](#516-build-steps--deploy-ke-docker-server)
   - [5.17 Post-build Actions](#517-post-build-actions)
6. [Test Pipeline End-to-End](#6-test-pipeline-end-to-end)
7. [Troubleshooting](#7-troubleshooting)
8. [Apa yang Otomatis vs Manual](#8-apa-yang-otomatis-vs-manual)
9. [Cleanup](#9-cleanup)

---

## 1. Arsitektur Overview

```
Developer Push → GitHub → [Webhook otomatis] → Jenkins
                                                    ↓
                                          SonarQube Analysis
                                                    ↓
                                          Docker Deploy Server
                                                    ↓
                                          Web App Live (http://<docker-ip>)
```

| Server    | Port | Fungsi                                   |
| --------- | ---- | ---------------------------------------- |
| Jenkins   | 8080 | CI/CD orchestrator, build trigger        |
| SonarQube | 9000 | Code quality analysis                    |
| Docker    | 80   | Production deployment via docker-compose |

**Semua infrastruktur di-provision oleh Terraform** termasuk GitHub Webhook.

---

## 2. Prasyarat

### 2.1 Tools yang Harus Terinstall di Komputer Lokal

| Tool      | Versi Minimum | Cara Install                         |
| --------- | ------------- | ------------------------------------ |
| Terraform | >= 1.3.0      | `brew install terraform` (Mac)       |
| AWS CLI   | >= 2.0        | Sudah terkonfigurasi (aws configure) |
| Git       | any           | `brew install git`                   |

### 2.2 File yang Harus Ada di Direktori Kerja

```
ci-cd/
├── *.pem          ← File key pair AWS (misal: vockey.pem)
├── main.tf
├── variables.tf
├── ...
```

### 2.3 GitHub Personal Access Token (PAT)

1. Buka: https://github.com/settings/tokens
2. Klik **"Generate new token (classic)"**
3. Berikan nama: `terraform-webhook`
4. **Expiration**: Sesuai kebutuhan (misal: 90 days)
5. Centang scopes berikut:
   - ✅ `repo` (Full control of private repositories)
   - ✅ `admin:repo_hook` (Full control of repository hooks)
6. Klik **"Generate token"**
7. **COPY TOKEN SEKARANG** – tidak bisa dilihat lagi!

---

## 3. Quick Start – Terraform

### Step 1: Clone project dan masuk direktori

```bash
cd /path/to/ci-cd
```

### Step 2: Buat file terraform.tfvars

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
aws_region       = "us-east-1"
instance_type    = "t2.medium"
key_name         = "vockey"          # ← nama KEY PAIR di AWS (bukan nama file .pem!)
                                     # Cek: aws ec2 describe-key-pairs --query 'KeyPairs[*].KeyName'
                                     # Di AWS Academy: key pair = "vockey", file = "labsuser.pem"

github_token     = "ghp_xxxxxxxxxxxx"  # ← token dari Step 2.3
github_owner     = "ihyaulumuddin14"
github_repo      = "tanstack-demo"

project_name     = "tanstack-demo-cicd"
allowed_ssh_cidr = "0.0.0.0/0"
```

> ⚠️ **PENTING**: Pastikan `terraform.tfvars` ada di `.gitignore`!

### Step 3: Initialize Terraform

```bash
terraform init
```

Output yang diharapkan:
![terraform init output](picture/terraform-init.png)

### Step 4: Plan (preview)

```bash
terraform plan
```

Akan menampilkan rencana pembuatan:

- `3 aws_instance` (Jenkins, SonarQube, Docker)
- `3 aws_security_group`
- `1 github_repository_webhook`

### Step 5: Apply

```bash
terraform apply
```

Ketik `yes` saat diminta konfirmasi.

Terraform akan:

1. Membuat 3 EC2 instances
2. Membuat 3 Security Groups
3. **Otomatis membuat GitHub Webhook** yang mengarah ke Jenkins

![terraform apply](picture/terraform-apply.png)

**Waktu proses**: ±3-5 menit untuk Terraform apply.
**Waktu inisialisasi server**: ±5-10 menit setelah apply selesai.

### Step 6: Lihat Output

```bash
terraform output
```

Catat semua IP yang ditampilkan, kamu akan butuh ini.

![terraform-output](picture/terraform-output.png)

### Step 7: Jalankan Post-Provision Script

```bash
chmod +x post-provision.sh
./post-provision.sh
```

Script ini akan mencetak semua URL, SSH commands, dan status server.

![post-provision output](picture/post-provision.png)

---

## 4. After terraform apply – GitHub Webhook

### 4.1 Apa yang Terjadi Secara Otomatis

Saat `terraform apply` selesai, Terraform telah:

✅ Membuat GitHub webhook di repository `ihyaulumuddin14/tanstack-demo`
✅ Mengatur URL webhook ke `http://<jenkins-ip>:8080/github-webhook/`
✅ Mengaktifkan events: `push` dan `pull_request`
✅ Content type: `application/json`

Kamu **TIDAK PERLU** mengkonfigurasi webhook secara manual.

### 4.2 Cara Verifikasi Webhook di GitHub

1. Buka browser, pergi ke:

   ```
   `https://github.com/ihyaulumuddin14/tanstack-demo/settings/hooks`
   ```

2. Akan ada 1 webhook dengan URL:

   ```
   http://<jenkins-ip>:8080/github-webhook/
   ```

3. **Status Normal (sebelum Jenkins dikonfigurasi):**
   ![webhook failed](picture/git-webhook%20failed.png)
   - Ada tanda ⚠️ atau ❌ – ini **NORMAL** karena Jenkins belum siap menerima webhook
   - Setelah Jenkins selesai dikonfigurasi di Section 5, webhook akan menampilkan ✅

4. **Cara cek detail webhook:**
   - Klik webhook tersebut
   - Scroll ke bawah ke section **"Recent Deliveries"**
   - Kamu bisa lihat history pengiriman dan response

### 4.3 Catatan Penting: Jika AWS Academy Session Restart

> ⚠️ AWS Academy menggunakan IP dinamis. Setiap session restart, IP berubah!

Jika IP Jenkins berubah setelah session restart:

```bash
# Jalankan ulang terraform apply untuk update webhook URL
terraform apply

# Terraform akan update webhook dengan IP baru secara otomatis
# Output: github_repository_webhook.jenkins will be updated in-place
```

---

## 5. Manual Configuration Jenkins Web UI

> ⏰ **Tunggu 5-10 menit** setelah `terraform apply` sebelum mengakses Jenkins.
> Server butuh waktu untuk install Jenkins dan plugins via user_data.

### 5.1 Login Jenkins Pertama Kali

**Step 1:** Dapatkan initial admin password dengan menjalankan command ini di terminal lokal:

```bash
# Ganti <JENKINS_IP> dengan IP dari terraform output
ssh -i labsuser.pem ubuntu@<JENKINS_IP> 'sudo cat /var/lib/jenkins/secrets/initialAdminPassword'
```

![initial admin pass](picture/initial%20admin%20password.png)

Output akan berupa string 32 karakter, contoh:

```
1b2c3d4e5f6789012345678901234ab
```

**COPY password ini!**

**Step 2:** Buka browser, pergi ke:

```
http://<JENKINS_IP>:8080
```

**Step 3:** Tampilan akan menampilkan:

![unlock jenkins](picture/jenkins-unlock.png)

→ **Paste password** yang tadi di-copy

→ Klik **"Continue"**

---

### 5.2 Install Suggested Plugins

Setelah unlock, muncul halaman **"Customize Jenkins"**:

![install manage plugin](picture/jenkins-install-manage-plugin.png)

→ Klik **"Install suggested plugins"** (tombol kiri)

→**Tunggu hingga semua plugin selesai** (±3-5 menit).

> **Catatan:** Plugin seperti SonarQube Scanner, Publish Over SSH, dan GitHub sudah
> diinstall via user_data (jenkins-plugin-manager). Plugin di step ini adalah
> plugin dasar yang disarankan Jenkins.

---

### 5.3 Buat Admin User

Setelah plugin terinstall, muncul form **"Create First Admin User"**:

![Create admin user](picture/jenkins-create%20admin%20user.png)

→ Isi semua field

→ Klik **"Save and Continue"**

**Halaman berikutnya: "Instance Configuration"**

![instance configuration](picture/jenkins-instance%20configuration.png)

→ Biarkan URL default (sudah terisi otomatis dengan IP Jenkins)

→ Klik **"Save and Finish"**

→ Klik **"Start using Jenkins"**

---

### 5.4 SonarQube – Login & Ganti Password

> Lakukan ini di tab browser baru.

**Step 1:** Buka SonarQube di:

```
http://<SONARQUBE_IP>:9000
```

> ⏰ Jika SonarQube belum bisa diakses, tunggu 3-5 menit lagi.
> SonarQube butuh waktu untuk start karena menginisialisasi database.

**Step 2:** Login dengan kredensial default:

```
Username: admin
Password: admin
```

![login](picture/sonarqube-login%20defaultpassword.png)

**Step 3:** Muncul popup "Update your password":

![update password](picture/sonarqube-update%20password.png)

→ Isi `admin` di "Old password"

→ Isi password baru yang kuat

→ Klik **"Update"**

---

### 5.5 SonarQube – Buat Project & Generate Token

**Step 1:** Di SonarQube Dashboard, klik **"Create a local project"**

**Step 2:** Isi form Project:

![Form create local project](picture/sonarqube-create-project.png)

→ Project display name: `tanstack-demo`

→ Project key: `tanstack-demo`

→ Main branch: `main`

→ Klik **"Next"**

**Step 3:** Pilih baseline:

![Setup project (choose baseline)](picture/sonarqube-pilih-baseline.png)

→ Pilih **"Previous version"**

→ Klik **"Create project"**

**Step 4:** Pilih analysis method – **"With Jenkins"**

![Analysis Method](picture/sonarqube-analysis-method.png)

→ Klik **"Jenkins"**

> Jika tidak muncul pilihan ini, skip ke Step 5.

**Step 5:** Generate Token untuk Jenkins:

1. Di SonarQube, klik avatar/nama di pojok kanan atas
2. Klik **"My Account"**
3. Klik tab **"Security"**
4. Di section "Generate Tokens":

   → Name: `jenkins-token`

   → Type: `User Token`

   → Klik **"Generate"**

5. Token akan muncul **SEKALI SAJA**:
   ```
   squ_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```
   → **COPY TOKEN INI** Simpan di notepad.

![generate token](picture/sonarqube-generate-token.png)

---

### 5.6 Jenkins – Tambahkan Credential SonarQube Token

> Kembali ke Jenkins di browser.

**Step 1:** Di Jenkins Dashboard, klik **"Manage Jenkins"** (menu kiri)

**Step 2:** Klik **"Manage Credentials"**

**Step 3:** Klik pada **(global)** di bawah "Stores scoped to Jenkins":

**Step 4:** Klik **"Add Credentials"** (tombol di kiri)

**Step 5:** Isi form credential:

![secret text](picture/jenkins-sonarqube-token1.png)

→ **Kind**: pilih `Secret text`

![form](picture/jenkins-sonarqube-token2.png)

→ **Scope**: `Global (Jenkins, nodes, items, all child items, etc)`

→ **Secret**: paste token SonarQube dari Step 5.5

→ **ID**: `sonarqube-token` (PERSIS seperti ini, akan direferensikan di pipeline)

→ **Description**: `SonarQube Auth Token`

→ Klik **"Create"**

---

### 5.7 Jenkins – Configure System (SonarQube Server)

**Step 1:** Klik **"Manage Jenkins"**

**Step 2:** Klik **"Configure System"**

**Step 3:** Scroll ke bawah hingga menemukan section **"SonarQube servers"**:

→ **Centang** "Enable injection of SonarQube server configuration..."
→ Klik **"Add SonarQube"**

**Step 4:** Isi detail SonarQube server:

![configure sonarQube server](picture/jenkins-sonarqube-server.png)

→ **Name**: `SonarQube` (PERSIS seperti ini, case-sensitive)

→ **Server URL**: `http://<SONARQUBE_IP>:9000`

→ Ganti `<SONARQUBE_IP>` dengan IP dari `terraform output sonarqube_public_ip`

→ **Server authentication token**: pilih `sonarqube-token` dari dropdown

**Step 5:** Klik **"Save"**

---

### 5.8 Jenkins – Global Tool Configuration (SonarQube Scanner)

**Step 1:** Klik **"Manage Jenkins"**

**Step 2:** Klik **"Global Tool Configuration"**

> Alternatif di Jenkins versi baru: **"Tools"**

**Step 3:** Scroll ke section **"SonarQube Scanner"**:

→ Klik **"Add SonarQube Scanner"**

**Step 4:** Isi konfigurasi:

![SonarQube Scanner](picture/jenkins-sonarqube-scanner.png)

→ **Name**: `SonarQube-Scanner`

→ **Centang** "Install automatically"

→ **Version**: pilih versi terbaru yang tersedia

**Step 5:** Klik **"Save"**

---

### 5.9 Jenkins – Tambahkan Credential SSH (Docker Server)

Jenkins perlu SSH key untuk koneksi ke Docker server.

**Step 1:** Buka file `.pem` kamu dan copy isinya:

```bash
# Di terminal lokal
cat labsuser.pem
```

Copy SEMUA isi file termasuk header dan footer:

```
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA...
(banyak baris)
...xxxxxxxxxxx=
-----END RSA PRIVATE KEY-----
```

**Step 2:** Di Jenkins, klik **"Manage Jenkins"** → **"Manage Credentials"**

**Step 3:** Klik **(global)** → **"Add Credentials"**

![add SSH credential](picture/jenkins-add%20SSH%20credentials.png)

**Step 4:** Isi form:

![add SSH username](picture/jenkins-add%20SSH%20username.png)

→ **Kind**: `SSH Username with private key`

→ **Scope**: `Global`

→ **ID**: `docker-server-key`

→ **Description**: `Docker Server SSH Key`

→ **Username**: `ubuntu`

→ **Private Key**: klik **"Enter directly"** → klik **"Add"** → paste SEMUA isi file `.pem`

→ Klik **"Create"**

---

### 5.10 Jenkins – Configure System (Publish Over SSH)

> Plugin ini memungkinkan Jenkins SSH ke Docker server dan menjalankan perintah deploy.

**Step 1:** Klik **"Manage Jenkins"** → **"Configure System"**

**Step 2:** Scroll ke section **"Publish over SSH"**

**Step 3:** Klik **"Add"** di section "SSH Servers":

![confgure ssh server](picture/jenkins-config%20ssh%20server.png)

Isi field:

**Bagian utama (di atas SSH Servers):**
→ **Key**: paste isi file `.pem` (SEMUA termasuk header/footer)

**Bagian SSH Servers:**
→ **Name**: `docker-server`

→ **Hostname**: IP dari `terraform output docker_public_ip`

Contoh: `54.123.456.789`

→ **Username**: `ubuntu`

→ **Remote Directory**: `/opt/app/tanstack-demo`

**Step 4:** Klik **"Advanced..."** untuk expand opsi tambahan:

→ Biarkan default (port 22, jangan centang "Use password authentication")

**Step 5:** Klik **"Test Configuration"**

Hasil yang diharapkan:

```
Success
```

Jika gagal:

- Pastikan Docker server sudah berjalan (tunggu jika baru deploy)
- Pastikan security group Docker mengizinkan port 22 dari Jenkins IP
- Cek bahwa private key yang di-paste sudah benar

**Step 6:** Klik **"Save"**

---

### 5.11 Jenkins – Buat Freestyle Project

**Step 1:** Di Jenkins Dashboard, klik **"New Item"** (menu kiri)

**Step 2:** Isi nama project:

![create project](picture/jenkins-freestyle-project.png)

→ Name: `tanstack-demo-pipeline`
→ Pilih: **"Freestyle project"**
→ Klik **"OK"**

Kamu masuk ke halaman konfigurasi project. Ada beberapa tab di atas:
**General | Source Code Management | Build Triggers | Build Environment | Build Steps | Post-build Actions**

---

### 5.12 Source Code Management (Git)

**Step 1:** Klik tab **"Source Code Management"**

**Step 2:** Pilih **"Git"**:

![source code management](picture/jenkins-source%20code%20management.png)

→ **Repository URL**: `https://github.com/ihyaulumuddin14/tanstack-demo`

→ **Credentials**: `- none -` (karena repo public)

→ Jika private, klik "Add" dan buat credential dengan GitHub token

→ **Branch Specifier**: `*/main`

→ Atau `*/master` jika branch utama namanya master

---

### 5.13 Build Triggers (GitHub Webhook)

**Step 1:** Klik tab **"Build Triggers"**

**Step 2:** Centang opsi berikut:

![build trigger](picture/jenkins-build%20triggers.png)

→ **Centang**: `GitHub hook trigger for GITScm polling`

> Ini yang menghubungkan GitHub webhook (yang sudah dibuat Terraform)
> dengan pipeline Jenkins. Setiap push ke GitHub akan trigger build ini.

---

### 5.14 Build Environment

**Step 1:** Klik tab **"Build Environment"**

**Step 2:** Centang:

→ **Centang** (opsional): `Add timestamps to the Console Output`

## ![environment checklist](picture/jenkins-environment.png)

### 5.15 Build Steps – SonarQube Analysis

**Step 1:** Klik tab **"Build Steps"**

**Step 2:** Klik **"Add build step"** → pilih **"Execute SonarQube Scanner"**

**Step 3:** Isi konfigurasi:

→ **Task to run**: biarkan kosong (default: `scan`)
→ **Analysis properties** – copy-paste teks ini PERSIS:

```properties
sonar.projectKey=tanstack-demo
sonar.projectName=tanstack-demo
sonar.projectVersion=1.0
sonar.sources=.
sonar.exclusions=**/node_modules/**,**/*.test.js,**/vendor/**
sonar.sourceEncoding=UTF-8
```

![configure sonarQube scanner](picture/jenkins-sonarqube-scanner-config.png)

---

### 5.16 Build Steps – Deploy ke Docker Server

Siapkan file env terlebih dahulu pada docker server

```
   MONGODB_URI=***

   BETTER_AUTH_SECRET=***

   AUTH_URL=http://<DOCKER_IP>:3000
   NEXT_PUBLIC_AUTH_URL=http://<DOCKER_IP>:3000
```

**Step 1:** Masih di tab "Build Steps", klik **"Add build step"** lagi

**Step 2:** Pilih **"Send files or execute commands over SSH"**

**Step 3:** Isi konfigurasi:

Isi field:
→ **SSH Server Name**: pilih `docker-server` dari dropdown

→ **Source files**: **KOSONGKAN** (gunakan git pull, tidak perlu transfer file)

→ **Remove prefix**: KOSONGKAN

→ **Remote directory**: KOSONGKAN

→ **Exec command**: paste command berikut:

```bash
   # Clone jika belum ada, pull jika sudah ada
   #!/bin/bash
   set -e

   APP_DIR="/opt/app/tanstack-demo"
   REPO_URL="https://github.com/ihyaulumuddin14/tanstack-demo.git"

   echo "================================="
   echo "Deploy started: $(date)"
   echo "================================="

   # Clone pertama kali atau update repo
   if [ -d "$APP_DIR/.git" ]; then
      echo "[INFO] Updating repository..."

      cd "$APP_DIR"

      git fetch origin
      git reset --hard origin/main

   else
      echo "[INFO] Cloning repository..."

      git clone "$REPO_URL" "$APP_DIR"

      cd "$APP_DIR"
   fi

   echo "[INFO] Docker Compose validation..."
   docker-compose config

   echo "[INFO] Stopping old containers..."
   docker-compose down --remove-orphans || true

   echo "[INFO] Building and starting containers..."
   docker-compose up -d --build

   echo "[INFO] Running containers:"
   docker-compose ps

   echo "================================="
   echo "Deploy completed: $(date)"
   echo "================================="
```

**Step 4:** Klik **"Advanced..."** di bagian Transfer Sets:

→ **Centang**: `Exec in pty`

→ **Timeout**: `120000` (2 menit, cukup untuk docker build)

![docker server ssh configure](picture/jenkins-docker%20server%20config.png)
![docker server ssh configure](picture/jenkins-docker%20server%20config2.png)

---

## 6. Test Pipeline End-to-End

### Test 1: Manual Build

1. Di Jenkins, klik project **"tanstack-demo-pipeline"**
2. Klik **"Build Now"** di menu kiri
3. Kamu akan melihat build baru muncul di "Build History" (#1)
4. Klik pada build tersebut → klik **"Console Output"**
5. Monitor progress:

   ![manual build output](picture/jenkins-manudal%20build1.png)
   ![manual build output](picture/jenkins-manudal%20build2.png)

6. Buka SonarQube: `http://<SONAR_IP>:9000` → project **"tanstack-demo"** → lihat hasil analisis

   ![SonarQube analysis result](picture/sonarqube-analysis-result.png)
   ![SonarQube analysis result](picture/sonarqube-analysis-result2.png)

7. Buka app: `http://<DOCKER_IP>` → website harus tampil

   ![app](picture/web-tampil.png)

### Test 2: Trigger via GitHub Push

1. Edit file apapun di repository tanstack-demo di GitHub
   (misalnya edit README.md)
2. Commit dan push ke branch main
3. Dalam 1-2 menit, Jenkins akan otomatis mulai build baru
4. Cek di Jenkins Dashboard → **"Build History"** → build baru muncul

![new](picture/new1.png)
![new](picture/new2.png)
![build history](picture/build-history.png)

### Test 3: Verifikasi Webhook Delivery

1. Buka GitHub: `https://github.com/ihyaulumuddin14/tanstack-demo/settings/hooks`
2. Klik webhook
3. Scroll ke **"Recent Deliveries"**
4. Kamu akan melihat delivery dengan status `200 OK` ✅

![webhook check](picture/webhook-delivery.png)

---

## 7. Troubleshooting

### Jenkins tidak bisa diakses (http://IP:8080)

```bash
# SSH ke Jenkins server
ssh -i labsuser.pem ubuntu@<JENKINS_IP>

# Cek status Jenkins
sudo systemctl status jenkins

# Lihat log
sudo tail -100 /var/log/user-data.log
sudo journalctl -u jenkins -n 50 --no-pager

# Restart Jenkins jika perlu
sudo systemctl restart jenkins
```

### Gagal dapat initial password

```bash
ssh -i labsuser.pem ubuntu@<JENKINS_IP>
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
# atau
cat /home/ubuntu/jenkins-info.txt
```

### SonarQube tidak bisa diakses (http://IP:9000)

```bash
ssh -i labsuser.pem ubuntu@<SONARQUBE_IP>

# Cek status
sudo systemctl status sonarqube
sudo systemctl status postgresql

# Lihat log SonarQube
sudo tail -100 /opt/sonarqube/logs/sonar.log
sudo tail -100 /opt/sonarqube/logs/web.log
sudo tail -100 /opt/sonarqube/logs/es.log  # Elasticsearch

# Cek vm.max_map_count (harus >= 524288)
sysctl vm.max_map_count

# Restart
sudo systemctl restart sonarqube
```

### Plugin tidak terinstall di Jenkins

```bash
# SSH ke Jenkins
ssh -i labsuser.pem ubuntu@<JENKINS_IP>

# Lihat log plugin installation
sudo cat /var/log/user-data.log | grep -i plugin

# Install plugin manual via Jenkins UI:
# Manage Jenkins → Plugin Manager → Available → cari nama plugin → Install
```

### Build gagal di step SonarQube

1. Cek di Jenkins Console Output – cari baris yang mengandung `ERROR`
2. Pastikan SonarQube server **online** dan token valid
3. Di Jenkins: Manage Jenkins → Configure System → SonarQube
   → klik "Test connection" (jika ada tombolnya)
4. Cek credential: Manage Jenkins → Manage Credentials
   → pastikan `sonarqube-token` ada

### Build gagal di step SSH Deploy

1. Cek Console Output di Jenkins untuk pesan error
2. Test koneksi SSH dari Jenkins ke Docker:
   ```bash
   # Di Jenkins server
   ssh -i /home/ubuntu/.ssh/id_rsa ubuntu@<DOCKER_IP>
   ```
3. Pastikan Docker server berjalan:
   ```bash
   ssh -i labsuser.pem ubuntu@<DOCKER_IP> 'sudo systemctl status docker'
   ```
4. Cek Publish Over SSH config:
   Manage Jenkins → Configure System → Publish over SSH → Test Configuration

### Webhook tidak trigger build

1. Cek GitHub webhook delivery: `Settings → Webhooks → klik webhook → Recent Deliveries`
2. Pastikan di Jenkins project: Build Triggers → "GitHub hook trigger" **tercentang**
3. Pastikan Jenkins bisa diakses dari internet (security group port 8080 open)
4. Pastikan URL webhook benar: `http://<JENKINS_IP>:8080/github-webhook/` (dengan trailing slash!)

### IP berubah setelah AWS Academy session restart

```bash
# Update semua resource Terraform dengan IP baru
terraform apply

# Post-provision script untuk lihat IP baru
./post-provision.sh

# Perbarui konfigurasi Jenkins Publish Over SSH dengan IP Docker yang baru:
# Manage Jenkins → Configure System → Publish over SSH → Update Hostname
```

---

## 8. Apa yang Otomatis vs Manual

### ✅ OTOMATIS (Terraform)

| Resource           | Keterangan                                                               |
| ------------------ | ------------------------------------------------------------------------ |
| EC2 Jenkins        | Install Java, Jenkins, plugins via user_data                             |
| EC2 SonarQube      | Install PostgreSQL, SonarQube, config sebagai service                    |
| EC2 Docker         | Install Docker CE, Docker Compose, buat direktori app                    |
| Security Groups    | Jenkins (22,8080,50000), SonarQube (22,9000), Docker (22,80,443,3000)    |
| **GitHub Webhook** | **Dibuat via `integrations/github` provider, langsung point ke Jenkins** |
| Resource Tags      | Semua resource diberi tag `Project = tanstack-demo-cicd`                 |
| AMI Selection      | Otomatis pilih Ubuntu 22.04 LTS terbaru                                  |
| Outputs            | Semua URL, IP, SSH commands tampil otomatis                              |

### ✋ MANUAL (Jenkins Web UI)

| Konfigurasi                           | Di Mana                    | Alasan Manual                       |
| ------------------------------------- | -------------------------- | ----------------------------------- |
| Login Jenkins + Setup Wizard          | Jenkins UI                 | Butuh interaksi user                |
| Ganti password SonarQube              | SonarQube UI               | Keamanan                            |
| Buat SonarQube project + token        | SonarQube UI               | Token bersifat dinamis              |
| Tambah credential SonarQube token     | Jenkins → Credentials      | Token tidak bisa di-Terraform       |
| Configure SonarQube Server di Jenkins | Jenkins → Configure System | Butuh token dari langkah sebelumnya |
| Configure Publish Over SSH            | Jenkins → Configure System | Butuh private key                   |
| Create Freestyle Project              | Jenkins → New Item         | Kompleks via Terraform              |
| Source Code Management                | Jenkins project config     | Spesifik project                    |
| Build Triggers (webhook)              | Jenkins project config     | Harus aktif setelah plugin ready    |
| Build Steps (SonarQube Scanner)       | Jenkins project config     | Konfigurasi analisis                |
| Build Steps (SSH Deploy)              | Jenkins project config     | Konfigurasi deployment              |

---

## 9. Cleanup

> ⚠️ Ini akan **MENGHAPUS SEMUA** resource yang dibuat. Tidak bisa di-undo!

```bash
# Lihat dulu apa yang akan dihapus
terraform plan -destroy

# Hapus semua resource
terraform destroy
```

Ketik `yes` untuk konfirmasi.

Terraform akan menghapus:

- 3 EC2 instances (Jenkins, SonarQube, Docker)
- 3 Security Groups
- 1 GitHub Webhook (dari repository tanstack-demo)

---

## Appendix: Struktur File Project

```
ci-cd/
├── main.tf                    # EC2 instances + GitHub webhook
├── variables.tf               # Input variable definitions
├── outputs.tf                 # Output values (IP, URL, commands)
├── providers.tf               # AWS + GitHub provider config
├── security-groups.tf         # Security groups untuk semua server
├── terraform.tfvars.example   # Template konfigurasi (copy → .tfvars)
├── terraform.tfvars           # Konfigurasi aktual (tidak di commit)
├── user-data-jenkins.sh       # Bootstrap Jenkins server
├── user-data-sonarqube.sh     # Bootstrap SonarQube server
├── user-data-docker.sh        # Bootstrap Docker server
├── post-provision.sh          # Summary script setelah terraform apply
└── README.md                  # Dokumentasi ini
```

---

_Dibuat dengan Terraform + AWS Academy | Aplikasi: [tanstack-demo](https://github.com/ihyaulumuddin14/tanstack-demo.git)_
