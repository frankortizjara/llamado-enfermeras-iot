// ============================================
// firmware_unificado.ino
// FIRMWARE UNIFICADO: Cuarto + Bano + Luces
// Sistema Llamado de Enfermeras v2026
// ============================================
//
// Un solo firmware para los 3 tipos de ESP32.
// El tipo se elige en la primera configuracion
// y se guarda en NVS. Se puede cambiar desde la web.
//
// TIPOS:
//   "cuarto" - Transmisor: RF 433MHz → ESP-NOW + HTTP
//   "bano"   - Transmisor: Botones → ESP-NOW + HTTP
//   "luces"  - Receptor: ESP-NOW → Rele corredor
//
// CARACTERISTICAS NUEVAS:
//   - Codigo unificado (un .bin para todo)
//   - OTA Web Upload (subir .bin desde navegador)
//   - OTA Programado (verifica a hora/dia configurado)
//   - Heartbeat configurable (5-30 minutos)
//   - NTP para reloj (OTA programado)
//   - Selector de tipo en primera configuracion
//
// INTERVALOS DE PETICIONES HTTP:
//   - Heartbeat: cada 5-30 min (configurable) = 1 POST
//   - OTA check: 1 vez al dia/semana a hora fija = 1 POST
//   - Alertas: solo cuando paciente presiona = 1 POST
//   - Login JWT: solo al encender/expirar = 1 POST
//   - Luces: MQTT push (sin polling HTTP)
//   TOTAL: ~288-1440 requests/dia (0.17% duty cycle)
//   IMPACTO TERMICO: despreciable
//
// LIBRERIAS NECESARIAS (Arduino IDE):
//   - AsyncTCP (me-no-dev)
//   - ESPAsyncWebServer (me-no-dev)
//   - ArduinoJson (Benoit Blanchon)
//   - PubSubClient (Nick O'Leary) - MQTT
//   - ESP32 Board Package >= 2.0.0
//
// CONFIGURAR EN ARDUINO IDE:
//   Board: ESP32 Dev Module
//   Partition Scheme: Minimal SPIFFS (con OTA)
//   Upload Speed: 921600
//   Flash Size: 4MB
// ============================================

#include <WiFi.h>
#include <Preferences.h>
#include <HTTPClient.h>
#include <AsyncTCP.h>
#include <ESPAsyncWebServer.h>
#include <ArduinoJson.h>
#include <esp_now.h>
#include <esp_wifi.h>
#include <Update.h>
#include <time.h>
#include "data.h"

// ============================================
// CONECTAR WIFI
// ============================================
bool intentarConectarWiFi() {
  if (ssid == "") {
    Serial.println("No hay SSID configurado");
    return false;
  }

  WiFi.disconnect();
  delay(100);

  // IP estatica si se configuro
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
    wifiConectado = true;
    wifiChannel = WiFi.channel();
    Serial.println(" OK - IP: " + WiFi.localIP().toString() + " Canal: " + String(wifiChannel));
    return true;
  }

  Serial.println(" FALLO");
  wifiConectado = false;
  return false;
}

// ============================================
// CONFIGURAR PINES SEGUN TIPO
// ============================================
void configurarPines() {
  if (tipoDispositivo == "luces") {
    // GPIO21 = RELE via 2N2222 NPN: HIGH=ON, LOW=OFF
    pinMode(PIN_RELE, OUTPUT);
    digitalWrite(PIN_RELE, LOW);    // Rele OFF por defecto (NPN cortado)
    pinMode(BTN_CONFIG, INPUT_PULLUP);

    // === TEST RELE AL BOOT ===
    // Si escuchas 2 clicks, el hardware funciona
    Serial.println("TEST RELE (GPIO21): ON...");
    digitalWrite(PIN_RELE, HIGH);   // Rele ON (NPN conduce)
    delay(500);
    Serial.println("TEST RELE: OFF...");
    digitalWrite(PIN_RELE, LOW);    // Rele OFF (NPN cortado)
    delay(300);
    Serial.println("TEST RELE: ON...");
    digitalWrite(PIN_RELE, HIGH);   // Rele ON
    delay(500);
    Serial.println("TEST RELE: OFF. Test completo.");
    digitalWrite(PIN_RELE, LOW);    // Rele OFF
    delay(200);
  } else {
    // Cuarto/Bano: botones RF + LEDs
    pinMode(btn_Ayuda, INPUT);
    pinMode(btn_Atender, INPUT);
    pinMode(btn_Llamar_rf, INPUT);
    pinMode(btn_Luz_rf, INPUT);
    pinMode(BUZZER, OUTPUT);
    pinMode(led_rf, INPUT_PULLDOWN);
    pinMode(bit2_Cama, INPUT);
    pinMode(bit1_Cama, INPUT);
    pinMode(PIN_GPIO4, OUTPUT);   // LED WiFi
    pinMode(led_on, OUTPUT);
    pinMode(BTN_CONFIG, INPUT_PULLUP);

    digitalWrite(led_on, HIGH);   // LED encendido = alimentacion OK
    digitalWrite(BUZZER, LOW);
  }
}

