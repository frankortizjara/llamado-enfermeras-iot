// ============================================
// config.ino - HTTP, ESP-NOW, Web Server
// FIRMWARE UNIFICADO
//
// Funciones compartidas por todos los tipos:
//   logMessage, getChipId, getMacAddress
//   enviarHeartbeat, setupWebServer, startWiFiManager
//
// Funciones solo cuarto/bano:
//   doLogin, registrarESP32, enviarESPNOW
//   sendPostRequest, encenderBuzzer
//
// Funciones solo luces:
//   onESPNOWRecibido (callback ESP-NOW)
// ============================================

#include <ArduinoJson.h>
#include "web_pages.h"

// ============================================
// LOG
// ============================================
void logMessage(String message) {
  Serial.println(message);
  logBuffer += message + "\n";
  if (logBuffer.length() > 2000) {
    logBuffer.remove(0, logBuffer.length() - 2000);
  }
}

// ============================================
// CHIP ID / MAC
// ============================================
void getChipId() {
  uint64_t chipid = ESP.getEfuseMac();
  uint16_t chip = (uint16_t)(chipid >> 32);
  char serialStr[13];
  snprintf(serialStr, sizeof(serialStr), "%08X%04X", (uint32_t)chipid, chip);
  numero_serial = String(serialStr);
  Serial.println("Serial: " + numero_serial);
}

String getMacAddress() {
  uint64_t mac = ESP.getEfuseMac();
  char macStr[18];
  snprintf(macStr, sizeof(macStr), "%02X:%02X:%02X:%02X:%02X:%02X",
           (uint8_t)(mac), (uint8_t)(mac >> 8), (uint8_t)(mac >> 16),
           (uint8_t)(mac >> 24), (uint8_t)(mac >> 32), (uint8_t)(mac >> 40));
  return String(macStr);
}

// ============================================
// LOGIN (cuarto/bano)
// ============================================
bool doLogin() {
  if (apiURL.length() == 0 || apiUser.length() == 0) {
    logMessage("ERROR: Configurar URL y usuario");
    return false;
  }

  HTTPClient http;
  http.begin(apiURL + "api/usuarios/login");
  http.setTimeout(10000);
  http.addHeader("Content-Type", "application/json");

  String body = "{\"usuario\":\"" + apiUser + "\",\"clave\":\"" + apiPassword + "\"}";
  logMessage("Login: " + apiURL + "api/usuarios/login");

  int httpCode = http.POST(body);

  if (httpCode == 200) {
    String response = http.getString();
    DynamicJsonDocument doc(2048);
    DeserializationError error = deserializeJson(doc, response);

    if (!error && doc.containsKey("body") && doc["body"].containsKey("token")) {
      saveToken(doc["body"]["token"].as<String>());
      logMessage("LOGIN OK");
      http.end();
      return true;
    }
  }

  logMessage("LOGIN ERROR: " + String(httpCode));
  http.end();
  return false;
}

// ============================================
// REGISTRAR ESP32 (cuarto/bano)
// ============================================
bool registrarESP32() {
  if (authToken.length() == 0) {
    if (!doLogin()) return false;
  }

  HTTPClient http;
  http.begin(apiURL + "api/dispositivos/agregarESP32");
  http.setTimeout(10000);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Authorization", "Bearer " + authToken);

  String body = "{\"numero_serial\":\"" + numero_serial + "\","
    "\"direccion_mac\":\"" + getMacAddress() + "\","
    "\"ip\":\"" + WiFi.localIP().toString() + "\"}";

  int httpCode = http.POST(body);
  String response = http.getString();
  logMessage("Registrar: " + String(httpCode));
  http.end();

  if (httpCode == 200 || httpCode == 201) return true;
  if (httpCode == 401 || httpCode == 403) {
    if (doLogin()) return registrarESP32();
  }
  return false;
}

