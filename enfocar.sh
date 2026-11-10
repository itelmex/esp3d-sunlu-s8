#!/bin/bash
# Ayuda para enfocar la camara de ESP3D: toma fotos seguidas y muestra su "nitidez".
# Con la misma escena y la misma calidad, una foto enfocada pesa mas (tiene mas detalle).
# Gira el lente muy poco entre lecturas y busca el numero mas alto.
IP=${1:-192.168.1.15}
max=0
echo "Enfocando $IP  (Ctrl+C para salir). No muevas la camara ni cambies la luz."
while true; do
  b=$(curl -s -m10 -o /dev/null -w '%{size_download}' "http://$IP/snap")
  [ "$b" -gt "$max" ] && max=$b
  n=$(( b * 50 / (max>0?max:1) ))
  printf '%6d B  %-50s  mejor: %d\n' "$b" "$(printf '#%.0s' $(seq 1 $n))" "$max"
done