// ============================================
// SETUP
// ============================================
void setup() {
  Serial.begin(115200);
  Serial.println("\n=== ESP32 Enfermeras Unificado v" FIRMWARE_VERSION " ===");

  getChipId();

  // Calcular escalonamiento para auto-reinicio basado en chipId
  // Hash del numero serial para distribuir uniformemente (0-30 min extra)
  uint32_t hash = 0;
  for (unsigned int i = 0; i < numero_serial.length(); i++) {
    hash = hash * 31 + numero_serial.charAt(i);
  }
  unsigned long escalonamiento = (hash % 1800) * 1000UL;  // 0-30 min en ms
  intervaloReinicio = INTERVALO_BASE_REINICIO + escalonamiento;
  Serial.println("Auto-reinicio en: " + String(intervaloReinicio / 60000UL) + " min");

  // 1. Leer tipo de dispositivo de NVS
  readTipoDispositivo();

  // 2. Si no hay tipo configurado → modo selector (primera vez)
  if (tipoDispositivo == "") {
    Serial.println("Sin tipo configurado -> Modo Selector");
    iniciarModoSelector();
    return;
  }

  Serial.println("Tipo: " + tipoDispositivo);

  // 3. Configurar pines segun tipo
  configurarPines();

  // 4. Leer toda la configuracion
  readWiFiConfig();
  readAPIConfig();
  readOTAConfig();

  // 5. Boton BOOT presionado = modo config manual
  delay(100);
  if (digitalRead(BTN_CONFIG) == LOW) {
    Serial.println("Boton BOOT presionado -> Modo AP");
    iniciarModoAP();
    return;
  }

  // 7. Luces sin habitacionId: aviso pero NO forzar AP
  // El usuario configurara habitacionId desde /api una vez conectado a WiFi
  // ESP-NOW no reaccionara hasta que se configure habitacionId (filtra habId=0)
  if (tipoDispositivo == "luces" && habitacionId == 0) {
    Serial.println("AVISO: Luces sin habitacionId - configurar en /api");
  }

  // 8. Conectar WiFi
  if (ssid != "") {
    if (intentarConectarWiFi()) {
      // WiFi OK
      if (tipoDispositivo != "luces") {
        digitalWrite(PIN_GPIO4, HIGH);  // LED WiFi ON
      }
      modoConfiguracion = false;
      intentosReconexion = 0;

      // Web server
      setupWebServer();

      // ESP-NOW segun rol
      if (tipoDispositivo == "luces") {
        initESPNOW_Receptor();
        // MQTT: leer config y conectar
        readMQTTConfig();
        initMQTT();
      } else {
        initESPNOW_Transmisor();
      }

      // NTP para OTA programado
      configurarNTP();

      // Primer heartbeat
      tiempoInicio = millis();
      enviarHeartbeat();
      ultimoHeartbeat = millis();

      // Login automatico (todos los tipos)
      if (apiURL.length() > 0 && apiUser.length() > 0) {
        if (doLogin()) {
          Serial.println("Login OK");
        } else {
          Serial.println("Login fallido - configurar en /api");
        }
      }

    } else {
      // WiFi fallo al boot
      if (tipoDispositivo != "luces") {
        digitalWrite(PIN_GPIO4, LOW);
      }
      intentosReconexion = 0;   // Empezar Fase 1 desde cero
      enPausaReconexion = false;
      iniciarModoAP();
    }
  } else {
    // Sin SSID configurado
    iniciarModoAP();
  }
}