// ============================================
// HEARTBEAT (todos los tipos)
// Envia estado periodicamente al servidor
// Intervalo configurable (5-30 min)
// ============================================
void enviarHeartbeat() {
  if (apiURL.length() == 0 || WiFi.status() != WL_CONNECTED) return;

  unsigned long uptime = (millis() - tiempoInicio) / 1000;
  int rssi = WiFi.RSSI();

  HTTPClient http;
  http.begin(apiURL + "api/dispositivos/heartbeat");
  http.setTimeout(5000);
  http.addHeader("Content-Type", "application/json");

  String habIdStr = (habitacionId > 0) ? String(habitacionId) : "null";

  // tipo_dispositivo: "cuarto", "bano", "luces"
  String tipoAPI = tipoDispositivo;

  // relay_estado: solo relevante para luces
  String relayStr = (tipoDispositivo == "luces") ? (luzEncendida ? "true" : "false") : "false";

  String body = "{\"numero_serial\":\"" + numero_serial + "\","
    "\"direccion_mac\":\"" + getMacAddress() + "\","
    "\"ip\":\"" + WiFi.localIP().toString() + "\","
    "\"tipo_dispositivo\":\"" + tipoAPI + "\","
    "\"habitacion_id\":" + habIdStr + ","
    "\"relay_estado\":" + relayStr + ","
    "\"firmware_version\":\"" FIRMWARE_VERSION "\","
    "\"uptime\":" + String(uptime) + ","
    "\"rssi\":" + String(rssi) + "}";

  int httpCode = http.POST(body);
  http.end();

  if (httpCode == 200 || httpCode == 201) {
    logMessage("Heartbeat OK (up=" + String(uptime) + "s rssi=" + String(rssi) + "dBm)");
  } else {
    logMessage("Heartbeat error: " + String(httpCode));
  }
}

// ============================================
// ESP-NOW TRANSMISOR (cuarto/bano)
// ============================================
void initESPNOW_Transmisor() {
  if (esp_now_init() != ESP_OK) {
    Serial.println("ERROR: esp_now_init()");
    return;
  }

  esp_now_peer_info_t peer;
  memset(&peer, 0, sizeof(peer));
  memcpy(peer.peer_addr, broadcastMAC, 6);
  peer.channel = 0;  // Canal actual del WiFi
  peer.encrypt = false;
  esp_now_add_peer(&peer);

  Serial.println("ESP-NOW TX activo (habId=" + String(habitacionId) + ")");
}

void enviarESPNOW(int tipoAlerta, int cama) {
  MensajeAlerta msg;
  msg.habitacionId = (uint16_t)habitacionId;
  msg.tipoAlerta = (uint8_t)tipoAlerta;
  msg.cama = (uint8_t)cama;

  esp_err_t result = esp_now_send(broadcastMAC, (uint8_t *)&msg, sizeof(msg));
  if (result == ESP_OK) {
    logMessage("ESPNOW> hab=" + String(habitacionId) + " tipo=" + String(tipoAlerta) + " cama=" + String(cama));
  } else {
    logMessage("ESPNOW error");
  }
}

// ============================================
// ESP-NOW RECEPTOR (luces)
// ============================================
void onESPNOWRecibido(const esp_now_recv_info_t *info, const uint8_t *datos, int largo) {
  if (largo != sizeof(MensajeAlerta)) return;

  // No procesar si no tenemos habitacionId configurado
  if (habitacionId == 0) return;

  MensajeAlerta msg;
  memcpy(&msg, datos, sizeof(MensajeAlerta));

  // Solo procesar si es para NUESTRA habitacion
  if (msg.habitacionId != (uint16_t)habitacionId) return;

  Serial.printf("ESPNOW< hab=%d tipo=%d cama=%d\n",
                msg.habitacionId, msg.tipoAlerta, msg.cama);

  if (msg.tipoAlerta == 1 || msg.tipoAlerta == 2) {
    digitalWrite(PIN_RELE, HIGH);   // Rele ON (2N2222 NPN conduce)
    luzEncendida = true;
    ultimaAlerta = millis();
    Serial.println(">>> LUZ ON (GPIO21=HIGH)");
  } else if (msg.tipoAlerta == 3) {
    digitalWrite(PIN_RELE, LOW);    // Rele OFF (2N2222 NPN cortado)
    luzEncendida = false;
    Serial.println(">>> LUZ OFF (GPIO21=LOW)");
  }
}

void initESPNOW_Receptor() {
  // Desactivar power saving para no perder mensajes
  esp_wifi_set_ps(WIFI_PS_NONE);

  if (esp_now_init() != ESP_OK) {
    Serial.println("ERROR: esp_now_init()");
    return;
  }

  esp_now_register_recv_cb(onESPNOWRecibido);

  Serial.println("========================================");
  Serial.println("ESP-NOW RX activo");
  Serial.println("  Canal: " + String(WiFi.channel()));
  Serial.println("  Habitacion: " + String(habitacionId));
  Serial.println("  MAC: " + WiFi.macAddress());
  Serial.println("  Esperando alertas...");
  Serial.println("========================================");
}

