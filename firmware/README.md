# Firmware

Firmware de los ESP32, en C++ sobre el core de Arduino.

| Carpeta | Dispositivo |
|---|---|
| `cuarto/` | ESP32 de la habitación. Recibe la llamada por ESP-NOW, acciona el relay de la luz, publica el evento por MQTT y sirve su propia interfaz de configuración. |
| `luces-pasillo/` | ESP32 del indicador luminoso del pasillo. |

## Cómo está organizado cada uno

- `main__*.ino` — arranque, bucle principal, ESP-NOW y MQTT
- `config.ino` — servidor web embebido de configuración
- `data.h` — estado global y declaraciones

## Configuración

**Ninguna credencial está en el código.** Red, dirección del dispositivo y
emparejamiento se configuran en sitio desde la interfaz web que sirve el propio
ESP32, y se guardan en NVS. En el primer arranque el dispositivo levanta un punto de
acceso propio para poder configurarlo desde un teléfono.

Eso es deliberado: en una instalación hospitalaria el técnico llega con un móvil, no
con un portátil y el IDE de Arduino.

## Dependencias

Core ESP32 para Arduino, `PubSubClient` (MQTT), `ESPAsyncWebServer` y LittleFS para
la interfaz embebida.