// ============================================
// LOOP
// ============================================
void loop() {
  // --- MODO CONFIGURACION (AP) ---
  if (modoConfiguracion) {
    loopModoConfiguracion();
    return;
  }

  // --- VERIFICAR WIFI ---
  if (WiFi.status() != WL_CONNECTED) {
    wifiConectado = false;
    if (tipoDispositivo != "luces") {
      digitalWrite(PIN_GPIO4, LOW);
    }
    Serial.println("WiFi perdido!");

    if (intentarConectarWiFi()) {
      if (tipoDispositivo != "luces") {
        digitalWrite(PIN_GPIO4, HIGH);
      }
      Serial.println("Reconectado!");
    } else {
      intentosReconexion = 0;  // Reset para empezar Fase 1 completa
      if (reinicio) {
        ESP.restart();
      }
      iniciarModoAP();
    }
    return;
  }

  wifiConectado = true;
  if (tipoDispositivo != "luces") {
    digitalWrite(PIN_GPIO4, HIGH);  // LED WiFi ON
  }

  // --- LOOP ESPECIFICO POR TIPO ---
  if (tipoDispositivo == "cuarto") {
    loopCuarto();
  } else if (tipoDispositivo == "bano") {
    loopBanio();
  } else if (tipoDispositivo == "luces") {
    loopLuces();
  }

  // --- HEARTBEAT PERIODICO ---
  if (millis() - ultimoHeartbeat >= INTERVALO_HEARTBEAT) {
    enviarHeartbeat();
    ultimoHeartbeat = millis();
  }

  // --- OTA: Procesar operaciones pendientes desde web ---
  // (diferidas del web server async para no bloquearlo)
  if (otaPendienteVerificar && !otaEnProgreso) {
    otaPendienteVerificar = false;
    verificarActualizacionRemota(false);
  }
  if (otaPendienteDescargar && !otaEnProgreso) {
    otaPendienteDescargar = false;
    descargarFirmwareRemoto(otaDownloadUrl);
  }

  // --- OTA PROGRAMADO ---
  if (!otaEnProgreso) {
    verificarOTAProgramado();
  }

  // --- AUTO-REINICIO PROGRAMADO ---
  // Reinicia tras ~10h + escalonamiento, pero solo si no hay alerta activa
  if (reinicioAutoProgramado && !otaEnProgreso && (millis() - tiempoInicio) >= intervaloReinicio) {
    if (tipoDispositivo == "luces" && luzEncendida) {
      // Hay alerta activa: posponer 5 min y reintentar
      logMessage("Auto-reinicio pospuesto (alerta activa)");
      tiempoInicio = millis() - intervaloReinicio + 300000UL;  // Reintentar en 5 min
    } else {
      logMessage("Auto-reinicio programado (" + String((millis()) / 60000UL) + " min uptime)");
      enviarHeartbeat();  // Ultimo heartbeat antes de reiniciar
      delay(500);
      ESP.restart();
    }
  }

  delay(100);
}

// ============================================
// LOOPS ESPECIFICOS POR TIPO
// ============================================