// ============================================
// MQTT (luces)
// Recibe alertas push del servidor via broker MQTT
// Reemplaza el polling HTTP cada 5 seg
// ============================================

// Callback: se ejecuta cuando llega un mensaje MQTT
void onMqttMessage(char* topic, byte* payload, unsigned int length) {
  // Parsear payload JSON: {"action":"ON","tipo":1,"cama":"A","ts":123456}
  String msg = "";
  for (unsigned int i = 0; i < length; i++) {
    msg += (char)payload[i];
  }

  logMessage("MQTT< " + String(topic) + " : " + msg);

  DynamicJsonDocument doc(256);
  DeserializationError error = deserializeJson(doc, msg);
  if (error) {
    logMessage("MQTT: JSON error");
    return;
  }

  String action = doc["action"] | "";

  if (action == "ON") {
    int tipo = doc["tipo"] | 1;
    if (!luzEncendida) {
      digitalWrite(PIN_RELE, HIGH);
      luzEncendida = true;
      logMessage(">>> RELE ON (MQTT tipo=" + String(tipo) + ")");
    }
    ultimaAlerta = millis();  // Resetear auto-off
  } else if (action == "OFF") {
    if (luzEncendida) {
      digitalWrite(PIN_RELE, LOW);
      luzEncendida = false;
      logMessage(">>> RELE OFF (MQTT)");
    }
  }
}

// Inicializar cliente MQTT
void initMQTT() {
  if (mqttHost.length() == 0) {
    logMessage("MQTT: sin host (configurar URL del servidor)");
    return;
  }
  if (habitacionId == 0) {
    logMessage("MQTT: sin habitacionId");
    return;
  }

  mqttClient.setServer(mqttHost.c_str(), mqttPort);
  mqttClient.setCallback(onMqttMessage);
  mqttClient.setBufferSize(512);

  logMessage("MQTT: broker=" + mqttHost + ":" + String(mqttPort));

  conectarMQTT();
}

// Conectar/reconectar al broker MQTT
void conectarMQTT() {
  if (mqttHost.length() == 0 || habitacionId == 0) return;

  String clientId = "esp32-luces-" + numero_serial;
  String topic = "enfermeras/alertas/" + String(habitacionId);

  // Last Will: publicar offline al desconectarse
  String lwtTopic = "enfermeras/lwt/" + numero_serial;

  logMessage("MQTT: conectando como " + clientId + "...");

  bool connected = mqttClient.connect(
    clientId.c_str(),
    mqttUser.c_str(),
    mqttPassword.c_str(),
    lwtTopic.c_str(),
    1,      // QoS 1
    true,   // retain
    "OFFLINE"
  );

  if (connected) {
    mqttConectado = true;
    logMessage("MQTT: conectado!");

    // Suscribirse al topic de nuestra habitacion
    mqttClient.subscribe(topic.c_str(), 1);  // QoS 1
    logMessage("MQTT: suscrito a " + topic);

    // Publicar online
    mqttClient.publish(lwtTopic.c_str(), "ONLINE", true);
  } else {
    mqttConectado = false;
    logMessage("MQTT: fallo conexion (rc=" + String(mqttClient.state()) + ")");
  }
}

