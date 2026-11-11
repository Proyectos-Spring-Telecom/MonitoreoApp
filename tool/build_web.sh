#!/usr/bin/env bash
# Compila la PWA para publicar.
#
#   tool/build_web.sh                       # en /ordenservicioapp/
#   BASE_HREF=/otra-ruta/ tool/build_web.sh # en otra ruta
#   tool/build_web.sh --dart-define=API_BASE_URL=https://...
#
# Además de `flutter build web`, marca la compilación con un número
# (fecha + commit) en sw.js, pwa.js y build.json. Con él la app detecta que se
# publicó una versión nueva y el service worker borra la caché anterior.
set -euo pipefail

cd "$(dirname "$0")/.."

BASE_HREF="${BASE_HREF:-/ordenservicioapp/}"
case "$BASE_HREF" in
  /*/) ;;
  *) echo "BASE_HREF debe empezar y terminar con /: $BASE_HREF" >&2; exit 1 ;;
esac

COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo local)"
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then COMMIT="$COMMIT-cambios"; fi
BUILD_ID="$(date +%Y%m%d%H%M%S)-$COMMIT"

# --no-web-resources-cdn: el motor de Flutter (CanvasKit) se sirve desde
# nuestro servidor y no desde gstatic.com, así queda en la caché offline.
flutter build web --release --no-web-resources-cdn --base-href "$BASE_HREF" "$@"

OUT=build/web
for file in "$OUT/sw.js" "$OUT/pwa.js"; do
  sed -i.bak "s/__BUILD_ID__/$BUILD_ID/g" "$file" && rm "$file.bak"
done
printf '{"build":"%s"}\n' "$BUILD_ID" > "$OUT/build.json"

echo
echo "Compilación $BUILD_ID lista en $OUT/ (ruta $BASE_HREF)."