void loopCuarto() {
  // Leer estado de botones y receptor RF
  estado_Llamar_rf = digitalRead(btn_Llamar_rf);
  estado_Luz_rf = digitalRead(btn_Luz_rf);
  estado_Ayuda = digitalRead(btn_Ayuda);
  estado_Atender = digitalRead(btn_Atender);
  estado_bit2_Cama = digitalRead(bit2_Cama);
  estado_bit1_Cama = digitalRead(bit1_Cama);
  estado_led_rf = digitalRead(led_rf);

  // Senal RF detectada (paciente presiono control remoto)
  if (digitalRead(led_rf) && (millis() - ultimoEnvio > intervaloMinimo)) {
    int cama = 2 * digitalRead(bit2_Cama) + digitalRead(bit1_Cama) + 1;
    if (estado_Llamar_rf == 1) {
      Serial.println("Llamada cama " + String(cama));
      sendPostRequest(1, cama);  // Tipo 1 = Urgente
      ultimoEnvio = millis();
    }
    if (estado_Luz_rf == 1) {
      Serial.println("Luz corredor cama " + String(cama));
      enviarESPNOW(1, cama);     // Enciende luz via ESP-NOW
      ultimoEnvio = millis();
    }
  }

  // Boton Atender (enfermera cancela alertas)
  // GPIO34 es input-only sin pull-down interno: requiere debounce doble lectura
  if (estado_Atender == 1 && (millis() - ultimoEnvio > intervaloMinimo)) {
    delay(50);  // debounce
    if (digitalRead(btn_Atender) == 1) {
      Serial.println("Atendiendo - Apagando alertas");
      for (int i = 1; i <= 5; i++) {
        sendPostRequest(3, i);  // Tipo 3 = Apagar
      }
      ultimoEnvio = millis();
    }
  }

  // Boton Ayuda (emergencia)
  // GPIO33 es input-only sin pull-down interno: requiere debounce doble lectura
  if (estado_Ayuda == 1 && (millis() - ultimoEnvio > intervaloMinimo)) {
    delay(50);  // debounce
    if (digitalRead(btn_Ayuda) == 1) {
      Serial.println("EMERGENCIA!");
      sendPostRequest(2, 5);  // Tipo 2 = Emergencia
      ultimoEnvio = millis();
    }
  }
}

void loopBanio() {
  estado_Llamar_rf = digitalRead(btn_Llamar_rf);
  estado_Luz_rf = digitalRead(btn_Luz_rf);
  estado_Ayuda = digitalRead(btn_Ayuda);
  estado_Atender = digitalRead(btn_Atender);
  estado_led_rf = digitalRead(led_rf);

  // Senal RF desde banio
  if (digitalRead(led_rf) && (millis() - ultimoEnvio > intervaloMinimo)) {
    if (estado_Llamar_rf == 1) {
      Serial.println("Senal RF - Llamada banio");
      sendPostRequest(1, 0);  // cama=0 siempre para bano
      ultimoEnvio = millis();
    }
    if (estado_Luz_rf == 1) {
      Serial.println("Luz corredor banio");
      enviarESPNOW(1, 0);     // Enciende luz via ESP-NOW
      ultimoEnvio = millis();
    }
  }

  // Boton Atender
  if (estado_Atender == 1 && (millis() - ultimoEnvio > intervaloMinimo)) {
    Serial.println("Atendiendo banio");
    sendPostRequest(3, 0);
    ultimoEnvio = millis();
  }

  // Boton Ayuda
  if (estado_Ayuda == 1 && (millis() - ultimoEnvio > intervaloMinimo)) {
    Serial.println("EMERGENCIA banio!");
    sendPostRequest(2, 0);
    ultimoEnvio = millis();
  }
}

void loopLuces() {
  // --- MQTT: mantener conexion y procesar mensajes ---
  if (!mqttClient.connected()) {
    mqttConectado = false;
    // Reintentar conexion cada INTERVALO_REINTENTO_MQTT
    if (millis() - ultimoReintento >= INTERVALO_REINTENTO_MQTT) {
      ultimoReintento = millis();
      conectarMQTT();
    }
  } else {
    mqttConectado = true;
    mqttClient.loop();  // Procesar mensajes entrantes
  }

  // --- AUTO-OFF de seguridad (si se pierde conexion al broker) ---
  if (luzEncendida && (millis() - ultimaAlerta > TIEMPO_AUTO_OFF)) {
    digitalWrite(PIN_RELE, LOW);
    luzEncendida = false;
    logMessage(">>> RELE OFF (auto-off 10min)");
  }
}

