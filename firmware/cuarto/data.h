// ============================================
// data.h - Variables globales ESP32 Cuarto v2 + ESP-NOW
// Sistema Llamado de Enfermeras
// ============================================
//
// CAMBIO vs v2 original:
// Se agrega ESP-NOW para enviar alertas directamente
// al ESP32 de luces, ademas del HTTP al servidor.
// ============================================

#ifndef DATA_H
#define DATA_H

#include <ESPAsyncWebServer.h>
#include <Preferences.h>
#include <esp_now.h>
#include <esp_wifi.h>

// Servidor web
AsyncWebServer server(80);
Preferences preferences;

// ============================================
// Variables WiFi
// ============================================
String ssid, pass, localIP, gateway, subnet, dns1, dns2;

// ============================================
// Variables API y Autenticacion
// ============================================
String apiURL;
String authToken;
String apiUser;
String apiPassword;
int areaId;
int habitacionId;
String numero_serial;
bool reinicio;
bool camaUnica;
bool modoConfiguracion = false;

// ============================================
// Control de reconexion WiFi
// ============================================
unsigned long tiempoInicioAP = 0;
const unsigned long TIEMPO_AP_MS = 600000;
const unsigned long TIEMPO_PARPADEO = 500;
int intentosReconexion = 0;
const int MAX_INTENTOS_RECONEXION = 3;

// ============================================
// Pines de Hardware
// ============================================
const uint8_t btn_Llamar_rf = 12;
const uint8_t btn_Luz_rf = 14;
const uint8_t bit2_Cama = 26;
const uint8_t bit1_Cama = 27;
const uint8_t btn_Ayuda = 33;
const uint8_t btn_Atender = 34;
const uint8_t led_wifi = 4;
const uint8_t led_on = 5;
const uint8_t led_rf = 13;
const uint8_t BUZZER = 2;

// ============================================
// Estados de Botones
// ============================================
uint8_t estado_Llamar_rf = 0;
uint8_t estado_Luz_rf = 0;
uint8_t estado_bit2_Cama = 0;
uint8_t estado_bit1_Cama = 0;
uint8_t estado_Ayuda = 0;
uint8_t estado_Atender = 0;
uint8_t estado_led_rf = 0;

// ============================================
// ESP-NOW (NUEVO)
// Estructura del mensaje para comunicacion
// directa con el ESP32 de luces.
// DEBE SER IDENTICA en cuarto, bano y luces.
// ============================================
typedef struct {
  uint16_t habitacionId;  // ID de la habitacion
  uint8_t tipoAlerta;     // 1=urgente, 2=emergencia, 3=apagar
  uint8_t cama;           // numero de cama (1-4=A-D, 0=bano)
} MensajeAlerta;

// MAC broadcast: envia a TODOS los ESP32 cercanos
// El ESP32 de luces filtra por habitacionId
uint8_t broadcastMAC[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};

// ============================================
// Heartbeat
// Envia estado cada 5 minutos al servidor
// ============================================
const unsigned long INTERVALO_HEARTBEAT = 300000;  // 5 min
unsigned long ultimoHeartbeat = 0;
unsigned long tiempoInicio = 0;

// ============================================
// Logs
// ============================================
String logBuffer = "";

#endif
