// ============================================
// data.h - Variables globales
// FIRMWARE UNIFICADO: Cuarto + Bano + Luces
// Sistema Llamado de Enfermeras v2026
// ============================================
//
// Un solo firmware para los 3 tipos de dispositivo.
// El tipo se configura por web y se guarda en NVS.
// Cada tipo usa solo los pines y funciones que necesita.
//
// TIPOS:
//   "cuarto" - Transmisor: RF → ESP-NOW + HTTP
//   "bano"   - Transmisor: Botones → ESP-NOW + HTTP
//   "luces"  - Receptor: ESP-NOW → Rele
//   ""       - Sin configurar (modo selector)
// ============================================

#ifndef DATA_H
#define DATA_H

#include <ESPAsyncWebServer.h>
#include <Preferences.h>
#include <esp_now.h>
#include <esp_wifi.h>

// ============================================
// VERSION DEL FIRMWARE
// Incrementar con cada actualizacion
// ============================================
#define FIRMWARE_VERSION "6.5.0"

// ============================================
// Servidor web y NVS
// ============================================
AsyncWebServer server(80);
Preferences preferences;

// ============================================
// TIPO DE DISPOSITIVO
// Se lee de NVS namespace "device-config"
// Valores: "cuarto", "bano", "luces", ""
// ============================================
String tipoDispositivo = "";

// ============================================
// Variables WiFi (NVS: "wifi-config")
// ============================================
String ssid, pass, localIP, gateway, subnet, dns1, dns2;

// ============================================
// Variables API y Autenticacion (NVS: "api-config")
// ============================================
String apiURL;
String authToken;
String apiUser;
String apiPassword;
int areaId = 1;
int habitacionId = 0;
String numero_serial;
bool reinicio = false;
bool camaUnica = false;       // Solo relevante para tipo "cuarto"
bool modoConfiguracion = false;

// ============================================
// Control de reconexion WiFi
// Fase 1: 4 ciclos de [AP 10min + intento WiFi]
// Fase 2: Pausa 1h (light sleep) + intento WiFi
// Si no reconecta, vuelve a Fase 1 indefinidamente
// ============================================
unsigned long tiempoInicioAP = 0;
const unsigned long TIEMPO_AP_MS = 600000;       // 10 min en AP antes de reintentar
const unsigned long TIEMPO_PARPADEO = 500;       // Parpadeo LED WiFi en modo AP
int intentosReconexion = 0;
const int MAX_INTENTOS_FASE1 = 4;                // Ciclos AP en Fase 1
const unsigned long TIEMPO_PAUSA_MS = 3600000;   // 1h pausa en Fase 2
bool enPausaReconexion = false;                   // true = en Fase 2 (pausa sin AP)
unsigned long tiempoInicioPausa = 0;              // Cuando empezo la pausa

// ============================================
// Pines de Hardware
//
// GPIO 4: cuarto/bano - LED indicador WiFi
// GPIO 21: luces - Control del RELE via 2N2222 (NPN)
//   NPN: HIGH=ON (transistor conduce), LOW=OFF (transistor cortado)
//
// GPIO 0: Boton BOOT (todos los tipos)
//   - Mantener presionado al encender = modo config
// ============================================
const uint8_t PIN_GPIO4 = 4;         // LED WiFi (cuarto/bano)
const uint8_t PIN_RELE = 21;         // RELE via 2N2222 NPN (luces)
const uint8_t BTN_CONFIG = 0;        // GPIO0 (BOOT) - modo config manual

// Pines cuarto/bano (receptor RF + botones)
const uint8_t btn_Llamar_rf = 12;
const uint8_t btn_Luz_rf = 14;
const uint8_t bit2_Cama = 26;
const uint8_t bit1_Cama = 27;
const uint8_t btn_Ayuda = 33;
const uint8_t btn_Atender = 34;
const uint8_t led_on = 5;
const uint8_t led_rf = 13;
const uint8_t BUZZER = 2;

