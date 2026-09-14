// ============================================
// main__cuarto_v2_espnow.ino
// ESP32 Control Camas v2 + ESP-NOW
// Sistema Llamado de Enfermeras
// ============================================
//
// CAMBIO vs v2 original:
// Ademas de enviar alertas via HTTP al servidor,
// tambien envia un mensaje ESP-NOW broadcast que
// el ESP32 de luces recibe instantaneamente.
//
// ESP-NOW NO interfiere con WiFi: ambos funcionan
// simultaneamente en el mismo canal.
//
// TIPOS DE ALERTA:
// 1 = Urgente (llamada de cama)
// 2 = Emergencia (boton de ayuda)
// 3 = Apagar/Cancelar alertas
// ============================================

#include <WiFi.h>
#include <Preferences.h>
#include <HTTPClient.h>
#include <AsyncTCP.h>
#include <ESPAsyncWebServer.h>
#include <ArduinoJson.h>
#include "FS.h"
#include "LittleFS.h"
#include "data.h"

unsigned long ultimoEnvio = 0;
unsigned long intervaloMinimo = 500;

// ============================================
// Intentar conectar a WiFi
// ============================================
bool intentarConectarWiFi() {
  if (ssid == "") {
    Serial.println("No hay SSID configurado");
    return false;
  }

  WiFi.disconnect();
  delay(100);

  if (localIP != "" && gateway != "") {
    IPAddress ip, gw, sn, d1, d2;
    ip.fromString(localIP);
    gw.fromString(gateway);
    sn.fromString(subnet.length() > 0 ? subnet : "255.255.255.0");
    if (dns1.length() > 0) d1.fromString(dns1);
    if (dns2.length() > 0) d2.fromString(dns2);
    WiFi.config(ip, gw, sn, d1, d2);
  }

  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid.c_str(), pass.c_str());
  Serial.print("Conectando WiFi '" + ssid + "'");

  int intentos = 0;
  while (WiFi.status() != WL_CONNECTED && intentos < 40) {
    delay(500);
    Serial.print(".");
    intentos++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println(" OK - IP: " + WiFi.localIP().toString());
    return true;
  }

  Serial.println(" FALLO");
  return false;
}

// ============================================
// Iniciar modo AP
// ============================================
void iniciarModoAP() {
  modoConfiguracion = true;
  tiempoInicioAP = millis();

  WiFi.disconnect();
  delay(100);

  startWiFiManager();

  Serial.println("=== MODO AP: ESP32-ENFERMERAS / 12345678 / 192.168.4.1 ===");
}

// ============================================
// Inicializar ESP-NOW (NUEVO)
// Se llama despues de conectar WiFi.
// ESP-NOW usa el mismo canal que la conexion WiFi.
// ============================================
void initESPNOW() {
  if (esp_now_init() != ESP_OK) {
    Serial.println("ERROR: esp_now_init()");
    return;
  }

  // Agregar peer broadcast
  esp_now_peer_info_t peer;
  memset(&peer, 0, sizeof(peer));
  memcpy(peer.peer_addr, broadcastMAC, 6);
  peer.channel = 0;  // 0 = canal actual del WiFi
  peer.encrypt = false;
  esp_now_add_peer(&peer);

  Serial.println("ESP-NOW activo (broadcast habId=" + String(habitacionId) + ")");
}

void setup() {
  Serial.begin(115200);
  Serial.println("\n=== ESP32 Enfermeras v2 + ESP-NOW ===");

  // Configurar pines
  pinMode(btn_Ayuda, INPUT);
  pinMode(btn_Atender, INPUT);
  pinMode(btn_Llamar_rf, INPUT);
  pinMode(btn_Luz_rf, INPUT);
  pinMode(BUZZER, OUTPUT);
  pinMode(led_rf, INPUT_PULLDOWN);
  pinMode(bit2_Cama, INPUT);
  pinMode(bit1_Cama, INPUT);
  pinMode(led_wifi, OUTPUT);
  pinMode(led_on, OUTPUT);

  digitalWrite(led_on, HIGH);
  digitalWrite(BUZZER, LOW);

  getChipId();
  readWiFiConfig();
  readAPIConfig();
  listFiles();

  if (ssid != "") {
    if (intentarConectarWiFi()) {
      digitalWrite(led_wifi, HIGH);
      modoConfiguracion = false;
      intentosReconexion = 0;

      setupWebServer();

      // >>> NUEVO: Iniciar ESP-NOW despues de WiFi <<<
      initESPNOW();

      // Heartbeat
      tiempoInicio = millis();
      enviarHeartbeat();
      ultimoHeartbeat = millis();

      // Login automatico
      if (apiURL.length() > 0 && apiUser.length() > 0) {
        if (doLogin()) {
          Serial.println("Login OK");
        } else {
          Serial.println("Login fallido - configurar en /api");
        }
      }
    } else {
      digitalWrite(led_wifi, LOW);
      intentosReconexion++;
      iniciarModoAP();
    }
  } else {
    iniciarModoAP();
  }
}

