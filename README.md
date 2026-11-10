# ESP3D para la Sunlu S8 — cámara, SD por WiFi, relés y apagado automático

Accesorio WiFi para la impresora **Sunlu S8** (Marlin) basado en **ESP3D v3.1.3** sobre un **ESP32-S3 con cámara**.

- Sube los G-code por WiFi a la microSD de la placa y los imprime (botón ▶).
- Muestra la cámara en una página propia con el avance de la impresión.
- Enciende y apaga la impresora y la luz con un módulo de 2 relés.
- Apaga la impresora sola al terminar, cuando el hotend ya se enfrió.

Estado al 10/11/2026: **funcionando** en http://192.168.1.15 (IP reservada en el router por MAC). Pendiente de probar
con la impresora: los relés conectados y el apagado al final de una impresión (ver [Pendiente](#pendiente)).

## Contenido

| Ruta | Qué es |
|---|---|
| `firmware/placa-camara.patch` | Cambios sobre ESP3D v3.1.3 para la placa con cámara (la que está en uso) |
| `firmware/placa-sin-camara.patch` | Cambios para la primera placa, ESP32-S3 sin PSRAM (de repuesto) |
| `preparar.sh` | Baja ESP3D v3.1.3, aplica el parche y copia la interfaz |
| `webui/index.html.gz` | ESP3D-WEBUI v3.1.0 para Marlin (`dist/Printer3D/Marlin/` de luc-github/ESP3D-WEBUI) |
| `webui/cam.html` | Página de la cámara: imagen, avance, relés |
| `gcode/fin_con_apagado.gcode` | Final de G-code para Cura que apaga la impresora al enfriarse |
| `enfocar.sh` | Ayuda para enfocar el lente |

El código completo de ESP3D (≈270 MB con librerías) no se sube: `preparar.sh` lo reconstruye exacto.

## Hardware

### Placa con cámara (en uso)

- ESP32-S3R8, 16 MB de flash y 8 MB de PSRAM octal. MAC **28:84:85:54:35:ec**. Puerto COM con CH340.
- Cámara con pines de ESP32-S3-EYE / Freenove ESP32-S3 CAM.
- microSD propia en SDIO de 1 bit: CMD 38, CLK 39, D0 40. **FAT32**: una de 64 GB en exFAT no montó.
- Puerto **USB** (nativo del S3) como **anfitrión** hacia el USB de la impresora (CH340), con adaptador OTG.
  - El USB de la impresora no da corriente: la placa se alimenta por su puerto COM con un cargador de 5 V de 1 A o más.

### Primera placa (repuesto)

ESP32-S3 de 16 MB **sin PSRAM**, MAC e0:72:a1:d6:63:a0, puerto COM CH343. Sin cámara ni SD. Usa el entorno
`esp32-s3-luis` (memoria `qio_qspi`). El entorno `esp32-s3` de fábrica espera PSRAM octal y la deja colgada al arrancar.

### Relés (módulo Steren de 2 relés, entrada de 3.3 V)

| Módulo | Placa | Función |
|---|---|---|
| IN1 | **GPIO 21** | Impresora |
| IN2 | **GPIO 14** | Luz |
| VCC | 5 V (o 3.3 V si el módulo lo pide) | |
| GND | GND | |

Del lado de 127 V:

| Relé | Contactos | Comportamiento |
|---|---|---|
| Relé 1 | Común y **NC**, en la fase de la impresora | En reposo la impresora está **encendida**: si la placa se reinicia, se cuelga o se queda sin corriente, la impresión sigue. **Energizado = impresora apagada.** |
| Relé 2 | Común y **NA**, en la fase de la fuente de la luz | Energizado = luz encendida |

- El módulo se configuró **activo con LOW** (lo normal con optoacoplador). Si resulta activo con HIGH, cambiar
  `LUIS_RELE_ACTIVO` en `configuration.h` y `ACTIVO` en `cam.html`.
- Si el relé no suelta del todo con 3.3 V: quitar el puente JD-VCC, VCC a 3.3 V y JD-VCC a 5 V.
- **Todo va a una barra con interruptor:** apagarla corta todo. Al encenderla, la impresora arranca de inmediato porque
  el relé 1 está en reposo.

### Cámara y luz

- El lente es de enfoque fijo. Para ver de cerca (10–30 cm) se desenrosca entre ¼ y 1 vuelta; luego una gota de barniz
  de uñas en la rosca.
- **Enfocar:** correr `./enfocar.sh` y girar poco a poco buscando el número más alto. Con la misma escena, la foto más
  nítida es la que más pesa.
- **Fotos movidas:** fijar la cámara al marco (no a la cama, que se mueve en Y) y poner luz.
- **Luz:** blanca de 4000–6500 K en la parte superior de cada nicho, apuntando hacia atrás para que la cámara no vea
  los LEDs. Tira de 12 V con difusor y una fuente que no parpadee.

## Firmware

### Reconstruir y grabar

```
./preparar.sh camara                     # o: ./preparar.sh sin-camara
cd build/ESP3D-3.1.3-camara
~/.platformio/penv/bin/pio run -e esp32-s3-camara -t upload   --upload-port /dev/ttyUSB0
~/.platformio/penv/bin/pio run -e esp32-s3-camara -t uploadfs --upload-port /dev/ttyUSB0   # interfaz y cam.html
```

- PlatformIO: `~/.platformio/penv/bin/pio`.
- **Antes de grabar**, confirmar la placa: `esptool.py --port /dev/ttyUSB0 read_mac`. En la PC hay otros CH340, como
  la pantalla del tótem.
- Grabar por USB conserva los ajustes de la placa: WiFi, salida USB y velocidad.
- **`uploadfs` borra** lo que se haya subido a mano al sistema de archivos de la placa. Por eso `cam.html` va en `esp3d/data/`.
- Al reiniciarse la placa **se reinicia también la impresora** (se reabre su USB). No grabar durante una impresión.

### Qué cambia el parche de la placa con cámara

| Archivo | Cambio | Por qué |
|---|---|---|
| `platformio.ini` | Entorno `esp32-s3-camara`: 16 MB, `default_16MB.csv`, `qio_opi`, LittleFS | Memoria de esta placa |
| `configuration.h` | `USB_SERIAL_FEATURE`, `DEFAULT_FW MARLIN`, SD `ESP_NOT_SHARED_SD` + `ESP_SDIO` 1 bit 38/39/40, `CAMERA_MODEL_ESP32S3_EYE`, `CAMERA_DEVICE_FLIP_HORIZONTALY`, `LUIS_RELE_*` | Hardware de esta placa |
| `camera.cpp` | 640×480 (era 800×600) y calidad JPEG 12 (era 5) | Fotos de ≈12–17 KB: menos carga para la placa |
| `esp3d.cpp` | Pone los relés en reposo lo primero al arrancar | Que la impresora no se apague al reiniciar la placa |
| `ESP800.cpp` | Reporta `"Streaming":"Enabled"` | Sin esto la WEBUI 3.1.0 no muestra el ▶ en la SD de la placa |
| `ESP700.cpp` | Acepta `stream=/sd/archivo` y lo convierte a `/SD/archivo` | Es lo que manda el ▶ de la WEBUI 3.1.0 |
| `gcode_host.cpp` | Cualquier línea de Marlin mientras espera el `ok` reinicia el plazo de 16 s | Sin esto, una orden larga (M190, M109, G28, G29, G4) aborta la impresión desde la SD de la placa |

El parche de la placa sin cámara sólo trae `platformio.ini` (entorno `esp32-s3-luis`) y `configuration.h`.

### Ajustes que se hacen una vez (quedan guardados en la placa)

- `[ESP950]USB`: ESP3D 3.1.3 trae la salida sin definir ("output: ???").
- `[ESP902]250000`: el Marlin de la S8 trabaja a 250000; a 115200 no contesta.
- Red de la casa en modo estación. Sin red, ESP3D abre su propia red `ESP3D` (contraseña `12345678`) en http://192.168.0.1.
- En la WEBUI: **Ajustes → Interfaz → SD** activado, para que aparezca la SD de la placa. Se guarda en cada placa.

## Uso

### Páginas

- **http://192.168.1.15/cam.html**: la página del día a día (pestaña "Sunlu-S8-B Cam"). Se adapta a la PC y al celular.
  - Imagen en vivo, con pausar, girar 90°, ritmo de las fotos, guardar foto y pantalla completa.
  - Avance de la impresión desde la SD de la placa: porcentaje, archivo, transcurrido, restante aproximado.
  - **Control:** interruptores de la impresora y de la luz.
- **http://192.168.1.15/**: ESP3D-WEBUI completa (archivos, consola, temperaturas, macros).
- **http://192.168.1.15/snap**: una foto suelta.

### Imprimir

1. En la WEBUI, en **Archivos → SD**, subir el G-code. Pueden ser archivos grandes (30 MB o más), sólo tardan más.
2. Darle **▶**. La placa manda el archivo línea por línea y tiene que seguir encendida hasta el final.
3. Ver el avance en `cam.html`.

Desde la consola también se puede: `[ESP700]/SD/archivo.gcode`, y `[ESP701]action=PAUSE`, `RESUME` o `ABORT`.

**Cámara e impresión:** la placa atiende la página y manda el G-code en el mismo ciclo. Con su WiFi lento (≈9 KB/s),
cada foto frena el envío ≈1–1.5 s, lo que puede dejar grumos en curvas. Por eso `cam.html` baja sola a una foto cada
30 s mientras imprime. Con **Pausar**, o con la pestaña en segundo plano, no pide fotos.

### Apagado automático al terminar

Pegar `gcode/fin_con_apagado.gcode` **al final** del G-code final de la impresora en Cura. Al terminar la pieza:

1. Apaga hotend, cama y ventilador de capa.
2. Espera con `M109 R50` a que el hotend baje a 50 °C, y luego 60 s más con el ventilador del disipador.
3. Con `[ESP201]P=21 V=0` energiza el relé 1 y apaga la impresora. La placa y la cámara siguen encendidas.

- Sólo funciona **imprimiendo desde la SD de la placa**: ESP3D ejecuta las líneas `[ESP…]` del archivo. Desde la SD de la
  impresora, Marlin la ignora y la impresora queda encendida.
- Para volver a encenderla: interruptor **Impresora** en `cam.html`, o apagar y prender la barra.

### Apagar a mano desde la página

El interruptor **Impresora**:
- no apaga mientras haya una impresión desde la SD de la placa;
- si el hotend está a 50 °C o más, ofrece apagarla sola cuando se enfríe (con la pestaña abierta; tocar el interruptor
  lo cancela);
- siempre pide confirmación.

Para leer la temperatura abre el websocket de ESP3D (puerto 81). Eso desconecta la WEBUI completa si está abierta en
otra pestaña: recargarla.

### Comandos útiles

| Comando | Qué hace |
|---|---|
| `[ESP800]` | Versión y capacidades |
| `[ESP420]` | Estado: WiFi, señal, memoria |
| `[ESP170]` | Ajustes de la cámara; en caliente `framesize=8` (640×480), `quality=12`, `hmirror=1`, `vflip=1`. Se pierden al reiniciar |
| `[ESP201]P=21 V=0` / `V=1` | Impresora apagada / encendida |
| `[ESP201]P=14 V=0` / `V=1` | Luz encendida / apagada |
| `[ESP600]mensaje` | Notificación (correo: token1 = usuario SMTP, token2 = contraseña de aplicación, ajustes `correo#smtp.server:465`) |

## Pendiente

- Conectar el módulo de relés y confirmar la polaridad (LOW = activo) y que suelte con 3.3 V.
- Probar con la impresora la lectura de la temperatura en `cam.html` y una impresión completa con `fin_con_apagado.gcode`.
  Ya está probado sin impresora que ESP3D ejecuta `[ESP201]` desde un archivo de la SD.
- Confirmar que el Marlin de la S8 manda mensajes mientras espera (`M109`, `G4`), que es lo que mantiene viva la
  impresión con el arreglo de `gcode_host.cpp`.
- No se puede subir a la SD de la impresora desde la WEBUI: sólo lo permite el protocolo MKS.
- No hay complemento de Cura para ESP3D. Opciones: WebDAV o un script de envío.
