#!/usr/bin/env bash
#
# Restore dump ke database produksi di container db.
#
# PERINGATAN: skrip ini MENGHAPUS seluruh schema public sebelum restore.
# Hentikan API dulu (skrip melakukannya otomatis) dan pastikan backup terbaru
# sudah ada.
#
# Pemakaian:
#   ./restore.sh /var/backups/sales/sales-20261106T120000Z.dump.age
#   ./restore.sh --yes /var/backups/sales/sales-20261106T120000Z.dump
#
# File .age akan didekripsi otomatis (butuh private key age di host).

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/compose.prod.yaml"
ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/.env.production}"

usage() {
  cat >&2 <<'EOF'
Pemakaian: ./restore.sh [--yes] <file.dump|file.dump.age>

  --yes   lewati konfirmasi interaktif (hati-hati)
EOF
}

YES=0
DUMP=""
for arg in "$@"; do
  case "$arg" in
    --yes|-y) YES=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Opsi tidak dikenal: $arg" >&2; usage; exit 1 ;;
    *) DUMP="$arg" ;;
  esac
done

[[ -n "$DUMP" ]] || { usage; exit 1; }
[[ -f "$DUMP" ]] || { echo "File tidak ditemukan: $DUMP" >&2; exit 1; }
[[ -f "$ENV_FILE" ]] || { echo "Env file tidak ditemukan: $ENV_FILE" >&2; exit 1; }
[[ -f "$COMPOSE_FILE" ]] || { echo "Compose file tidak ditemukan: $COMPOSE_FILE" >&2; exit 1; }
command -v docker >/dev/null || { echo "docker tidak terpasang" >&2; exit 1; }

COMPOSE=(docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE")

if [[ "$YES" -ne 1 ]]; then
  echo "PERINGATAN: semua data di schema public database produksi akan DIHAPUS."
  echo "Sumber restore: $DUMP"
  read -r -p "Ketik 'RESTORE' untuk melanjutkan: " answer
  [[ "$answer" == "RESTORE" ]] || { echo "Dibatalkan."; exit 1; }
fi

WORKDIR="$(mktemp -d)"
cleanup() { rm -rf "$WORKDIR"; }

api_stopped=0
on_exit() {
  status=$?
  if [[ "$api_stopped" -eq 1 && "$status" -ne 0 ]]; then
    echo "Restore gagal. API dibiarkan berhenti agar tidak melayani data parsial." >&2
    echo "Perbaiki masalah lalu jalankan: ${COMPOSE[*]} start api" >&2
  fi
  cleanup
}
trap on_exit EXIT

SOURCE="$DUMP"
if [[ "$DUMP" == *.age ]]; then
  command -v age >/dev/null || { echo "File .age tapi perintah age tidak ada" >&2; exit 1; }
  echo "==> Dekripsi $DUMP"
  SOURCE="$WORKDIR/restore.dump"
  age --decrypt --output "$SOURCE" "$DUMP"
fi

echo "==> Salin dump ke container db"
"${COMPOSE[@]}" exec -T db sh -c 'cat > /tmp/restore.dump' < "$SOURCE"

echo "==> Validasi arsip"
"${COMPOSE[@]}" exec -T db pg_restore --list /tmp/restore.dump > /dev/null

echo "==> Hentikan API agar tidak ada write"
"${COMPOSE[@]}" stop api
api_stopped=1

echo "==> Kosongkan schema public"
"${COMPOSE[@]}" exec -T db sh -c \
  'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
     -c "DROP SCHEMA public CASCADE;"'

echo "==> Restore"
"${COMPOSE[@]}" exec -T db sh -c \
  'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
     --no-owner --no-privileges --exit-on-error /tmp/restore.dump'

echo "==> Bersihkan file sementara di container"
"${COMPOSE[@]}" exec -T db rm -f /tmp/restore.dump

echo "==> Jalankan API kembali"
"${COMPOSE[@]}" start api
api_stopped=0

echo "==> Tunggu health check"
domain="$(grep -E '^API_DOMAIN=' "$ENV_FILE" | tail -n1 | cut -d= -f2- | tr -d '"' || true)"
if command -v curl >/dev/null && [[ -n "$domain" ]]; then
  for _ in $(seq 1 30); do
    if curl -fsS "https://$domain/health" >/dev/null 2>&1; then
      echo "health OK: https://$domain/health"
      break
    fi
    sleep 2
  done
else
  echo "Lewati health check (curl tidak ada atau API_DOMAIN kosong)."
fi

echo
echo "Restore selesai. Verifikasi manual:"
echo "  ${COMPOSE[*]} ps"
echo "  ${COMPOSE[*]} logs --tail=100 api"
