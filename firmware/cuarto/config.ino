// ============================================
// config.ino - Configuracion y HTTP
// ESP32 Cuarto v2 + ESP-NOW
// ============================================
//
// CAMBIOS vs v2 original:
// 1. Funcion enviarESPNOW() nueva
// 2. sendPostRequest() ahora envia ESP-NOW
//    ANTES del HTTP (respuesta instantanea)
// ============================================

#include <ArduinoJson.h>

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
// LOGIN
// ============================================
bool doLogin() {
  if (apiURL.length() == 0 || apiUser.length() == 0) {
    logMessage("ERROR: Configurar URL y usuario primero");
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
// REGISTRAR ESP32
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

  String body = "{\"numero_serial\":\"" + numero_serial + "\",\"direccion_mac\":\"" + getMacAddress() + "\",\"ip\":\"" + WiFi.localIP().toString() + "\"}";
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
// HEARTBEAT al servidor
// Envia estado cada 5 minutos
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

  String body = "{\"numero_serial\":\"" + numero_serial + "\","
    "\"direccion_mac\":\"" + getMacAddress() + "\","
    "\"ip\":\"" + WiFi.localIP().toString() + "\","
    "\"tipo_dispositivo\":\"cuarto\","
    "\"habitacion_id\":" + habIdStr + ","
    "\"relay_estado\":false,"
    "\"uptime\":" + String(uptime) + ","
    "\"rssi\":" + String(rssi) + "}";

  int httpCode = http.POST(body);
  http.end();

  if (httpCode == 200 || httpCode == 201) {
    logMessage("Heartbeat OK (uptime=" + String(uptime) + "s rssi=" + String(rssi) + "dBm)");
  } else {
    logMessage("Heartbeat error: " + String(httpCode));
  }
}

// ============================================
// ENVIAR ALERTA VIA ESP-NOW (NUEVO)
// Envia un mensaje broadcast que el ESP32 de
// luces recibe instantaneamente (~50ms).
// El habitacionId asegura que solo la luz
// correcta se enciende.
// ============================================
void enviarESPNOW(int tipoAlerta, int cama) {
  MensajeAlerta msg;
  msg.habitacionId = (uint16_t)habitacionId;
  msg.tipoAlerta = (uint8_t)tipoAlerta;
  msg.cama = (uint8_t)cama;

  esp_err_t result = esp_now_send(broadcastMAC, (uint8_t *)&msg, sizeof(msg));
  if (result == ESP_OK) {
    logMessage("ESP-NOW enviado (hab=" + String(habitacionId) + " tipo=" + String(tipoAlerta) + " cama=" + String(cama) + ")");
  } else {
    logMessage("ESP-NOW error");
  }
}

// ============================================
// ENVIAR ALERTA HTTP + ESP-NOW
// ============================================
void sendPostRequest(int tipoAlerta, int cama) {
  // >>> NUEVO: Enviar ESP-NOW primero (instantaneo) <<<
  // Esto enciende la luz ANTES de que el HTTP termine.
  // Asi la enfermera ve la luz inmediatamente.
  enviarESPNOW(tipoAlerta, cama);

  // Luego enviar HTTP al servidor (como siempre)
  if (authToken.length() == 0) {
    logMessage("Sin token, intentando login...");
    if (!doLogin()) return;
  }

  char letrasCama[5] = {'A', 'B', 'C', 'D', '-'};
  String codigoCama = String(letrasCama[cama - 1]);
  if (tipoAlerta == 2 || camaUnica) codigoCama = "-";

  HTTPClient http;
  http.begin(apiURL + "api/dispositivos/agregarRegistro");
  http.setTimeout(5000);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Authorization", "Bearer " + authToken);

  String body = "{\"numero_serial\":\"" + numero_serial + "\",\"area_id\":" + String(areaId) + ",\"habitacion_id\":" + String(habitacionId) + ",\"codigo_cama\":\"" + codigoCama + "\",\"tipo_alerta\":" + String(tipoAlerta) + "}";

  logMessage("Alerta tipo " + String(tipoAlerta) + " cama " + codigoCama);

  int httpCode = http.POST(body);
  logMessage("HTTP: " + String(httpCode));

  if (httpCode == 200 || httpCode == 201 || httpCode == 409) {
    encenderBuzzer();
  } else if (httpCode == 401 || httpCode == 403) {
    authToken = "";
    if (doLogin()) sendPostRequest(tipoAlerta, cama);
  }

  http.end();
}

// ============================================
// BUZZER
// ============================================
void encenderBuzzer() {
  digitalWrite(BUZZER, HIGH);
  delay(300);
  digitalWrite(BUZZER, LOW);
}

// ============================================
// LISTAR ARCHIVOS
// ============================================
void listFiles() {
  if (!LittleFS.begin()) return;
  Serial.println("Archivos LittleFS:");
  File root = LittleFS.open("/");
  File file = root.openNextFile();
  while (file) {
    Serial.println("  " + String(file.name()));
    file = root.openNextFile();
  }
}

// ============================================
// SERVIDOR WEB
// ============================================
void setupWebServer() {
  server.on("/style.css", HTTP_GET, [](AsyncWebServerRequest *request) {
    request->send(LittleFS, "/style.css", "text/css");
  });

  server.on("/", HTTP_GET, [](AsyncWebServerRequest *request) {
    request->send(LittleFS, "/index.html", "text/html");
  });

  server.on("/wifi", HTTP_GET, [](AsyncWebServerRequest *request) {
    request->send(LittleFS, "/wifiManager.html", "text/html");
  });

  server.on("/wifi", HTTP_POST, [](AsyncWebServerRequest *request) {
    String newSsid = request->hasParam("ssid", true) ? request->getParam("ssid", true)->value() : "";
    String newPass = request->hasParam("pass", true) ? request->getParam("pass", true)->value() : "";
    String newIP = request->hasParam("ip", true) ? request->getParam("ip", true)->value() : "";
    String newGW = request->hasParam("gateway", true) ? request->getParam("gateway", true)->value() : "";
    String newSN = request->hasParam("subnet", true) ? request->getParam("subnet", true)->value() : "";
    String newDNS1 = request->hasParam("dns1", true) ? request->getParam("dns1", true)->value() : "";
    String newDNS2 = request->hasParam("dns2", true) ? request->getParam("dns2", true)->value() : "";

    if (newSsid != "" && newPass != "") {
      saveWiFiConfig(newSsid, newPass, newIP, newGW, newSN, newDNS1, newDNS2);
      request->send(200, "text/html", "<h1>Guardado!</h1><p>Reiniciando...</p>");
      delay(2000);
      ESP.restart();
    } else {
      request->send(400, "text/plain", "SSID y Password requeridos");
    }
  });

  server.on("/api", HTTP_GET, [](AsyncWebServerRequest *request) {
    readAPIConfig();

    File file = LittleFS.open("/apiManager.html", "r");
    if (!file) {
      request->send(500, "text/plain", "Error: apiManager.html no encontrado");
      return;
    }

    String html = file.readString();
    file.close();

    html.replace("{{apiURL}}", apiURL);
    html.replace("{{apiUser}}", apiUser);
    html.replace("{{apiPass}}", apiPassword);
    html.replace("{{areaId}}", String(areaId));
    html.replace("{{habitacionId}}", String(habitacionId));
    html.replace("{{reinicio}}", reinicio ? "checked" : "");
    html.replace("{{camaUnica}}", camaUnica ? "checked" : "");
    html.replace("{{tokenStatus}}", authToken.length() > 0 ? "Token OK" : "Sin token");
    html.replace("{{tokenClass}}", authToken.length() > 0 ? "ok" : "error");
    html.replace("{{tokenDot}}", authToken.length() > 0 ? "" : "off");

    request->send(200, "text/html", html);
  });

  server.on("/api", HTTP_POST, [](AsyncWebServerRequest *request) {
    apiURL = request->hasParam("apiURL", true) ? request->getParam("apiURL", true)->value() : "";
    apiUser = request->hasParam("apiUser", true) ? request->getParam("apiUser", true)->value() : "";
    apiPassword = request->hasParam("apiPass", true) ? request->getParam("apiPass", true)->value() : "";
    areaId = request->hasParam("areaId", true) ? request->getParam("areaId", true)->value().toInt() : 1;
    habitacionId = request->hasParam("habitacionId", true) ? request->getParam("habitacionId", true)->value().toInt() : 1;
    reinicio = request->hasParam("reinicio", true);
    camaUnica = request->hasParam("camaUnica", true);

    if (!apiURL.endsWith("/")) apiURL += "/";

    saveAPIConfig();
    request->send(200, "text/html", "<h1>Guardado</h1><script>setTimeout(()=>location.href='/api',1000)</script>");
  });

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

  server.on("/log", HTTP_GET, [](AsyncWebServerRequest *request) {
    request->send(LittleFS, "/log.html", "text/html");
  });

  server.on("/get-log", HTTP_GET, [](AsyncWebServerRequest *request) {
    request->send(200, "text/plain", logBuffer);
  });

  server.on("/info", HTTP_GET, [](AsyncWebServerRequest *request) {
    String info = "{\"serial\":\"" + numero_serial + "\",\"mac\":\"" + getMacAddress() + "\",\"ip\":\"" + WiFi.localIP().toString() + "\",\"area_id\":" + String(areaId) + ",\"habitacion_id\":" + String(habitacionId) + ",\"token\":" + (authToken.length() > 0 ? "true" : "false") + ",\"espnow\":true}";
    request->send(200, "application/json", info);
  });

  server.on("/test-alerta", HTTP_POST, [](AsyncWebServerRequest *request) {
    int cama = request->hasParam("cama") ? request->getParam("cama")->value().toInt() : 1;
    int tipo = request->hasParam("tipo") ? request->getParam("tipo")->value().toInt() : 1;
    sendPostRequest(tipo, cama);
    request->send(200, "text/plain", "Alerta tipo " + String(tipo) + " cama " + String(cama) + " (HTTP+ESPNOW)");
  });

  server.on("/test-llamar", HTTP_POST, [](AsyncWebServerRequest *request) {
    sendPostRequest(1, 1);
    request->send(200, "text/plain", "Alerta tipo 1 enviada (HTTP+ESPNOW)");
  });

  server.on("/test-emergencia", HTTP_POST, [](AsyncWebServerRequest *request) {
    sendPostRequest(2, 5);
    request->send(200, "text/plain", "Emergencia enviada (HTTP+ESPNOW)");
  });

  server.on("/test-apagar", HTTP_POST, [](AsyncWebServerRequest *request) {
    for (int i = 1; i <= 5; i++) sendPostRequest(3, i);
    request->send(200, "text/plain", "Alertas apagadas (HTTP+ESPNOW)");
  });

  server.on("/reboot", HTTP_GET, [](AsyncWebServerRequest *request) {
    request->send(200, "text/html", "<h1>Reiniciando...</h1>");
    delay(1000);
    ESP.restart();
  });

  server.begin();
  Serial.println("Web server activo");
}

// ============================================
// MODO AP
// ============================================
void startWiFiManager() {
  WiFi.softAP("ESP32-ENFERMERAS", "12345678");
  Serial.println("AP: ESP32-ENFERMERAS / 12345678 / " + WiFi.softAPIP().toString());

  server.on("/style.css", HTTP_GET, [](AsyncWebServerRequest *request) {
    request->send(LittleFS, "/style.css", "text/css");
  });
  server.on("/", HTTP_GET, [](AsyncWebServerRequest *request) {
    request->send(LittleFS, "/wifiManager.html", "text/html");
  });
  server.on("/wifi", HTTP_GET, [](AsyncWebServerRequest *request) {
    request->send(LittleFS, "/wifiManager.html", "text/html");
  });
  server.on("/wifi", HTTP_POST, [](AsyncWebServerRequest *request) {
    String newSsid = request->hasParam("ssid", true) ? request->getParam("ssid", true)->value() : "";
    String newPass = request->hasParam("pass", true) ? request->getParam("pass", true)->value() : "";
    String newIP = request->hasParam("ip", true) ? request->getParam("ip", true)->value() : "";
    String newGW = request->hasParam("gateway", true) ? request->getParam("gateway", true)->value() : "";
    String newSN = request->hasParam("subnet", true) ? request->getParam("subnet", true)->value() : "";
    String newDNS1 = request->hasParam("dns1", true) ? request->getParam("dns1", true)->value() : "";
    String newDNS2 = request->hasParam("dns2", true) ? request->getParam("dns2", true)->value() : "";

    if (newSsid != "" && newPass != "") {
      saveWiFiConfig(newSsid, newPass, newIP, newGW, newSN, newDNS1, newDNS2);
      request->send(200, "text/html", "<h1>Guardado!</h1><p>Reiniciando...</p>");
      delay(2000);
      ESP.restart();
    }
  });

  server.begin();
}
