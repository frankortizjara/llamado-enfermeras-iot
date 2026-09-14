# Firmware

**Un solo firmware para los tres tipos de dispositivo.** El tipo se elige desde la
interfaz web del propio ESP32 y se guarda en NVS; cada uno usa solo los pines y las
funciones que necesita.

| Tipo | Dónde va | Qué hace |
|---|---|---|
| `cuarto` | Junto a la cama | Recibe el pulsador, avisa por ESP-NOW y publica por MQTT |
| `banio` | En el baño | Igual, y es donde sale el 40 % de los llamados |
| `luz` | Sobre la puerta, en el pasillo | Acciona el relé del indicador luminoso |

Sin configurar arranca en **modo selector**: levanta su propio punto de acceso para
que el técnico lo configure desde un teléfono, sin reflashear y sin un portátil con
el IDE.

| Archivo | Qué contiene |
|---|---|
| `firmware_unificado.ino` | Arranque, bucle principal, ESP-NOW y MQTT |
| `config.ino` | Servidor web de configuración |
| `web_pages.h` | La interfaz embebida, servida desde el propio dispositivo |
| `nvs.ino` | Persistencia de la configuración |
| `ota.ino` | Actualización de firmware por aire |
| `data.h` | Estado global y mapa de pines |

## Por qué un firmware y no tres

Tres firmwares significan tres binarios que mantener, tres versiones que se
desincronizan y un técnico que tiene que saber cuál grabar en cada caja. Con uno
solo, el almacén tiene un único dispositivo, la actualización por aire alcanza a
todos a la vez, y un equipo que falla se reemplaza por cualquier otro
reconfigurándolo en sitio.

Cuesta algo de memoria y algún `if` de más. Vale la pena.

## Configuración

**Ninguna credencial está en el código.** Red, tipo de dispositivo, dirección y
emparejamiento se configuran desde la interfaz web y viven en NVS.

## Dependencias

Core ESP32 para Arduino, `PubSubClient` (MQTT), `ESPAsyncWebServer` y `Preferences`.