// ============================================
// ENVIAR ALERTA HTTP + ESP-NOW (cuarto/bano)
// ESP-NOW se envia PRIMERO (instantaneo, ~5ms)
// HTTP se envia despues (registra en servidor, ~500ms)
// ============================================
void sendPostRequest(int tipoAlerta, int cama) {
  // 1. ESP-NOW primero (enciende luz instantaneamente)
  enviarESPNOW(tipoAlerta, cama);

  // 2. HTTP al servidor
  if (authToken.length() == 0) {
    logMessage("Sin token, login...");
    if (!doLogin()) return;
  }

  // Determinar codigo de cama segun tipo
  String codigoCama;
  if (tipoDispositivo == "bano") {
    codigoCama = "Bano";
  } else {
    // cuarto: A, B, C, D, -
    char letras[] = {'A', 'B', 'C', 'D', '-'};
    int idx = (cama >= 1 && cama <= 4) ? (cama - 1) : 4;
    codigoCama = String(letras[idx]);
    if (tipoAlerta == 2 || camaUnica) codigoCama = "-";
  }

  HTTPClient http;
  http.begin(apiURL + "api/dispositivos/agregarRegistro");
  http.setTimeout(5000);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Authorization", "Bearer " + authToken);

  String body = "{\"numero_serial\":\"" + numero_serial + "\","
    "\"area_id\":" + String(areaId) + ","
    "\"habitacion_id\":" + String(habitacionId) + ","
    "\"codigo_cama\":\"" + codigoCama + "\","
    "\"tipo_alerta\":" + String(tipoAlerta) + "}";

  logMessage("Alerta tipo=" + String(tipoAlerta) + " cama=" + codigoCama);

  int httpCode = http.POST(body);
  logMessage("HTTP: " + String(httpCode));

  if (httpCode == 200 || httpCode == 201 || httpCode == 409) {
    encenderBuzzer();
  } else if (httpCode == 401 || httpCode == 403) {
    authToken = "";
    http.end();
    if (doLogin()) sendPostRequest(tipoAlerta, cama);
    return;
  }

  http.end();
}

// ============================================
// BUZZER (cuarto/bano)
// ============================================
void encenderBuzzer() {
  if (tipoDispositivo == "luces") return;
  digitalWrite(BUZZER, HIGH);
  delay(300);
  digitalWrite(BUZZER, LOW);
}

// ============================================
// MODO SELECTOR (primera vez, sin tipo)
// AP con pagina para elegir tipo + WiFi
// ============================================
void iniciarModoSelector() {
  modoConfiguracion = true;
  tiempoInicioAP = millis();

  // Configurar GPIO0 como input
  pinMode(BTN_CONFIG, INPUT_PULLUP);

  WiFi.disconnect();
  delay(100);
  WiFi.softAP("ESP32-ENFERMERAS-CFG", "12345678");

  Serial.println("========================================");
  Serial.println("MODO SELECTOR");
  Serial.println("  Red: ESP32-ENFERMERAS-CFG");
  Serial.println("  Pass: 12345678");
  Serial.println("  IP: " + WiFi.softAPIP().toString());
  Serial.println("========================================");

  // Servir pagina de seleccion (desde flash embebido)
  server.on("/style.css", HTTP_GET, [](AsyncWebServerRequest *request) {
    request->send_P(200, "text/css", PAGE_STYLE_CSS);
  });

  server.on("/", HTTP_GET, [](AsyncWebServerRequest *request) {
    request->send_P(200, "text/html", PAGE_SELECTOR_HTML);
  });

  server.on("/setup", HTTP_POST, [](AsyncWebServerRequest *request) {
    String tipo = request->hasParam("tipo", true) ? request->getParam("tipo", true)->value() : "";
    String newSsid = request->hasParam("ssid", true) ? request->getParam("ssid", true)->value() : "";
    String newPass = request->hasParam("pass", true) ? request->getParam("pass", true)->value() : "";
    String newIP = request->hasParam("ip", true) ? request->getParam("ip", true)->value() : "";
    String newGW = request->hasParam("gateway", true) ? request->getParam("gateway", true)->value() : "";
    String newSN = request->hasParam("subnet", true) ? request->getParam("subnet", true)->value() : "";
    String newDNS1 = request->hasParam("dns1", true) ? request->getParam("dns1", true)->value() : "";
    String newDNS2 = request->hasParam("dns2", true) ? request->getParam("dns2", true)->value() : "";

    if (tipo.length() > 0 && newSsid.length() > 0 && newPass.length() > 0) {
      saveTipoDispositivo(tipo);
      saveWiFiConfig(newSsid, newPass, newIP, newGW, newSN, newDNS1, newDNS2);

      String tipoLabel = tipo;
      if (tipo == "bano") tipoLabel = "Bano";

      request->send(200, "text/html",
        "<!DOCTYPE html><html><head><meta charset='utf-8'>"
        "<style>body{font-family:sans-serif;text-align:center;padding:50px;"
        "background:#1a1a2e;color:#e0e0e0}</style></head>"
        "<body><h1>Configurado!</h1>"
        "<p>Tipo: <strong>" + tipoLabel + "</strong></p>"
        "<p>WiFi: " + newSsid + "</p>"
        "<p>Reiniciando en 3 segundos...</p></body></html>");

      delay(3000);
      ESP.restart();
    } else {
      request->send(400, "text/html",
        "<!DOCTYPE html><html><head><meta charset='utf-8'>"
        "<style>body{font-family:sans-serif;text-align:center;padding:50px;"
        "background:#1a1a2e;color:#e0e0e0}a{color:#00d4ff}</style></head>"
        "<body><h1>Error</h1><p>Tipo, SSID y Password son obligatorios</p>"
        "<a href='/'>Volver</a></body></html>");
    }
  });

  server.begin();
}