// ============================================
// LOOP MODO CONFIGURACION (AP)
// Fase 1: AP 10min → intento WiFi (x4)
// Fase 2: Pausa 1h (light sleep) → intento WiFi
// Luego vuelve a Fase 1 indefinidamente
// ============================================
void loopModoConfiguracion() {
  // --- FASE 2: Pausa sin AP (ahorro energia) ---
  if (enPausaReconexion) {
    // Parpadeo lento LED (1 flash cada 3s) para indicar modo pausa
    if (tipoDispositivo != "luces" && tipoDispositivo != "") {
      unsigned long ciclo = millis() % 3000;
      digitalWrite(PIN_GPIO4, ciclo < 150 ? HIGH : LOW);
    }

    // Verificar boton BOOT para forzar AP manual
    if (digitalRead(BTN_CONFIG) == LOW) {
      delay(50);  // debounce
      if (digitalRead(BTN_CONFIG) == LOW) {
        Serial.println("Boton BOOT -> salir de pausa, entrar AP");
        enPausaReconexion = false;
        intentosReconexion = 0;
        iniciarModoAP();
        return;
      }
    }

    unsigned long tiempoEnPausa = millis() - tiempoInicioPausa;

    // Mensaje periodico
    static unsigned long ultimoMensajePausa = 0;
    if (millis() - ultimoMensajePausa > 60000) {
      Serial.println("Pausa reconexion: " + String((TIEMPO_PAUSA_MS - tiempoEnPausa) / 60000) + " min restantes");
      ultimoMensajePausa = millis();
    }

    // Fin de pausa → intentar WiFi, si falla vuelve a Fase 1
    if (tiempoEnPausa >= TIEMPO_PAUSA_MS) {
      Serial.println("Fin pausa - intentando WiFi...");
      enPausaReconexion = false;

      if (ssid.length() > 0 && intentarConectarWiFi()) {
        modoConfiguracion = false;
        intentosReconexion = 0;
        delay(1000);
        ESP.restart();
      } else {
        // Volver a Fase 1 (4 ciclos de AP)
        intentosReconexion = 0;
        Serial.println("WiFi fallo tras pausa -> Fase 1 (ciclos AP)");
        iniciarModoAP();
      }
    }

    delay(100);
    return;
  }

  // --- FASE 1: Modo AP activo ---

  // Parpadear LED WiFi en cuarto/bano
  if (tipoDispositivo != "luces" && tipoDispositivo != "") {
    digitalWrite(PIN_GPIO4, (millis() / TIEMPO_PARPADEO) % 2);
  }

  // Verificar boton BOOT para reiniciar ciclo AP
  if (digitalRead(BTN_CONFIG) == LOW) {
    delay(50);
    if (digitalRead(BTN_CONFIG) == LOW) {
      Serial.println("Boton BOOT -> reiniciar timer AP");
      tiempoInicioAP = millis();
      intentosReconexion = 0;
    }
  }

  unsigned long tiempoEnAP = millis() - tiempoInicioAP;

  // Mensaje periodico en serial
  static unsigned long ultimoMensaje = 0;
  if (millis() - ultimoMensaje > 30000) {
    Serial.println("AP restante: " + String((TIEMPO_AP_MS - tiempoEnAP) / 1000) + "s (intento " + String(intentosReconexion + 1) + "/" + String(MAX_INTENTOS_FASE1) + ")");
    ultimoMensaje = millis();
  }

  // Timeout del AP → reintentar WiFi
  if (tiempoEnAP >= TIEMPO_AP_MS && ssid.length() > 0) {
    WiFi.softAPdisconnect(true);
    delay(500);

    if (intentarConectarWiFi()) {
      modoConfiguracion = false;
      intentosReconexion = 0;
      if (tipoDispositivo != "luces") {
        digitalWrite(PIN_GPIO4, HIGH);
      }
      delay(1000);
      ESP.restart();
    }

    intentosReconexion++;

    if (intentosReconexion >= MAX_INTENTOS_FASE1) {
      // Fase 1 agotada → entrar a Fase 2 (pausa 1h)
      Serial.println("Fase 1 agotada (" + String(MAX_INTENTOS_FASE1) + " intentos) -> Pausa " + String(TIEMPO_PAUSA_MS / 60000) + " min");
      WiFi.softAPdisconnect(true);
      enPausaReconexion = true;
      tiempoInicioPausa = millis();
      if (tipoDispositivo != "luces" && tipoDispositivo != "") {
        digitalWrite(PIN_GPIO4, LOW);
      }
    } else {
      // Siguiente ciclo AP
      Serial.println("Intento " + String(intentosReconexion) + "/" + String(MAX_INTENTOS_FASE1) + " - reabrir AP");
      iniciarModoAP();
    }
  }

  delay(100);
}
