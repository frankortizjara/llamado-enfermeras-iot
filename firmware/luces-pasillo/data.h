// ============================================
// data.h - Variables globales ESP32 Luces ESP-NOW
// Sistema Llamado de Enfermeras
// ============================================
//
// MODO HIBRIDO: WiFi + ESP-NOW
// - WiFi conectado permanentemente para heartbeat
// - ESP-NOW para recibir alertas instantaneas
// - Heartbeat cada 5 minutos al servidor
//
// AISLAMIENTO POR HABITACION:
// Cada set (cuarto + bano + luces) comparte el
// mismo habitacionId. Aunque el broadcast ESP-NOW
// llega a todos los ESP32 cercanos, solo el que
// tiene el habitacionId correcto reacciona.
// ============================================

#ifndef DATA_H
#define DATA_H

#include <Preferences.h>

Preferences preferences;

// ============================================
// Pines
// ============================================
const uint8_t RELE = 4;       // GPIO4 para el rele
const uint8_t BTN_CONFIG = 0; // GPIO0 (boton BOOT) para modo configuracion

// ============================================
// Estructura del mensaje ESP-NOW
// IDENTICA en cuarto, bano y luces
// ============================================
typedef struct {
  uint16_t habitacionId;  // ID de la habitacion (filtro de aislamiento)
  uint8_t tipoAlerta;     // 1=urgente, 2=emergencia, 3=apagar
  uint8_t cama;           // numero de cama (0=bano, 1-4=camas A-D)
} MensajeAlerta;

// ============================================
// Configuracion almacenada en NVS
// ============================================
int habitacionId = 0;        // ID de habitacion a escuchar (0 = no configurado)
String ssid;                 // SSID del WiFi
String pass;                 // Password del WiFi
String localIP;              // IP estatica (opcional)
String gateway;              // Gateway (opcional)
String subnet;               // Subnet (opcional)
String apiURL;               // URL del servidor (ej: http://192.168.1.100:3000/)
String numero_serial;

// ============================================
// Estado del sistema
// ============================================
bool modoConfiguracion = false;
bool luzEncendida = false;
unsigned long ultimaAlerta = 0;

// Auto-apagado: si no hay actividad en 10 minutos,
// apagar la luz automaticamente (seguridad)
const unsigned long TIEMPO_AUTO_OFF = 600000;  // 10 min

// ============================================
// WiFi
// ============================================
uint8_t wifiChannel = 1;
bool wifiConectado = false;
int intentosReconexion = 0;
const int MAX_INTENTOS_RECONEXION = 5;

// ============================================
// Heartbeat
// Envia estado cada 5 minutos al servidor
// ============================================
const unsigned long INTERVALO_HEARTBEAT = 300000;  // 5 min
unsigned long ultimoHeartbeat = 0;
unsigned long tiempoInicio = 0;  // Para calcular uptime

// ============================================
// Modo AP (configuracion)
// ============================================
unsigned long tiempoInicioAP = 0;
const unsigned long TIEMPO_AP_MS = 180000;     // 3 min antes de reintentar WiFi
const unsigned long TIEMPO_PARPADEO = 500;     // Parpadeo LED durante AP

// ============================================
// Logs
// ============================================
String logBuffer = "";

#endif