// ============================================
// MODO AP (reconfigurar WiFi)
// ============================================
bool apServerIniciado = false;  // Evitar registrar handlers duplicados

void iniciarModoAP() {
  modoConfiguracion = true;
  tiempoInicioAP = millis();

  WiFi.disconnect();
  delay(100);

  startWiFiManager();
}

// Genera HTML de WiFi Manager con la configuracion anterior pre-poblada
String generarWiFiManagerHTML() {
  String html = FPSTR(PAGE_WIFI_MANAGER_HTML);

  // Info de configuracion anterior
  bool tieneConfig = ssid.length() > 0;
  html.replace("{{prevDisplay}}", tieneConfig ? "" : "display:none");
  html.replace("{{prevSsid}}", tieneConfig ? ssid : "No configurado");
  html.replace("{{prevIP}}", localIP.length() > 0 ? localIP : "DHCP (automatico)");
  html.replace("{{prevGW}}", gateway.length() > 0 ? gateway : "-");
  html.replace("{{serial}}", numero_serial);
  html.replace("{{tipoDisp}}", tipoDispositivo.length() > 0 ? tipoDispositivo : "Sin configurar");
  html.replace("{{version}}", FIRMWARE_VERSION);

  // Info de reconexion
  String reconInfo = "Intento " + String(intentosReconexion + 1) + "/" + String(MAX_INTENTOS_FASE1);
  if (enPausaReconexion) {
    reconInfo = "En pausa de reconexion (1h)";
  } else if (intentosReconexion == 0 && !tieneConfig) {
    reconInfo = "Primera configuracion";
  } else {
    reconInfo += " - El AP se cerrara en 10 min para reintentar WiFi";
  }
  html.replace("{{reconexionInfo}}", reconInfo);

  // Subtitulo
  html.replace("{{modoSubtitle}}", tieneConfig ? "Reconectando - puede reconfigurar" : "Configuracion inicial");

  // Valores pre-poblados en el formulario
  html.replace("{{valSsid}}", ssid);
  html.replace("{{valIP}}", localIP);
  html.replace("{{valGW}}", gateway);
  html.replace("{{valSubnet}}", subnet.length() > 0 ? subnet : "255.255.255.0");
  html.replace("{{valDNS1}}", dns1);

  return html;
}

void startWiFiManager() {
  // Nombre del AP segun tipo
  String apName = "ESP32-ENFERMERAS";
  if (tipoDispositivo == "bano") apName = "ESP32-BANIO";
  if (tipoDispositivo == "luces") apName = "ESP32-LUCES";

  WiFi.softAP(apName.c_str(), "12345678");
  Serial.println("AP: " + apName + " / 12345678 / " + WiFi.softAPIP().toString());

  // Solo registrar handlers una vez (evita duplicados en reintentos)
  if (!apServerIniciado) {
    server.on("/style.css", HTTP_GET, [](AsyncWebServerRequest *request) {
      request->send_P(200, "text/css", PAGE_STYLE_CSS);
    });
    server.on("/", HTTP_GET, [](AsyncWebServerRequest *request) {
      request->send(200, "text/html", generarWiFiManagerHTML());
    });
    server.on("/wifi", HTTP_GET, [](AsyncWebServerRequest *request) {
      request->send(200, "text/html", generarWiFiManagerHTML());
    });
    server.on("/wifi", HTTP_POST, [](AsyncWebServerRequest *request) {
      String newSsid = request->hasParam("ssid", true) ? request->getParam("ssid", true)->value() : "";
      String newPass = request->hasParam("pass", true) ? request->getParam("pass", true)->value() : "";
      String newIP = request->hasParam("ip", true) ? request->getParam("ip", true)->value() : "";
      String newGW = request->hasParam("gateway", true) ? request->getParam("gateway", true)->value() : "";
      String newSN = request->hasParam("subnet", true) ? request->getParam("subnet", true)->value() : "";
      String newDNS1 = request->hasParam("dns1", true) ? request->getParam("dns1", true)->value() : "";
      String newDNS2 = request->hasParam("dns2", true) ? request->getParam("dns2", true)->value() : "";

      // Si no puso password, mantener el anterior
      if (newPass == "" && pass.length() > 0) {
        newPass = pass;
      }

      if (newSsid != "" && newPass != "") {
        saveWiFiConfig(newSsid, newPass, newIP, newGW, newSN, newDNS1, newDNS2);
        request->send(200, "text/html",
          "<!DOCTYPE html><html><head><meta charset='utf-8'>"
          "<style>body{font-family:sans-serif;text-align:center;padding:50px;"
          "background:#1a1a2e;color:#e0e0e0}</style></head>"
          "<body><h1>Guardado!</h1><p>Reiniciando...</p></body></html>");
        delay(2000);
        ESP.restart();
      } else {
        request->send(400, "text/plain", "SSID y Password requeridos");
      }
    });

    server.begin();
    apServerIniciado = true;
  }
}

