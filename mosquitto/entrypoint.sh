#!/bin/sh
# =============================================================================
# Genera el archivo de credenciales de Mosquitto EN CADA ARRANQUE,
# leyendo MQTT_USER / MQTT_PASSWORD del entorno (que vienen del .env).
# =============================================================================
# Antes la contrasena estaba incrustada en la imagen (mosquitto_passwd en el
# Dockerfile): cambiarla en .env no tenia efecto y los ESP32 dejaban de
# conectarse sin un error claro. Ahora la unica fuente de verdad es el .env.
# =============================================================================
set -eu

PWFILE=/mosquitto/config/password.txt

: "${MQTT_USER:?MQTT_USER no definido (revisa el .env)}"
: "${MQTT_PASSWORD:?MQTT_PASSWORD no definido (revisa el .env)}"

rm -f "$PWFILE"
mosquitto_passwd -b -c "$PWFILE" "$MQTT_USER" "$MQTT_PASSWORD"
# El entrypoint corre como root pero mosquitto baja a su propio usuario:
# sin este chown el broker no puede leer el archivo y reinicia en bucle.
chown mosquitto:mosquitto "$PWFILE"
chmod 0600 "$PWFILE"

echo "[mosquitto] credenciales generadas para el usuario '${MQTT_USER}'"

exec mosquitto -c /mosquitto/config/mosquitto.conf
