#!/bin/bash
# Reconstruye el codigo de ESP3D v3.1.3 con los cambios de este repo, listo para compilar con PlatformIO.
#   ./preparar.sh camara       -> build/ESP3D-3.1.3-camara     (entorno esp32-s3-camara)
#   ./preparar.sh sin-camara   -> build/ESP3D-3.1.3            (entorno esp32-s3-luis)
set -e
cd "$(dirname "$0")"
case "$1" in
  camara)     parche=firmware/placa-camara.patch;     dest=build/ESP3D-3.1.3-camara; env=esp32-s3-camara ;;
  sin-camara) parche=firmware/placa-sin-camara.patch; dest=build/ESP3D-3.1.3;        env=esp32-s3-luis ;;
  *) echo "Uso: $0 camara|sin-camara"; exit 1 ;;
esac
[ -e "$dest" ] && { echo "Ya existe $dest: borralo primero si quieres rehacerlo."; exit 1; }
mkdir -p build
git clone -q --depth 1 --branch v3.1.3 https://github.com/luc-github/ESP3D.git "$dest"
rm -rf "$dest/.git"
git apply --directory="$dest" "$parche"
mkdir -p "$dest/esp3d/data"
cp webui/index.html.gz "$dest/esp3d/data/"
[ "$1" = camara ] && cp webui/cam.html "$dest/esp3d/data/"
echo "Listo: $dest"
echo "  cd $dest && ~/.platformio/penv/bin/pio run -e $env -t upload --upload-port /dev/ttyUSB0"