// ============================================
// SERVIDOR WEB (modo normal, conectado a WiFi)
// ============================================
void setupWebServer() {
  // --- Archivos estaticos (embebidos en flash) ---
  server.on("/style.css", HTTP_GET, [](AsyncWebServerRequest *request) {
    request->send_P(200, "text/css", PAGE_STYLE_CSS);
  });

  // --- Paginas principales ---
  server.on("/", HTTP_GET, [](AsyncWebServerRequest *request) {
    String html = FPSTR(PAGE_INDEX_HTML);
    html.replace("{{tipoDispositivo}}", tipoDispositivo);
    html.replace("{{version}}", FIRMWARE_VERSION);
    request->send(200, "text/html", html);
  });

  server.on("/wifi", HTTP_GET, [](AsyncWebServerRequest *request) {
    request->send(200, "text/html", generarWiFiManagerHTML());
  });

  server.on("/wifi", HTTP_POST, [](AsyncWebServerRequest *request) {
    String newSsid = request->hasParam("ssid", true) ? request->getParam("ssid", true)->value() : "";
    String newPass = request->hasParam("pass", true) ? request->getParam("pass", true)->value() : "";
    String newIP = request->hasParam("ip", true) ? request->getParam("ip", true)->value() : "";
    String newGW = request->hasParam("gateway", true) ? request->getParam("gateway", true)->value() : "";
    String newSN = request->hasParam("subnet", true) ? request->getParam("subnet", true)->value() : "";
    String newDNS1 = request->hasParam("dns1", true) ? request->getParam("dns1", true)->value() : "";
    String newDNS2 = request->hasParam("dns2", true) ? request->getParam("dns2", true)->value() : "";

    // Si no puso password, mantener el anterior
    if (newPass == "" && pass.length() > 0) {
      newPass = pass;
    }

    if (newSsid != "" && newPass != "") {
      saveWiFiConfig(newSsid, newPass, newIP, newGW, newSN, newDNS1, newDNS2);
      request->send(200, "text/html", "<h1>Guardado!</h1><p>Reiniciando...</p>");
      delay(2000);
      ESP.restart();
    } else {
      request->send(400, "text/plain", "SSID y Password requeridos");
    }
  });

  // --- API Config (adaptativo por tipo) ---
  server.on("/api", HTTP_GET, [](AsyncWebServerRequest *request) {
    readAPIConfig();
    readOTAConfig();
    if (tipoDispositivo == "luces") readMQTTConfig();

    String html = FPSTR(PAGE_API_MANAGER_HTML);

    // Variables comunes
    html.replace("{{tipoDispositivo}}", tipoDispositivo);
    html.replace("{{apiURL}}", apiURL);
    html.replace("{{habitacionId}}", String(habitacionId));
    html.replace("{{tokenStatus}}", authToken.length() > 0 ? "Token OK" : "Sin token");
    html.replace("{{tokenClass}}", authToken.length() > 0 ? "ok" : "error");
    html.replace("{{tokenDot}}", authToken.length() > 0 ? "" : "off");
    html.replace("{{version}}", FIRMWARE_VERSION);

    // Variables cuarto/bano
    html.replace("{{apiUser}}", apiUser);
    html.replace("{{apiPass}}", apiPassword);
    html.replace("{{areaId}}", String(areaId));
    html.replace("{{reinicio}}", reinicio ? "checked" : "");
    html.replace("{{camaUnica}}", camaUnica ? "checked" : "");

    // Variables OTA
    html.replace("{{otaHora}}", String(otaHora));
    html.replace("{{otaDia}}", String(otaDia));
    html.replace("{{otaHabilitado}}", otaHabilitado ? "checked" : "");

    // Heartbeat
    uint8_t hbMin = (uint8_t)(INTERVALO_HEARTBEAT / 60000UL);
    html.replace("{{heartbeatMin}}", String(hbMin));

    // Relay estado (luces)
    html.replace("{{relayEstado}}", luzEncendida ? "ENCENDIDO" : "APAGADO");
    html.replace("{{relayClass}}", luzEncendida ? "on" : "off");

    // MQTT (luces)
    html.replace("{{mqttPort}}", String(mqttPort));
    html.replace("{{mqttUser}}", mqttUser);
    html.replace("{{mqttPass}}", mqttPassword);

    request->send(200, "text/html", html);
  });

  server.on("/api", HTTP_POST, [](AsyncWebServerRequest *request) {
    apiURL = request->hasParam("apiURL", true) ? request->getParam("apiURL", true)->value() : "";
    habitacionId = request->hasParam("habitacionId", true) ? request->getParam("habitacionId", true)->value().toInt() : 1;

    // Campos comunes: usuario, password, area (todos los tipos los necesitan)
    apiUser = request->hasParam("apiUser", true) ? request->getParam("apiUser", true)->value() : "";
    apiPassword = request->hasParam("apiPass", true) ? request->getParam("apiPass", true)->value() : "";
    areaId = request->hasParam("areaId", true) ? request->getParam("areaId", true)->value().toInt() : 1;

    if (tipoDispositivo != "luces") {
      reinicio = request->hasParam("reinicio", true);
      if (tipoDispositivo == "cuarto") {
        camaUnica = request->hasParam("camaUnica", true);
      }
    }

    if (!apiURL.endsWith("/") && apiURL.length() > 0) apiURL += "/";
    saveAPIConfig();

    // MQTT config (luces)
    if (tipoDispositivo == "luces") {
      uint16_t newMqttPort = request->hasParam("mqttPort", true) ? request->getParam("mqttPort", true)->value().toInt() : 1883;
      String newMqttUser = request->hasParam("mqttUser", true) ? request->getParam("mqttUser", true)->value() : "esp32";
      String newMqttPass = request->hasParam("mqttPass", true) ? request->getParam("mqttPass", true)->value() : "CAMBIA_ESTA_PASSWORD";
      saveMQTTConfig(newMqttPort, newMqttUser, newMqttPass);
    }

    // OTA config
    uint8_t newOtaHora = request->hasParam("otaHora", true) ? request->getParam("otaHora", true)->value().toInt() : 3;
    uint8_t newOtaDia = request->hasParam("otaDia", true) ? request->getParam("otaDia", true)->value().toInt() : 0;
    bool newOtaOn = request->hasParam("otaHabilitado", true);
    uint8_t newHbMin = request->hasParam("heartbeatMin", true) ? request->getParam("heartbeatMin", true)->value().toInt() : 5;
    saveOTAConfig(newOtaHora, newOtaDia, newOtaOn, newHbMin);

    request->send(200, "text/html", "<h1>Guardado</h1><script>setTimeout(()=>location.href='/api',1000)</script>");
  });

  // --- Acciones ---
  server.on("/login", HTTP_POST, [](AsyncWebServerRequest *request) {
    if (doLogin()) {
      request->send(200, "text/html", "<h1>Login OK</h1><script>setTimeout(()=>location.href='/api',2000)</script>");
    } else {
      request->send(401, "text/html", "<h1>Error login</h1>");
    }
  });

  server.on("/registrar", HTTP_POST, [](AsyncWebServerRequest *request) {
    if (registrarESP32()) {
      request->send(200, "text/html", "<h1>Registrado!</h1><script>setTimeout(()=>location.href='/api',2000)</script>");
    } else {
      request->send(500, "text/html", "<h1>Error</h1>");
    }
  });

  // --- Logs ---
  server.on("/log", HTTP_GET, [](AsyncWebServerRequest *request) {
    request->send_P(200, "text/html", PAGE_LOG_HTML);
  });

  server.on("/get-log", HTTP_GET, [](AsyncWebServerRequest *request) {
    request->send(200, "text/plain", logBuffer);
  });

  // --- Info JSON ---
  server.on("/info", HTTP_GET, [](AsyncWebServerRequest *request) {
    unsigned long uptime = (millis() - tiempoInicio) / 1000;
    String info = "{\"serial\":\"" + numero_serial + "\","
      "\"mac\":\"" + getMacAddress() + "\","
      "\"ip\":\"" + WiFi.localIP().toString() + "\","
      "\"tipo\":\"" + tipoDispositivo + "\","
      "\"version\":\"" FIRMWARE_VERSION "\","
      "\"habitacion_id\":" + String(habitacionId) + ","
      "\"area_id\":" + String(areaId) + ","
      "\"token\":" + (authToken.length() > 0 ? "true" : "false") + ","
      "\"relay\":" + (luzEncendida ? "true" : "false") + ","
      "\"mqtt\":" + (mqttConectado ? "true" : "false") + ","
      "\"rssi\":" + String(WiFi.RSSI()) + ","
      "\"uptime\":" + String(uptime) + ","
      "\"espnow\":true}";
    request->send(200, "application/json", info);
  });

  // --- Test Alertas (cuarto/bano) ---
  server.on("/test-alerta", HTTP_POST, [](AsyncWebServerRequest *request) {
    if (tipoDispositivo == "luces") {
      request->send(400, "text/plain", "No disponible para luces");
      return;
    }
    int cama = request->hasParam("cama") ? request->getParam("cama")->value().toInt() : 0;
    int tipo = request->hasParam("tipo") ? request->getParam("tipo")->value().toInt() : 1;
    if (tipoDispositivo == "bano") cama = 0;
    sendPostRequest(tipo, cama);
    request->send(200, "text/plain", "Alerta tipo " + String(tipo) + " cama " + String(cama) + " (HTTP+ESPNOW)");
  });

  server.on("/test-apagar", HTTP_POST, [](AsyncWebServerRequest *request) {
    if (tipoDispositivo == "bano") {
      sendPostRequest(3, 0);
    } else {
      for (int i = 1; i <= 5; i++) sendPostRequest(3, i);
    }
    request->send(200, "text/plain", "Alertas apagadas");
  });

  // --- Toggle Rele manual (solo luces) ---
  server.on("/test-rele", HTTP_POST, [](AsyncWebServerRequest *request) {
    if (tipoDispositivo != "luces") {
      request->send(400, "text/plain", "Solo disponible para luces");
      return;
    }
    // Toggle: si esta encendido, apagar y viceversa
    luzEncendida = !luzEncendida;
    digitalWrite(PIN_RELE, luzEncendida ? HIGH : LOW);  // NPN: HIGH=ON
    if (luzEncendida) ultimaAlerta = millis();
    String estado = luzEncendida ? "ENCENDIDO" : "APAGADO";
    Serial.println("TEST RELE MANUAL: " + estado);
    request->send(200, "text/plain", "Rele " + estado + " (GPIO21=" + String(luzEncendida ? "HIGH" : "LOW") + ")");
  });

  // --- Cambiar tipo (requiere reinicio) ---
  server.on("/cambiar-tipo", HTTP_POST, [](AsyncWebServerRequest *request) {
    String nuevoTipo = request->hasParam("tipo", true) ? request->getParam("tipo", true)->value() : "";
    if (nuevoTipo == "cuarto" || nuevoTipo == "bano" || nuevoTipo == "luces") {
      saveTipoDispositivo(nuevoTipo);
      request->send(200, "text/html",
        "<h1>Tipo cambiado a: " + nuevoTipo + "</h1><p>Reiniciando...</p>");
      delay(2000);
      ESP.restart();
    } else {
      request->send(400, "text/plain", "Tipo invalido");
    }
  });

  // --- Reiniciar ---
  server.on("/reboot", HTTP_GET, [](AsyncWebServerRequest *request) {
    request->send(200, "text/html",
      "<!DOCTYPE html><html><head><meta charset='utf-8'>"
      "<style>body{font-family:sans-serif;text-align:center;padding:50px;"
      "background:#1a1a2e;color:#e0e0e0}</style></head>"
      "<body><h1>Reiniciando...</h1></body></html>");
    delay(1000);
    ESP.restart();
  });

  // --- OTA Web Upload ---
  setupOTAWebHandler();

  server.begin();
  Serial.println("Web server activo en " + WiFi.localIP().toString());
}
