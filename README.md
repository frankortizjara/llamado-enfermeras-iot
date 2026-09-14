# Sistema de llamado de enfermeras

Un pulsador junto a cada cama de hospital. Cuando el paciente lo aprieta, se
enciende una luz en el pasillo, aparece una entrada en el panel de la estación de
enfermería con la cama y el paciente, y **queda un registro con hora de llamada y
hora de atención**.

Eso último es lo que lo separa de un timbre: el tiempo de respuesta se puede medir.

Desplegado como piloto en un hospital de EsSalud (Perú), en un servicio de
hospitalización de cirugía.

![Placa controladora diseñada a medida con ESP32, receptor RF de 433 MHz, DIP switches de direccionamiento, buzzer y antena helicoidal](imagenes/01-placa-controlador-esp32.jpg)

---

## La decisión que define el sistema

Un pulsador de emergencia que depende del WiFi del hospital no es un pulsador de
emergencia.

Por eso el enlace entre el botón de la cama y el ESP32 de la habitación **no usa
WiFi ni router**: usa **ESP-NOW**, el protocolo de radio directo de Espressif. La
llamada del paciente llega aunque la red esté caída.

El WiFi aparece después, en el salto del ESP32 al servidor vía MQTT. Ahí ya no es
la llamada crítica, es comunicación de sistema — y si ese tramo falla, la luz del
pasillo ya se encendió igual.

```
   CAMA                    PASILLO                  SERVIDOR              ESTACIÓN
   ────                    ───────                  ────────              ────────

  Pulsador                 ESP32 de la             Node.js               Panel web
  del paciente ──ESP-NOW──▶ habitación  ──MQTT──▶  + PostgreSQL  ──HTTP──▶ (Angular)
                            + luz                                          en tablet
                            + relay
```

![Indicadores luminosos sobre las puertas de habitación, encendidos en rojo durante una llamada activa](imagenes/02-indicadores-llamada-pasillo.jpg)

---

## Stack

| Capa | Tecnología |
|---|---|
| Dispositivo | ESP32 · C++ / Arduino · ESP-NOW · MQTT · LittleFS · PCB propia |
| Servidor | Node.js · Express · MQTT · cron |
| Datos | PostgreSQL — lógica de negocio en funciones almacenadas |
| Panel | Angular 17 · Material |
| Despliegue | Docker Compose · actualización de firmware por OTA |

---

## Qué hay en este repositorio

Este es un repositorio de portafolio: contiene el **firmware ESP-NOW**, que es la
pieza que mejor explica el diseño, y la documentación de arquitectura. El sistema
completo —backend, panel, migraciones, integración hospitalaria— es privado, porque
opera sobre datos de pacientes reales.

```
firmware/
├── cuarto/          ESP32 de la habitación: recibe ESP-NOW, enciende la luz,
│                    publica por MQTT y sirve su propia interfaz de configuración
└── luces-pasillo/   ESP32 del indicador de pasillo
docs/
└── arquitectura.md  las cuatro capas, y lo que conviene saber antes de tocarlo
```

Cada ESP32 sirve **una interfaz web embebida desde LittleFS** para configurarlo en
sitio —red, dirección, emparejamiento— sin reflashear y sin un portátil con el IDE.
En un hospital, donde el técnico llega con un teléfono, eso es la diferencia entre
una instalación de cinco minutos y una de una hora.

---

## Decisiones que tomé, y por qué

**La lógica de negocio vive en PostgreSQL, no en Node.** Las funciones almacenadas
hacen el trabajo y el backend las llama. El hospital ya tiene DBAs y la lógica queda
junto a los datos. Es una decisión discutible y conviene saberla antes de buscar las
reglas en el código JavaScript y no encontrarlas.

**Los dispositivos reportan su estado solos.** Cada ESP32 manda un *heartbeat*
periódico con número de serie, MAC, IP, estado del relay, tiempo encendido y
potencia de señal. El panel sabe qué dispositivos están vivos sin esperar a que
alguien reporte una falla — que en un hospital es siempre tarde.

**El sistema no es dueño de los datos del paciente.** Los lee del sistema
hospitalario cada 30 minutos. Si esa API no responde, el sistema sigue avisando de
llamadas con la última foto conocida de quién ocupa cada cama.

**Actualización por aire.** El firmware se versiona junto al backend y se actualiza
por OTA. Con dispositivos repartidos por varias habitaciones, ir cama por cama con
un cable no es opción.

---

## Limitaciones conocidas

Prefiero decirlas a que se descubran:

- **El panel consulta por intervalos**, no recibe notificaciones push. Una alerta
  tarda hasta un ciclo en aparecer. El backend ya usa MQTT, así que migrar a
  WebSocket o SSE es la mitad del camino — es la mejora pendiente más clara.
- **La ventana de 30 minutos de sincronización es real.** Un paciente que ingresó
  hace diez minutos todavía no aparece con su nombre. Para un sistema de llamado es
  aceptable, pero es una limitación, no un detalle.
- **La red hospitalaria está aislada**, así que el despliegue lleva las imágenes de
  Docker en archivo en lugar de descargarlas. Funciona, pero hace cada actualización
  un procedimiento manual.

---

## Mi rol

Diseño del sistema completo: electrónica y PCB, firmware, backend, base de datos,
panel e integración con el sistema hospitalario. También el despliegue en sitio y la
capacitación al personal de enfermería.

---

## Sobre los datos

Este repositorio **no contiene datos de pacientes**. Las imágenes fueron revisadas
una a una y se descartaron todas las que mostraban nombres, números de documento o
historias clínicas, además de las que incluían personal identificable. Las capturas
de la interfaz que se añadan más adelante se generan con datos sintéticos.

---

## Licencia

MIT — ver [LICENSE](LICENSE).

La licencia cubre el código publicado aquí. El sistema desplegado y sus datos son
propiedad de la institución para la que se desarrolló.
