# ESP3D para la Sunlu S8 — cámara, SD por WiFi, relés y apagado automático

Accesorio WiFi para la impresora **Sunlu S8** (Marlin) sobre un **ESP32-S3 con cámara**.

> **Basado en [ESP3D](https://github.com/luc-github/ESP3D) v3.1.3** (etiqueta `v3.1.3`, 22/07/2026) de Luc Lebosse y
> colaboradores, y en **[ESP3D-WEBUI](https://github.com/luc-github/ESP3D-WEBUI) v3.1.0** (Printer3D / Marlin).
> Este repositorio sólo contiene los cambios sobre esa versión (`firmware/*.patch`), una página propia para la cámara
> y la documentación. El mérito de ESP3D es de sus autores; ver [Créditos](#créditos).

Sirve para cualquier impresora con Marlin por USB; la Sunlu S8 es la que está probada. Los datos de mi instalación
(IP 192.168.1.15, MAC de las placas, nombre "Sunlu-S8-B") son ejemplos: cada quien pone los suyos.

- Sube los G-code por WiFi a la microSD de la placa y los imprime (botón ▶).
- Muestra la cámara en una página propia con el avance de la impresión.
- Enciende y apaga la impresora y la luz con un módulo de 2 relés.
- Apaga la impresora sola al terminar, cuando el hotend ya se enfrió.

Estado al 10/11/2026: **funcionando** en http://192.168.1.15 (IP reservada en el router por MAC). Probado con la impresora
el 10/11/2026: lectura de temperatura, relés y apagado por temperatura desde `cam.html`. Falta una impresión completa
con el apagado al final (ver [Pendiente](#pendiente)).

## Contenido

| Ruta | Qué es |
|---|---|
| `firmware/placa-camara.patch` | Cambios sobre ESP3D v3.1.3 para la placa con cámara (la que está en uso) |
| `firmware/placa-sin-camara.patch` | Cambios para la primera placa, ESP32-S3 sin PSRAM (de repuesto) |
| `preparar.sh` | Baja ESP3D v3.1.3, aplica el parche y copia la interfaz |
| `webui/index.html.gz` | ESP3D-WEBUI v3.1.0 para Marlin (`dist/Printer3D/Marlin/` de luc-github/ESP3D-WEBUI) |
| `webui/cam.html` | Página de la cámara: imagen, avance, relés |
| `gcode/fin_con_apagado.gcode` | Final de G-code para Cura que apaga la impresora al enfriarse |
| `binarios/` | Firmware compilado, listo para grabar (ver [Programación](#programación)) |
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

- El módulo es **activo con LOW** y conmuta bien con la señal de 3.3 V de la ESP32-S3 (probado el 10/11/2026). Con
  otro módulo activo con HIGH, cambiar `LUIS_RELE_ACTIVO` en `configuration.h` y `ACTIVO` en `cam.html`.
- Si otro módulo no suelta del todo con 3.3 V: quitar el puente JD-VCC, VCC a 3.3 V y JD-VCC a 5 V.
- **Con la impresora apagada por el relé, su pantalla sigue encendida:** la tarjeta Marlin se alimenta con los 5 V del
  cable USB de la ESP32 y sigue contestando `M105`. Los 24 V (calentadores, motores y ventiladores) sí se cortan, así que
  no puede calentar. Es normal.
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

## Programación

### Binarios listos (`binarios/`)

| Archivo | Para qué | Dirección |
|---|---|---|
| `esp3d-3.1.3-sunlu-camara-completo.zip` | **Placa nueva o desde cero.** Descomprimir: trae un `.bin` de 16 MB con todo (arranque, particiones, firmware e interfaz web con `cam.html`) | **0x0** |
| `esp3d-3.1.3-sunlu-camara-firmware.bin` | **Actualizar** una placa que ya tiene ESP3D, conservando sus ajustes | 0x10000, o por WiFi |
| `SHA256SUMS.txt` | Para comprobar que se bajaron bien | |

**Placa requerida:** ESP32-S3 con **16 MB de flash y 8 MB de PSRAM octal** (N16R8, por ejemplo "ESP32-S3 CAM" tipo
Freenove), cámara con los pines de ESP32-S3-EYE y microSD en SDIO (CMD 38, CLK 39, D0 40). Con otra placa hay que
compilar desde el código (ver abajo).

### Opción 1: en línea, desde el navegador (sin instalar nada)

1. Descomprimir `esp3d-3.1.3-sunlu-camara-completo.zip`.
2. Conectar la placa a la PC por su puerto **COM** (el del chip CH340, no el USB nativo).
3. Abrir **https://espressif.github.io/esptool-js/** en **Chrome o Edge** (Firefox no tiene Web Serial).
4. Baudrate **921600**, **Connect** y elegir el puerto. Si no conecta: mantener **BOOT**, tocar **RESET**, soltar BOOT
   y volver a intentar.
5. En *Flash Address* poner **0x0**, elegir `esp3d-3.1.3-sunlu-camara-completo.bin` y presionar **Program**. Tarda
   1–3 minutos.
6. Al terminar, tocar **RESET** (o desconectar y conectar).

El archivo completo **borra todo**, incluidos los ajustes guardados: la placa arranca de fábrica.

### Opción 2: con esptool en la terminal

```
pip install esptool
esptool.py --chip esp32s3 --port /dev/ttyUSB0 --baud 921600 write_flash 0x0 esp3d-3.1.3-sunlu-camara-completo.bin
```

En Windows el puerto es `COM3`, `COM4`, etc.

### Actualizar sin perder los ajustes

- **Por WiFi:** en la página completa de ESP3D, en la sección de actualización de firmware, subir
  `esp3d-3.1.3-sunlu-camara-firmware.bin`.
- **Por cable:** `esptool.py --chip esp32s3 --port /dev/ttyUSB0 write_flash 0x10000 esp3d-3.1.3-sunlu-camara-firmware.bin`

Ninguna de las dos toca la interfaz web ni el nombre guardado de `cam.html`.

### Primer arranque (después de grabar el completo)

1. Conectarse a la red WiFi **`ESP3D`** (contraseña **`12345678`**) y abrir **http://192.168.0.1**.
2. Configurar la red de la casa (modo estación) y cambiar la contraseña de administración.
3. En la consola de ESP3D, una sola vez:
   - `[ESP950]USB`: la salida a la impresora por USB (ESP3D 3.1.3 la trae sin definir).
   - `[ESP902]250000`: la velocidad de Marlin. La Sunlu S8 usa 250000; otras impresoras, 115200.
4. Reiniciar y entrar a la nueva IP. Conviene reservarla en el router por la MAC de la placa.
5. En la WEBUI: **Ajustes → Interfaz → SD** activado, y en **Polling** activar **Enable polling** (la lista ya trae
   `M105` cada 3000 ms; dejar uno solo). Sin esto la WEBUI se queda en "Waiting for temperatures list available from
   printer": de fábrica no le pide la temperatura a la impresora.
6. Abrir **http://<IP>/cam.html** y ponerle nombre con el lápiz.
7. Conectar el USB de la placa al de la impresora (adaptador OTG) y alimentar la placa por su puerto COM.

## Firmware

### Reconstruir y grabar desde el código

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
  También borra el nombre guardado (`camara.json`): hay que volver a ponerlo con el lápiz.
- Al reiniciarse la placa **se reinicia también la impresora** (se reabre su USB). No grabar durante una impresión.

### Qué cambia el parche de la placa con cámara

| Archivo | Cambio | Por qué |
|---|---|---|
| `platformio.ini` | Entorno `esp32-s3-camara`: 16 MB, `default_16MB.csv`, `qio_opi`, LittleFS | Memoria de esta placa |
| `configuration.h` | `USB_SERIAL_FEATURE`, `DEFAULT_FW MARLIN`, SD `ESP_NOT_SHARED_SD` + `ESP_SDIO` 1 bit 38/39/40, `CAMERA_MODEL_ESP32S3_EYE`, `CAMERA_DEVICE_FLIP_HORIZONTALY`, `LUIS_RELE_*` | Hardware de esta placa |
| `camera.cpp` | 640×480 (era 800×600) y calidad JPEG 12 (era 5) | Fotos de ≈12–17 KB: menos carga para la placa |
| `esp3d.cpp` | Pone los relés en reposo lo primero al arrancar | Que la impresora no se apague al reiniciar la placa |
| `ESP201.cpp` | Pin virtual 100 = "Apagar al terminar"; la orden de apagar desde un archivo se ignora si está desactivado | Apagado al final optativo |
| `ESP800.cpp` | Reporta `"Streaming":"Enabled"` | Sin esto la WEBUI 3.1.0 no muestra el ▶ en la SD de la placa |
| `ESP700.cpp` | Acepta `stream=/sd/archivo` y lo convierte a `/SD/archivo` | Es lo que manda el ▶ de la WEBUI 3.1.0 |
| `gcode_host.cpp` | Cualquier línea de Marlin mientras espera el `ok` reinicia el plazo de 16 s | Sin esto, una orden larga (M190, M109, G28, G29, G4) aborta la impresión desde la SD de la placa |

El parche de la placa sin cámara sólo trae `platformio.ini` (entorno `esp32-s3-luis`) y `configuration.h`.

### Ajustes que se hacen una vez (quedan guardados en la placa)

- `[ESP950]USB`: ESP3D 3.1.3 trae la salida sin definir ("output: ???").
- `[ESP902]250000`: el Marlin de la S8 trabaja a 250000; a 115200 no contesta.
- Red de la casa en modo estación. Sin red, ESP3D abre su propia red `ESP3D` (contraseña `12345678`) en http://192.168.0.1.
- En la WEBUI: **Ajustes → Interfaz → SD** activado, para que aparezca la SD de la placa, y **Polling → Enable polling**
  con un solo `M105` cada 3000 ms, para que muestre las temperaturas. Se guarda en cada placa (`preferences.json`).

## Uso

### Páginas

- **http://192.168.1.15/cam.html**: la página del día a día. Se adapta a la PC y al celular.
  - **Nombre editable** con el lápiz junto al título: nombre (también el de la pestaña) y modelo de impresora. Se guarda
    en la placa (`/camara.json`), así que se ve igual en todos los equipos. Sin nombre guardado usa el nombre de red de
    la placa + " Cam". Así la misma página sirve para cualquier impresora.
  - Imagen en vivo, con pausar, girar 90°, ritmo de las fotos, guardar foto y pantalla completa.
  - Avance de la impresión desde la SD de la placa: porcentaje, archivo, transcurrido, restante aproximado.
  - **Control:** interruptores de la impresora, de la luz y de **Apagar al terminar**.
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

**Es optativo:** se controla con el interruptor **Apagar al terminar** de `cam.html`.
- **Arranca desactivado** cada vez que la placa se enciende: al terminar, la impresora queda prendida.
- Activado, la impresora se apaga al terminar y el interruptor **vuelve solo a desactivado** (se usa una vez).
  Se puede activar con la impresión en curso, por ejemplo en la noche.
- Vive en la RAM del firmware (pin virtual 100 de `[ESP201]`): `[ESP201]P=100 V=1` lo activa y `[ESP201]P=100` lo lee.
  Sólo afecta a la orden de apagar que viene **de un archivo en impresión**; el interruptor **Impresora** de la página
  apaga siempre.

Pegar `gcode/fin_con_apagado.gcode` **al final** del G-code final de la impresora en Cura y dejarlo siempre. Al terminar la pieza:

1. Apaga hotend, cama y ventilador de capa.
2. Espera con `M109 R50` a que el hotend baje a 50 °C, y luego 60 s más con el ventilador del disipador.
3. Con `[ESP201]P=21 V=0` energiza el relé 1 y apaga la impresora, si el interruptor está activado. La placa y la
   cámara siguen encendidas.

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

- Una impresión completa desde la SD de la placa con `fin_con_apagado.gcode`.
  Ya está probado sin impresora que ESP3D ejecuta `[ESP201]` desde un archivo de la SD, y que lo ignora o lo ejecuta
  según el interruptor (que vuelve a desactivado después).
- Ya probado con la impresora: `M105` contesta `ok T:27.95 /0.00 B:27.93 /0.00 @:0 B@:0` y `cam.html` lo lee; con el
  hotend a 60 °C ofreció esperar, y al bajar de 50 °C activó el relé y la impresora se apagó.
- Confirmar que el Marlin de la S8 manda mensajes mientras espera (`M109`, `G4`), que es lo que mantiene viva la
  impresión con el arreglo de `gcode_host.cpp`.
- No se puede subir a la SD de la impresora desde la WEBUI: sólo lo permite el protocolo MKS.
- No hay complemento de Cura para ESP3D. Opciones: WebDAV o un script de envío.

## Autor

**Luis** — [@itelmex](https://github.com/itelmex) · developer@melonmind.app

Adaptación, parches, página de la cámara, relés y documentación (noviembre de 2026), con ayuda de Claude (Anthropic).

## Créditos

Este proyecto no existiría sin el trabajo de:

| Proyecto | Autores | Licencia | Uso aquí |
|---|---|---|---|
| [ESP3D](https://github.com/luc-github/ESP3D) v3.1.3 | **Luc Lebosse** ([@luc-github](https://github.com/luc-github)) y los [colaboradores de ESP3D](https://github.com/luc-github/ESP3D#contributors-) | GPL-3.0 | Firmware base; los parches se aplican sobre él |
| [ESP3D-WEBUI](https://github.com/luc-github/ESP3D-WEBUI) v3.1.0 | **Luc Lebosse** y colaboradores | GPL-3.0 | `webui/index.html.gz`, sin cambios |
| [esp32-camera](https://github.com/espressif/esp32-camera) | Espressif Systems | Apache-2.0 | Controlador de la cámara (lo trae ESP3D) |
| [Arduino-ESP32](https://github.com/espressif/arduino-esp32) y ESP-IDF | Espressif Systems y colaboradores | LGPL-2.1 / Apache-2.0 | Núcleo para compilar |
| [pioarduino platform-espressif32](https://github.com/pioarduino/platform-espressif32) y [PlatformIO](https://platformio.org) | pioarduino, PlatformIO Labs | Apache-2.0 | Compilación |
| [arduinoWebSockets](https://github.com/Links2004/arduinoWebSockets) 2.6.1 | Markus Sattler (Links2004) | LGPL-2.1 | Websocket de ESP3D (incluida en ESP3D) |
| [esp32-usb-serial](https://github.com/luc-github/esp32-usb-serial) 1.0.1 | Luc Lebosse | Apache-2.0 | USB anfitrión hacia la impresora (incluida en ESP3D) |
| [ESP32SSDP](https://github.com/luc-github/ESP32SSDP) 2.0.3 | Me-No-Dev, mantenida por Luc Lebosse | GPL-3.0 | Descubrimiento en la red (incluida en ESP3D) |
| Las demás librerías de `libraries/` de ESP3D | Sus autores | Ver cada una | Incluidas en ESP3D |
| [Marlin](https://github.com/MarlinFirmware/Marlin) | MarlinFirmware y colaboradores | GPL-3.0 | Firmware de la impresora (no se modifica) |

Sunlu y S8 son marcas de sus dueños; este proyecto no tiene relación con ellos. Cura (UltiMaker) sólo se menciona para
el G-code final.

## Licencia

**GPL-3.0** (archivo `LICENSE`), la misma de ESP3D, del que este trabajo es derivado. Puedes usarlo, modificarlo y
compartirlo bajo esa licencia, manteniendo los créditos. Se ofrece tal cual, sin garantía: **la parte de 127 V
(relés) la conecta cada quien bajo su responsabilidad**.
