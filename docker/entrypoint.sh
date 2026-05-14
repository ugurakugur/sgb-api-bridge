#!/bin/sh
set -e

# Komut dispatcher. K8s'de "command/args" ile, Docker'da direkt argument ile cagrilir.
#
# Modlar:
#   all-in-one   : nginx + python loop (default)
#   loop         : sadece python loop
#   serve        : sadece nginx
#   sync-once    : tek seferlik sync; ikinci arg full|delta|healthcheck
#   sh / bash    : interaktif shell (debug)

MODE="${1:-all-in-one}"
shift 2>/dev/null || true

DATA_ROOT="${SGB_BRIDGE_ROOT:-/data}"

# Veri dizinleri yoksa olustur
mkdir -p "$DATA_ROOT/docs" "$DATA_ROOT/state"

# Seed: volume/PVC bos ise imaja gomulu gecmis veriyi kopyala.
# Boylece fresh container full sync'e gerek kalmadan delta'dan devam eder.
# -n (no-clobber): mevcut volume verisinin uzerine asla yazmaz.
if [ ! -f "$DATA_ROOT/state/seen_ids.json" ] && [ -d /app/seed ]; then
  echo "[entrypoint] $DATA_ROOT bos - imajdaki seed verisi kopyalaniyor"
  cp -rn /app/seed/docs/. "$DATA_ROOT/docs/" 2>/dev/null || true
  cp -rn /app/seed/state/. "$DATA_ROOT/state/" 2>/dev/null || true
  echo "[entrypoint] seed tamamlandi"
fi

case "$MODE" in
  all-in-one)
    echo "[entrypoint] all-in-one mode: nginx + python loop (delta)"
    nginx
    exec python /app/sync.py --mode loop
    ;;
  loop)
    echo "[entrypoint] loop mode: sadece sync"
    exec python /app/sync.py --mode loop
    ;;
  serve)
    echo "[entrypoint] serve mode: sadece nginx"
    exec nginx -g 'daemon off;'
    ;;
  sync-once)
    SUBMODE="${1:-delta}"
    echo "[entrypoint] sync-once: $SUBMODE"
    exec python /app/sync.py --mode "$SUBMODE"
    ;;
  healthcheck)
    exec python /app/sync.py --mode healthcheck
    ;;
  sh|bash)
    exec /bin/sh
    ;;
  *)
    # Bilinmeyen komut: direkt exec
    exec "$MODE" "$@"
    ;;
esac
