; ---- Apagado automatico al terminar (ESP3D Sunlu-S8-B) ----
; Pegar AL FINAL del "G-code final" de la impresora en Cura, despues de lo que ya trae. Se puede dejar siempre:
; el apagado es optativo con el interruptor "Apagar al terminar" de cam.html (arranca desactivado y se usa una vez).
; Solo funciona al imprimir desde la SD de la placa ESP3D (boton ▶): la linea [ESP201] la ejecuta ESP3D, no Marlin.
; Desde la SD de la impresora Marlin la ignora ("Unknown command") y la impresora queda encendida.
M104 S0              ; hotend apagado
M140 S0              ; cama apagada
M107                 ; ventilador de capa apagado (el del disipador sigue solo mientras este caliente)
M117 Enfriando...
M109 R50             ; esperar a que el hotend baje a 50 C
G4 S60               ; un minuto mas con el ventilador del disipador
M117 Apagando
[ESP201]P=21 V=0     ; impresora APAGADA, solo si en cam.html esta activado "Apagar al terminar" (si no, ESP3D la ignora)
