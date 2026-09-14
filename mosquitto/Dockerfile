# Mosquitto MQTT Broker - Sistema Llamado de Enfermeras
FROM eclipse-mosquitto:2

# Configuracion del broker
COPY mosquitto.conf /mosquitto/config/mosquitto.conf

# Entrypoint: genera password.txt en cada arranque desde MQTT_USER/MQTT_PASSWORD.
# La contrasena NO se incrusta en la imagen: se lee del .env en tiempo de ejecucion.
COPY entrypoint.sh /entrypoint.sh

USER root
RUN chmod +x /entrypoint.sh && \
    mkdir -p /mosquitto/data /mosquitto/log && \
    chown -R mosquitto:mosquitto /mosquitto

EXPOSE 1883

ENTRYPOINT ["/entrypoint.sh"]
