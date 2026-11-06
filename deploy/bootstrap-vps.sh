#!/usr/bin/env bash
#
# Bootstrap VPS Ubuntu 24.04 untuk stack sales-app.
#
# Jalankan sebagai root pada VPS yang masih baru:
#   bash bootstrap-vps.sh
#
# Opsional:
#   SSH_PUBKEY="ssh-ed25519 AAAA... user@laptop" bash bootstrap-vps.sh
#   DEPLOY_USER=deploy SSH_PORT=22 bash bootstrap-vps.sh
#
# Catatan port SSH: UFW melihat port INTERNAL di VPS. Banyak provider
# memetakan port eksternal (mis. 20155) ke port internal 22. Karena itu
# skrip SELALU mengizinkan 22, dan menambahkan SSH_PORT kalau berbeda.
# Jangan menghapus aturan 22 hanya karena port login Anda 20155.
#
# Yang dilakukan:
#   - membuat user deploy + sudo (NOPASSWD) + akses Docker
#   - memasang public key SSH (dari root atau SSH_PUBKEY)
#   - memasang Docker Engine + Compose plugin
#   - firewall UFW (SSH, 80, 443), fail2ban, unattended-upgrades
#   - timezone Asia/Makassar, swap 2 GB
#   - hardening SSH (root login & password dimatikan) HANYA kalau key deploy ada
#
# Skrip ini idempotent: aman dijalankan ulang.

set -Eeuo pipefail

DEPLOY_USER="${DEPLOY_USER:-deploy}"
SSH_PORT="${SSH_PORT:-22}"
SSH_PUBKEY="${SSH_PUBKEY:-}"

log() { printf '[bootstrap] %s\n' "$*"; }
warn() { printf '[bootstrap] PERINGATAN: %s\n' "$*" >&2; }
die() { printf '[bootstrap] ERROR: %s\n' "$*" >&2; exit 1; }

[[ "${EUID}" -eq 0 ]] || die "jalankan sebagai root (sudo -i lalu bash bootstrap-vps.sh)"
[[ -r /etc/os-release ]] || die "/etc/os-release tidak ada"
# shellcheck disable=SC1091
. /etc/os-release
[[ "${ID:-}" == "ubuntu" ]] || warn "distro terdeteksi '${ID:-unknown}', skrip ini diuji untuk Ubuntu"

[[ "$SSH_PORT" =~ ^[0-9]+$ ]] || die "SSH_PORT tidak valid: $SSH_PORT"

export DEBIAN_FRONTEND=noninteractive

log "update paket dasar"
apt-get update -y
apt-get install -y --no-install-recommends \
  ca-certificates curl gnupg git ufw fail2ban unattended-upgrades \
  rsync sudo adduser

# age dan rclone dipakai untuk backup; kalau repo universe belum aktif,
# jangan gagalkan seluruh bootstrap.
apt-get install -y --no-install-recommends age rclone \
  || warn "age/rclone gagal dipasang; backup terenkripsi/offsite harus disiapkan manual"

log "set timezone Asia/Makassar (hanya host; container tetap UTC)"
timedatectl set-timezone Asia/Makassar

log "siapkan swap 2 GB"
if ! swapon --show=NAME --noheadings | grep -qx '/swapfile'; then
  if [[ ! -f /swapfile ]]; then
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile >/dev/null
  fi
  swapon /swapfile
  grep -qE '^/swapfile[[:space:]]' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  log "swap aktif"
else
  log "swap sudah aktif, dilewati"
fi

log "buat user $DEPLOY_USER"
if ! id "$DEPLOY_USER" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "$DEPLOY_USER"
else
  log "user $DEPLOY_USER sudah ada"
fi

install -d -m 700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh"

if [[ -s /root/.ssh/authorized_keys ]]; then
  install -m 600 -o "$DEPLOY_USER" -g "$DEPLOY_USER" \
    /root/.ssh/authorized_keys "/home/$DEPLOY_USER/.ssh/authorized_keys"
  log "public key root disalin ke $DEPLOY_USER"
fi

if [[ -n "$SSH_PUBKEY" ]]; then
  printf '%s\n' "$SSH_PUBKEY" >> "/home/$DEPLOY_USER/.ssh/authorized_keys"
  chown "$DEPLOY_USER:$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh/authorized_keys"
  chmod 600 "/home/$DEPLOY_USER/.ssh/authorized_keys"
  log "SSH_PUBKEY ditambahkan"
fi

DEPLOY_KEY_OK=0
if [[ -s "/home/$DEPLOY_USER/.ssh/authorized_keys" ]]; then
  DEPLOY_KEY_OK=1
fi

log "sudo NOPASSWD untuk $DEPLOY_USER"
echo "$DEPLOY_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-$DEPLOY_USER"
chmod 440 "/etc/sudoers.d/90-$DEPLOY_USER"
visudo -cf "/etc/sudoers.d/90-$DEPLOY_USER" >/dev/null

log "pasang Docker Engine + Compose plugin"
install -m 0755 -d /etc/apt/keyrings
if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
fi
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
usermod -aG docker "$DEPLOY_USER"

log "konfigurasi firewall UFW"
ufw default deny incoming
ufw default allow outgoing
# 22 selalu diizinkan: ini port internal sshd, meskipun login eksternal
# memakai port lain lewat NAT provider.
ufw allow 22/tcp
if [[ "$SSH_PORT" != "22" ]]; then
  ufw allow "$SSH_PORT/tcp"
fi
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

log "konfigurasi fail2ban"
cat > /etc/fail2ban/jail.d/sshd.local <<EOF
[sshd]
enabled = true
port = $SSH_PORT
maxretry = 5
bantime = 1h
findtime = 10m
EOF
systemctl enable --now fail2ban
systemctl restart fail2ban

log "aktifkan update keamanan otomatis"
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
systemctl enable --now unattended-upgrades

if [[ "$DEPLOY_KEY_OK" -eq 1 ]]; then
  log "hardening SSH (root login & password dimatikan)"
  cat > /etc/ssh/sshd_config.d/99-sales-hardening.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
EOF
  if ! sshd -t; then
    rm -f /etc/ssh/sshd_config.d/99-sales-hardening.conf
    die "konfigurasi sshd tidak valid; hardening dibatalkan"
  fi
  systemctl reload ssh
else
  warn "public key untuk $DEPLOY_USER belum ada."
  warn "Hardening SSH DILEWATI supaya tidak terkunci. Tambahkan key lalu jalankan ulang skrip."
fi

cat <<EOF

[bootstrap] selesai.

Langkah berikutnya (login sebagai $DEPLOY_USER, bukan root):

  ssh -p <port-SSH-Anda> $DEPLOY_USER@<IP-VPS>

  # clone repo (publik)
  sudo mkdir -p /opt/sales-app
  sudo chown $DEPLOY_USER:$DEPLOY_USER /opt/sales-app
  git clone https://github.com/BagasRinn/sales-app.git /opt/sales-app

  # siapkan environment
  cd /opt/sales-app/deploy
  cp .env.production.example .env.production
  chmod 600 .env.production
  # isi API_DOMAIN, POSTGRES_*, SECRET_KEY, CORS_ORIGINS

Catatan:
  - Grup docker baru aktif setelah login ulang. Keluar lalu masuk lagi,
    atau jalankan: newgrp docker
  - Cek firewall: sudo ufw status
  - Cek Docker: docker run --rm hello-world
EOF