void loop() {
  // ==========================================
  // MODO CONFIGURACION (AP)
  // ==========================================
  if (modoConfiguracion) {
    digitalWrite(led_wifi, (millis() / TIEMPO_PARPADEO) % 2);

    unsigned long tiempoEnAP = millis() - tiempoInicioAP;

    static unsigned long ultimoMensaje = 0;
    if (millis() - ultimoMensaje > 30000) {
      Serial.println("AP restante: " + String((TIEMPO_AP_MS - tiempoEnAP) / 1000) + "s");
      ultimoMensaje = millis();
    }

    if (tiempoEnAP >= TIEMPO_AP_MS) {
      if (intentosReconexion < MAX_INTENTOS_RECONEXION) {
        WiFi.softAPdisconnect(true);
        delay(500);

        if (intentarConectarWiFi()) {
          modoConfiguracion = false;
          intentosReconexion = 0;
          digitalWrite(led_wifi, HIGH);
          delay(1000);
          ESP.restart();
        } else {
          intentosReconexion++;
          if (intentosReconexion >= MAX_INTENTOS_RECONEXION) {
            Serial.println("MAX INTENTOS - AP permanente");
          }
          iniciarModoAP();
        }
      }
    }

    delay(100);
    return;
  }

  // ==========================================
  // MODO NORMAL (Conectado a WiFi)
  // ==========================================

  if (WiFi.status() != WL_CONNECTED) {
    digitalWrite(led_wifi, LOW);
    Serial.println("WiFi perdido!");

    if (intentarConectarWiFi()) {
      digitalWrite(led_wifi, HIGH);
      Serial.println("Reconectado!");
    } else {
      intentosReconexion++;
      iniciarModoAP();
    }
    return;
  }

  digitalWrite(led_wifi, HIGH);

  // Leer botones
  estado_Llamar_rf = digitalRead(btn_Llamar_rf);
  estado_Luz_rf = digitalRead(btn_Luz_rf);
  estado_Ayuda = digitalRead(btn_Ayuda);
  estado_Atender = digitalRead(btn_Atender);
  estado_bit2_Cama = digitalRead(bit2_Cama);
  estado_bit1_Cama = digitalRead(bit1_Cama);
  estado_led_rf = digitalRead(led_rf);

  // Senal RF detectada
  if (digitalRead(led_rf) && (millis() - ultimoEnvio > intervaloMinimo)) {
    int cama = 2 * digitalRead(bit2_Cama) + digitalRead(bit1_Cama) + 1;
    if (estado_Llamar_rf == 1) {
      Serial.println("Llamada cama " + String(cama));
      sendPostRequest(1, cama);  // Tipo 1 = Urgente
      ultimoEnvio = millis();
    }
  }

  // Boton Atender
  if (estado_Atender == 1) {
    Serial.println("Atendiendo - Apagando alertas");
    for (int i = 1; i <= 5; i++) {
      sendPostRequest(3, i);  // Tipo 3 = Apagar
    }
    ultimoEnvio = millis();
  }

  // Boton Ayuda
  if (estado_Ayuda == 1) {
    Serial.println("EMERGENCIA!");
    sendPostRequest(2, 5);  // Tipo 2 = Emergencia
    ultimoEnvio = millis();
  }

  // Heartbeat periodico
  if (millis() - ultimoHeartbeat >= INTERVALO_HEARTBEAT) {
    enviarHeartbeat();
    ultimoHeartbeat = millis();
  }

  delay(100);
}