// ============================================
// Estados de Botones (cuarto/bano)
// ============================================
uint8_t estado_Llamar_rf = 0;
uint8_t estado_Luz_rf = 0;
uint8_t estado_bit2_Cama = 0;
uint8_t estado_bit1_Cama = 0;
uint8_t estado_Ayuda = 0;
uint8_t estado_Atender = 0;
uint8_t estado_led_rf = 0;

// ============================================
// ESP-NOW
// Estructura IDENTICA en cuarto, bano y luces
// ============================================
typedef struct {
  uint16_t habitacionId;    // ID de la habitacion (filtro)
  uint8_t tipoAlerta;       // 1=urgente, 2=emergencia, 3=apagar
  uint8_t cama;             // 0=bano, 1-4=camas A-D
} MensajeAlerta;

// MAC broadcast: envia a TODOS los ESP32 cercanos
uint8_t broadcastMAC[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};

// ============================================
// Luces - estado del rele + MQTT
// ============================================
bool luzEncendida = false;
unsigned long ultimaAlerta = 0;
const unsigned long TIEMPO_AUTO_OFF = 600000;  // 10 min auto-apagado (fallback seguridad)

// ============================================
// MQTT (solo luces)
// Se conecta al broker para recibir alertas push
// en lugar de hacer polling HTTP
// ============================================
#include <PubSubClient.h>
WiFiClient wifiClientMqtt;
PubSubClient mqttClient(wifiClientMqtt);

uint16_t mqttPort = 1883;
String mqttUser = "esp32";
String mqttPassword = "CAMBIA_ESTA_PASSWORD";
String mqttHost = "";                          // Se extrae de apiURL
bool mqttConectado = false;
unsigned long ultimoReintento = 0;
const unsigned long INTERVALO_REINTENTO_MQTT = 5000;  // 5 seg entre reintentos

// ============================================
// Heartbeat (configurable 5-30 min)
// NVS: "ota-config" → heartbeatMin
// ============================================
unsigned long INTERVALO_HEARTBEAT = 300000;    // 5 min default
unsigned long ultimoHeartbeat = 0;
unsigned long tiempoInicio = 0;
uint8_t wifiChannel = 1;
bool wifiConectado = false;

// ============================================
// OTA Programado
// NVS: "ota-config"
// ============================================
uint8_t otaHora = 3;           // Hora del dia (0-23) para verificar
uint8_t otaDia = 0;            // 0=diario, 1=Lun, 2=Mar..., 7=Dom
bool otaHabilitado = true;     // Habilitar chequeo automatico
bool otaVerificadoHoy = false;
unsigned long otaUltimoCheck = 0;
bool otaEnProgreso = false;

// Estado de verificacion OTA para web UI
// 0=idle, 1=verificando, 2=update disponible, 3=al dia, 4=error
uint8_t otaCheckStatus = 0;
String otaNewVersion = "";
String otaDownloadUrl = "";
String otaCheckMessage = "";

// Flags para diferir operaciones OTA bloqueantes al loop()
// (las funciones HTTP son sincronas y bloquean el web server async)
bool otaPendienteVerificar = false;
bool otaPendienteDescargar = false;

// ============================================
// Auto-reinicio programado (~10h + escalonamiento)
// Evita que todos los dispositivos reinicien a la vez
// ============================================
const unsigned long INTERVALO_BASE_REINICIO = 36000000UL;  // 10 horas en ms
unsigned long intervaloReinicio = 0;                       // Calculado con escalonamiento
bool reinicioAutoProgramado = true;

// ============================================
// Timing (cuarto/bano - debounce de botones)
// ============================================
unsigned long ultimoEnvio = 0;
unsigned long intervaloMinimo = 500;

// ============================================
// Logs (buffer circular de 2KB)
// ============================================
String logBuffer = "";

#endif
