#!/usr/bin/env bash
#
# Backup logis PostgreSQL dari container db.
#
# Contoh cron (user deploy):
#   15 2 * * * /opt/sales-app/deploy/backup.sh >> /var/log/sales-backup.log 2>&1
#
# Variabel yang dibaca (dari environment atau deploy/backup.env):
#   BACKUP_DIR      folder tujuan (default /var/backups/sales)
#   BULLETINS_DIR   folder PDF bulletin (default <deploy>/bulletins)
#   RETENTION_DAYS  hapus backup lebih tua dari N hari (default 14)
#   AGE_RECIPIENT   public key age untuk enkripsi (sangat disarankan)
#   RCLONE_REMOTE   remote rclone untuk upload offsite (opsional)
#
# Jalankan dengan: ./backup.sh

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/compose.prod.yaml"
ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/.env.production}"
BACKUP_ENV="${BACKUP_ENV:-$SCRIPT_DIR/backup.env}"

if [[ -f "$BACKUP_ENV" ]]; then
  # shellcheck disable=SC1090
  set -a
  . "$BACKUP_ENV"
  set +a
fi

BACKUP_DIR="${BACKUP_DIR:-/var/backups/sales}"
BULLETINS_DIR="${BULLETINS_DIR:-$SCRIPT_DIR/bulletins}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
AGE_RECIPIENT="${AGE_RECIPIENT:-}"
RCLONE_REMOTE="${RCLONE_REMOTE:-}"

log() { printf '[%s] %s\n' "$(date -u +%FT%TZ)" "$*"; }
die() { log "ERROR: $*"; exit 1; }

[[ -f "$ENV_FILE" ]] || die "env file tidak ditemukan: $ENV_FILE"
[[ -f "$COMPOSE_FILE" ]] || die "compose file tidak ditemukan: $COMPOSE_FILE"
command -v docker >/dev/null || die "docker tidak terpasang"

COMPOSE=(docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE")

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"
umask 077

# Cegah dua backup berjalan bersamaan.
exec 9>"$BACKUP_DIR/.backup.lock"
if command -v flock >/dev/null; then
  flock -n 9 || { log "backup lain masih berjalan, keluar."; exit 0; }
fi

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$BACKUP_DIR/sales-$STAMP.dump"

log "mulai dump ke $OUT"
"${COMPOSE[@]}" exec -T db sh -c \
  'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
     --format=custom --compress=9 \
     --no-owner --no-privileges \
     --lock-wait-timeout=60s' > "$OUT"

[[ -s "$OUT" ]] || die "dump kosong, proses dibatalkan"

# Pastikan arsip bisa dibaca sebelum dianggap backup sah.
"${COMPOSE[@]}" exec -T db pg_restore --list < "$OUT" > /dev/null \
  || die "arsip dump tidak valid"

FINAL="$OUT"
if [[ -n "$AGE_RECIPIENT" ]]; then
  command -v age >/dev/null || die "AGE_RECIPIENT diset tapi perintah age tidak ada"
  log "enkripsi dengan age"
  age --encrypt --recipient "$AGE_RECIPIENT" --output "$OUT.age" "$OUT"
  rm -f "$OUT"
  FINAL="$OUT.age"
else
  log "PERINGATAN: AGE_RECIPIENT kosong, backup tersimpan tanpa enkripsi"
fi

if command -v sha256sum >/dev/null; then
  ( cd "$BACKUP_DIR" && sha256sum "$(basename "$FINAL")" ) > "$FINAL.sha256"
fi

# ── Backup file PDF bulletin (local storage di VPS) ─────────────────────────
BULLETIN_ARCHIVE=""
if [[ -d "$BULLETINS_DIR" ]] && \
   [[ -n "$(find "$BULLETINS_DIR" -maxdepth 1 -type f -name '*.pdf' -print -quit)" ]]; then
  BULLETIN_OUT="$BACKUP_DIR/bulletins-$STAMP.tar.gz"
  log "mulai arsip bulletin ke $BULLETIN_OUT"
  tar -C "$BULLETINS_DIR" -czf "$BULLETIN_OUT" .
  BULLETIN_ARCHIVE="$BULLETIN_OUT"

  if [[ -n "$AGE_RECIPIENT" ]]; then
    age --encrypt --recipient "$AGE_RECIPIENT" --output "$BULLETIN_OUT.age" "$BULLETIN_OUT"
    rm -f "$BULLETIN_OUT"
    BULLETIN_ARCHIVE="$BULLETIN_OUT.age"
  fi

  if command -v sha256sum >/dev/null; then
    ( cd "$BACKUP_DIR" && sha256sum "$(basename "$BULLETIN_ARCHIVE")" ) > "$BULLETIN_ARCHIVE.sha256"
  fi

  if [[ -n "$RCLONE_REMOTE" ]]; then
    rclone copy "$BULLETIN_ARCHIVE" "$RCLONE_REMOTE" --checksum
    [[ -f "$BULLETIN_ARCHIVE.sha256" ]] && \
      rclone copy "$BULLETIN_ARCHIVE.sha256" "$RCLONE_REMOTE" --checksum
  fi
else
  log "tidak ada PDF bulletin di $BULLETINS_DIR, lewati arsip file"
fi

if [[ -n "$RCLONE_REMOTE" ]]; then
  command -v rclone >/dev/null || die "RCLONE_REMOTE diset tapi rclone tidak ada"
  log "upload ke $RCLONE_REMOTE"
  rclone copy "$FINAL" "$RCLONE_REMOTE" --checksum
  [[ -f "$FINAL.sha256" ]] && rclone copy "$FINAL.sha256" "$RCLONE_REMOTE" --checksum
else
  log "RCLONE_REMOTE kosong, backup hanya tersimpan lokal"
fi

log "hapus backup lebih tua dari $RETENTION_DAYS hari"
find "$BACKUP_DIR" -maxdepth 1 -type f \
  \( -name 'sales-*' -o -name 'bulletins-*' \) \
  -mtime +"$RETENTION_DAYS" -delete

SIZE="$(du -h "$FINAL" | cut -f1)"
log "selesai: $FINAL ($SIZE)"
if [[ -n "$BULLETIN_ARCHIVE" ]]; then
  log "selesai: $BULLETIN_ARCHIVE ($(du -h "$BULLETIN_ARCHIVE" | cut -f1))"
fi
