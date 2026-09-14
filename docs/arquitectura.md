# Arquitectura

Este documento explica qué es el sistema y cómo encaja cada pieza. Es una versión
pública del documento interno de arquitectura: se omiten direcciones de red,
endpoints del sistema hospitalario y todo lo que identifique instalaciones o
pacientes.

---

## 1. El problema

En una sala de hospitalización, un paciente que necesita ayuda no tiene forma fiable
de avisar. Grita, espera, o un familiar sale al pasillo a buscar a alguien. La
enfermería no sabe **quién** llamó, **desde qué cama**, ni **hace cuánto**.

El sistema convierte esa llamada en tres cosas:

- una **luz en el pasillo**, visible desde lejos,
- una **entrada en un panel** con la cama y el paciente,
- un **registro histórico** con hora de llamada y hora de atención.

El registro es lo que permite medir tiempos de respuesta. Un timbre tradicional no
deja rastro.

---

## 2. Las cuatro capas

```
   CAMA                     PASILLO / SALA              SERVIDOR                  PERSONAL
   ────                     ──────────────              ────────                  ────────

  Pulsador                    ESP32 del                Backend Node.js          Panel web
  del paciente  ──ESP-NOW──▶  cuarto      ──MQTT──▶    + PostgreSQL    ──HTTP──▶ (Angular)
                              + luz                                              en tablet
                              + relay                   sincronización            o PC
                                                        periódica
                                                              │
                                                              ▼
                                                     Sistema hospitalario
                                                     (quién ocupa cada cama)
```

### Capa 1 · El dispositivo (ESP32)

Microcontroladores ESP32 con firmware propio, PCB diseñada a medida y una interfaz
web embebida servida desde LittleFS.

Dos mecanismos de comunicación, cada uno para lo suyo:

- **ESP-NOW** entre el pulsador de la cama y el ESP32 de la habitación. Protocolo de
  radio directo de Espressif: no necesita WiFi ni router. La llamada del paciente
  funciona aunque la red del hospital se caiga. Para un pulsador de emergencia, eso
  no es un detalle.
- **MQTT sobre WiFi** entre el ESP32 y el servidor. Aquí sí hace falta red, pero ya
  es comunicación de sistema, no la llamada crítica.

Cada dispositivo envía un **heartbeat** periódico con número de serie, MAC, IP,
estado del relay, tiempo encendido y potencia de señal (RSSI). El panel sabe qué
dispositivos están vivos sin depender de que alguien reporte una falla.

### Capa 2 · El servidor (Node.js + Express)

Organizado por módulos de dominio, no por tipo de archivo:

| Módulo | De qué se ocupa |
|---|---|
| `ambientes` | Hospitales, áreas, servicios, habitaciones y camas |
| `dispositivos` | Alta de ESP32, heartbeat, encendido y apagado de alertas |
| `usuarios` | Personal, roles y asignaciones |
| `analytics` | Tiempos de respuesta, ocupación, indicadores |
| `informacion` | Avisos y contenido de sala |
| `ota` | Actualización de firmware por aire |
| `auditoria` | Registro de acciones |

**Buena parte de la lógica vive en funciones almacenadas de PostgreSQL**, no en
JavaScript; el backend las invoca. Decisión deliberada: la institución ya tiene
DBAs y la lógica queda junto a los datos. Conviene saberlo antes de buscar reglas de
negocio en el código Node y no encontrarlas.

Trabajos programados: sincronización periódica de ocupación de camas, y cierre
automático de alertas manuales que quedaron abiertas.

### Capa 3 · La base de datos (PostgreSQL)

Grupos de tablas:

- **Estructura física:** hospitales, áreas, servicios, habitaciones, camas,
  dispositivos y sus eventos
- **Clínico:** pacientes y ocupación de camas (espejo de lo que devuelve el sistema
  hospitalario)
- **Operación:** alertas, historial de alertas, notas, historial de ocupación
- **Personas:** usuarios y asignaciones
- **Sala:** avisos, efemérides, pantallas y su configuración
- **Sistema:** configuración y variables

Migraciones numeradas y aplicadas por script.

### Capa 4 · El panel (Angular 17)

Angular 17 con Material. El personal ve las alertas activas, las camas y sus
pacientes.

El panel **consulta al servidor por intervalos**; no recibe notificaciones push.
Funciona, pero una alerta tarda hasta un ciclo completo en aparecer. Ver §4.

---

## 3. La integración con el sistema hospitalario

Es la pieza que convierte «cama 12» en «la paciente de la cama 12, con nombre».

Un proceso programado consulta periódicamente el servicio del sistema hospitalario y
vuelca la ocupación en una tabla espejo.

Dos consecuencias que hay que tener presentes:

1. **El sistema no es dueño de los datos del paciente.** Los lee. Si el servicio no
   responde, el sistema sigue avisando de llamadas, pero con la última foto conocida
   de quién ocupa cada cama.
2. **La ventana de sincronización es real.** Un paciente que ingresó hace diez
   minutos todavía no aparece. Para un sistema de llamado es aceptable; conviene
   decirlo en vez de que se descubra.

---

## 4. Lo que conviene saber antes de tocarlo

No son fallos, pero sorprenden a quien llega nuevo:

- **La lógica está en SQL, no en Node.**
- **El panel consulta por intervalos.** Si hace falta que una alerta aparezca al
  instante, hay que pasar a WebSocket o SSE. El backend ya usa MQTT, así que medio
  camino está hecho. Es la mejora pendiente más clara.
- **ESP-NOW no depende de la red.** Es lo que hace que el pulsador funcione con el
  WiFi caído. No se debe sustituir por WiFi «para simplificar».
- **Los datos del paciente son del sistema hospitalario**, con retraso.
- **El firmware se versiona junto al backend** y se actualiza por OTA.

---

## 5. Despliegue

Docker Compose, con procedimiento documentado para **entorno sin conexión**: la red
hospitalaria está aislada, así que las imágenes se trasladan en archivo en lugar de
descargarse. Funciona, pero convierte cada actualización en un procedimiento manual.
