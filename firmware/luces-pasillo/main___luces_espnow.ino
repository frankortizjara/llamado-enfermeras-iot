// ============================================
// main___luces_espnow.ino
// ESP32 Control Luces - WiFi + ESP-NOW Hibrido
// Sistema Llamado de Enfermeras
// ============================================
//
// ARQUITECTURA HIBRIDA:
// - WiFi conectado permanentemente al router
// - ESP-NOW activo en el mismo canal para alertas
// - Heartbeat HTTP cada 5 minutos al servidor
//
// FLUJO DE UNA ALERTA:
//   Paciente presiona boton en cuarto/bano
//   -> ESP32 Cuarto/Bano envia ESP-NOW broadcast
//   -> Este ESP32 recibe y enciende el rele (~50ms)
//   -> Independiente del servidor/WiFi
//
// HEARTBEAT:
//   Cada 5 minutos envia al servidor:
//   - numero_serial, MAC, IP, uptime
//   - estado del rele, habitacionId, RSSI
//   El dashboard web puede mostrar que dispositivos
//   estan online y su estado actual.
//
// CONSUMO: ~110mA (WiFi+ESP-NOW activos)
//   vs ~150mA original (WiFi+polling HTTP cada 10s)
//   25% menos consumo, 0 sobrecalentamiento
//
// COMO ENTRAR EN MODO CONFIGURACION:
//   Mantener boton BOOT (GPIO0) presionado al encender.
//   O si habitacionId = 0 (primera vez), entra automaticamente.
// ============================================

#include <WiFi.h>
#include <HTTPClient.h>
#include <esp_now.h>
#include <esp_wifi.h>
#include <Preferences.h>
#include <AsyncTCP.h>
#include <ESPAsyncWebServer.h>
#include "data.h"

// Servidor web para configuracion
AsyncWebServer server(80);

// ============================================
// CALLBACK: Mensaje ESP-NOW recibido
// ============================================
void onESPNOWRecibido(const esp_now_recv_info_t *info, const uint8_t *datos, int largo) {
  if (largo != sizeof(MensajeAlerta)) return;

  MensajeAlerta msg;
  memcpy(&msg, datos, sizeof(MensajeAlerta));

  // Solo procesar si el mensaje es para NUESTRA habitacion
  if (msg.habitacionId != (uint16_t)habitacionId) return;

  Serial.printf("ESPNOW recibido: hab=%d tipo=%d cama=%d\n",
                msg.habitacionId, msg.tipoAlerta, msg.cama);

  if (msg.tipoAlerta == 1 || msg.tipoAlerta == 2) {
    digitalWrite(RELE, LOW);   // LOW = ON (logica invertida del rele)
    luzEncendida = true;
    ultimaAlerta = millis();
    Serial.println(">>> LUZ ON");
  } else if (msg.tipoAlerta == 3) {
    digitalWrite(RELE, HIGH);  // HIGH = OFF
    luzEncendida = false;
    Serial.println(">>> LUZ OFF");
  }
}

// ============================================
// Conectar a WiFi
// ============================================
bool conectarWiFi() {
  if (ssid.length() == 0) {
    Serial.println("No hay SSID configurado");
    return false;
  }

  WiFi.disconnect();
  delay(100);

  // Configurar IP estatica si se proporciono
  if (localIP.length() > 0 && gateway.length() > 0) {
    IPAddress ip, gw, sn;
    ip.fromString(localIP);
    gw.fromString(gateway);
    sn.fromString(subnet.length() > 0 ? subnet : "255.255.255.0");
    WiFi.config(ip, gw, sn);
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
  return false;
}

// ============================================
// Inicializar ESP-NOW (despues de WiFi)
// ============================================
bool initESPNOW() {
  // NO cambiar modo WiFi - ya esta en STA conectado
  // ESP-NOW funciona sobre el mismo canal que WiFi STA

  // Desactivar power saving para no perder mensajes ESP-NOW
  esp_wifi_set_ps(WIFI_PS_NONE);

  if (esp_now_init() != ESP_OK) {
    Serial.println("ERROR: esp_now_init() fallo");
    return false;
  }

  // Registrar callback de recepcion
  esp_now_register_recv_cb(onESPNOWRecibido);

  Serial.println("========================================");
  Serial.println("ESP-NOW ACTIVO (hibrido WiFi+ESP-NOW)");
  Serial.println("  Canal: " + String(wifiChannel));
  Serial.println("  Habitacion ID: " + String(habitacionId));
  Serial.println("  MAC: " + WiFi.macAddress());
  Serial.println("  IP: " + WiFi.localIP().toString());
  Serial.println("  Heartbeat cada " + String(INTERVALO_HEARTBEAT / 60000) + " min");
  Serial.println("  Esperando mensajes de cuarto/bano...");
  Serial.println("========================================");

  return true;
}

// ============================================
// CHIP ID
// ============================================
void getChipId() {
  uint64_t chipid = ESP.getEfuseMac();
  uint16_t chip = (uint16_t)(chipid >> 32);
  char serialStr[13];
  snprintf(serialStr, sizeof(serialStr), "%08X%04X", (uint32_t)chipid, chip);
  numero_serial = String(serialStr);
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
// Enviar Heartbeat al servidor
// ============================================
void enviarHeartbeat() {
  if (apiURL.length() == 0 || WiFi.status() != WL_CONNECTED) return;

  unsigned long uptime = (millis() - tiempoInicio) / 1000;
  int rssi = WiFi.RSSI();

  HTTPClient http;
  http.begin(apiURL + "api/dispositivos/heartbeat");
  http.setTimeout(5000);
  http.addHeader("Content-Type", "application/json");

  String body = "{\"numero_serial\":\"" + numero_serial + "\","
    "\"direccion_mac\":\"" + getMacAddress() + "\","
    "\"ip\":\"" + WiFi.localIP().toString() + "\","
    "\"tipo_dispositivo\":\"luces\","
    "\"habitacion_id\":" + String(habitacionId) + ","
    "\"relay_estado\":" + (luzEncendida ? "true" : "false") + ","
    "\"uptime\":" + String(uptime) + ","
    "\"rssi\":" + String(rssi) + "}";

  int httpCode = http.POST(body);
  http.end();

  if (httpCode == 200 || httpCode == 201) {
    Serial.println("Heartbeat OK (uptime=" + String(uptime) + "s rssi=" + String(rssi) + "dBm)");
  } else {
    Serial.println("Heartbeat error: " + String(httpCode));
  }
}

// ============================================
// Modo configuracion (AP con web server)
// ============================================
void iniciarModoConfig() {
  modoConfiguracion = true;
  tiempoInicioAP = millis();

  WiFi.disconnect();
  delay(100);
  WiFi.softAP("ESP32-LUCES-CFG", "12345678");

  Serial.println("========================================");
  Serial.println("MODO CONFIGURACION");
  Serial.println("  Red: ESP32-LUCES-CFG");
  Serial.println("  Password: 12345678");
  Serial.println("  IP: " + WiFi.softAPIP().toString());
  Serial.println("========================================");

  // Pagina de configuracion
  server.on("/", HTTP_GET, [](AsyncWebServerRequest *request) {
    String html = "<!DOCTYPE html><html><head><meta charset='utf-8'>";
    html += "<meta name='viewport' content='width=device-width,initial-scale=1'>";
    html += "<title>ESP32 Luces Config</title>";
    html += "<style>body{font-family:sans-serif;max-width:500px;margin:20px auto;padding:0 15px;background:#1a1a2e;color:#e0e0e0}";
    html += "h1{color:#00d4ff;text-align:center}h2{color:#ccc;border-bottom:1px solid #333;padding-bottom:5px}";
    html += "input{width:100%;padding:10px;margin:5px 0 15px;border:1px solid #333;border-radius:5px;background:#16213e;color:#fff;box-sizing:border-box}";
    html += "button{width:100%;padding:12px;background:#00d4ff;color:#000;border:none;border-radius:5px;font-size:16px;cursor:pointer;font-weight:bold}";
    html += "button:hover{background:#00b8d4}.info{background:#16213e;padding:10px;border-radius:5px;margin:10px 0;font-family:monospace;font-size:13px}";
    html += ".warn{background:#332200;border:1px solid #664400;padding:10px;border-radius:5px;margin:15px 0}";
    html += ".opt{color:#888;font-size:12px}</style></head><body>";
    html += "<h1>ESP32 Luces</h1>";

    html += "<div class='info'>MAC: " + WiFi.macAddress() + "<br>Serial: " + numero_serial + "</div>";

    html += "<form action='/guardar' method='POST'>";

    html += "<h2>Habitacion</h2>";
    html += "<label>ID de Habitacion:</label>";
    html += "<input type='number' name='habId' value='" + String(habitacionId) + "' min='1' required>";
    html += "<div class='warn'>Debe ser IGUAL al habitacion_id del ESP32 cuarto y bano.</div>";

    html += "<h2>Red WiFi</h2>";
    html += "<label>SSID:</label>";
    html += "<input type='text' name='ssid' value='" + ssid + "' required>";
    html += "<label>Password:</label>";
    html += "<input type='password' name='pass' value='" + pass + "' required>";

    html += "<label>IP Estatica: <span class='opt'>(dejar vacio para DHCP)</span></label>";
    html += "<input type='text' name='localIP' value='" + localIP + "' placeholder='192.168.1.200'>";
    html += "<label>Gateway: <span class='opt'>(dejar vacio para DHCP)</span></label>";
    html += "<input type='text' name='gateway' value='" + gateway + "' placeholder='192.168.1.1'>";
    html += "<label>Subnet: <span class='opt'>(dejar vacio para 255.255.255.0)</span></label>";
    html += "<input type='text' name='subnet' value='" + subnet + "' placeholder='255.255.255.0'>";

    html += "<h2>Servidor (Heartbeat)</h2>";
    html += "<label>URL del servidor:</label>";
    html += "<input type='text' name='apiURL' value='" + apiURL + "' placeholder='http://192.168.1.100:3000/'>";
    html += "<div class='warn'>Envia estado cada 5 min. Dejar vacio si no quieres heartbeat.</div>";

    html += "<br><button type='submit'>Guardar y Reiniciar</button>";
    html += "</form></body></html>";

    request->send(200, "text/html", html);
  });

  server.on("/guardar", HTTP_POST, [](AsyncWebServerRequest *request) {
    int newHabId = request->hasParam("habId", true) ? request->getParam("habId", true)->value().toInt() : 0;
    String newSsid = request->hasParam("ssid", true) ? request->getParam("ssid", true)->value() : "";
    String newPass = request->hasParam("pass", true) ? request->getParam("pass", true)->value() : "";
    String newLocalIP = request->hasParam("localIP", true) ? request->getParam("localIP", true)->value() : "";
    String newGateway = request->hasParam("gateway", true) ? request->getParam("gateway", true)->value() : "";
    String newSubnet = request->hasParam("subnet", true) ? request->getParam("subnet", true)->value() : "";
    String newApiURL = request->hasParam("apiURL", true) ? request->getParam("apiURL", true)->value() : "";

    if (newHabId > 0 && newSsid.length() > 0) {
      if (newApiURL.length() > 0 && !newApiURL.endsWith("/")) newApiURL += "/";

      saveConfig(newHabId, newSsid, newPass, newLocalIP, newGateway, newSubnet, newApiURL, wifiChannel);
      request->send(200, "text/html", "<!DOCTYPE html><html><head><meta charset='utf-8'>"
        "<style>body{font-family:sans-serif;text-align:center;padding:50px;background:#1a1a2e;color:#e0e0e0}</style></head>"
        "<body><h1>Guardado!</h1><p>Habitacion ID: " + String(newHabId) + "</p>"
        "<p>WiFi: " + newSsid + "</p>"
        "<p>Reiniciando en 3 segundos...</p></body></html>");
      delay(3000);
      ESP.restart();
    } else {
      request->send(400, "text/html", "<!DOCTYPE html><html><head><meta charset='utf-8'>"
        "<style>body{font-family:sans-serif;text-align:center;padding:50px;background:#1a1a2e;color:#e0e0e0}</style></head>"
        "<body><h1>Error</h1><p>ID habitacion y SSID son obligatorios</p></body></html>");
    }
  });

  server.on("/info", HTTP_GET, [](AsyncWebServerRequest *request) {
    String info = "{\"serial\":\"" + numero_serial + "\",\"mac\":\"" + WiFi.macAddress()
      + "\",\"habitacionId\":" + String(habitacionId) + ",\"canal\":" + String(wifiChannel)
      + ",\"modo\":\"config\"}";
    request->send(200, "application/json", info);
  });

  server.begin();
}

// ============================================
// Web server en modo normal (status/reconfig)
// ============================================
void setupWebServerNormal() {
  server.on("/", HTTP_GET, [](AsyncWebServerRequest *request) {
    unsigned long uptime = (millis() - tiempoInicio) / 1000;
    String html = "<!DOCTYPE html><html><head><meta charset='utf-8'>";
    html += "<meta name='viewport' content='width=device-width,initial-scale=1'>";
    html += "<title>ESP32 Luces - Estado</title>";
    html += "<style>body{font-family:sans-serif;max-width:500px;margin:20px auto;padding:0 15px;background:#1a1a2e;color:#e0e0e0}";
    html += "h1{color:#00d4ff;text-align:center}.info{background:#16213e;padding:10px;border-radius:5px;margin:10px 0;font-family:monospace;font-size:13px}";
    html += ".on{color:#00ff88;font-weight:bold}.off{color:#ff4444;font-weight:bold}";
    html += "a{display:block;text-align:center;color:#00d4ff;margin:20px 0}</style></head><body>";
    html += "<h1>ESP32 Luces</h1>";
    html += "<div class='info'>";
    html += "Serial: " + numero_serial + "<br>";
    html += "MAC: " + WiFi.macAddress() + "<br>";
    html += "IP: " + WiFi.localIP().toString() + "<br>";
    html += "Canal: " + String(wifiChannel) + "<br>";
    html += "Habitacion: " + String(habitacionId) + "<br>";
    html += "RSSI: " + String(WiFi.RSSI()) + " dBm<br>";
    html += "Uptime: " + String(uptime) + "s<br>";
    html += "Rele: <span class='" + String(luzEncendida ? "on'>ENCENDIDO" : "off'>APAGADO") + "</span><br>";
    html += "API: " + (apiURL.length() > 0 ? apiURL : "(sin configurar)") + "<br>";
    html += "</div>";
    html += "<a href='/config'>Configurar</a>";
    html += "<a href='/reboot'>Reiniciar ESP32</a>";
    html += "</body></html>";
    request->send(200, "text/html", html);
  });

  server.on("/info", HTTP_GET, [](AsyncWebServerRequest *request) {
    unsigned long uptime = (millis() - tiempoInicio) / 1000;
    String info = "{\"serial\":\"" + numero_serial + "\",\"mac\":\"" + getMacAddress()
      + "\",\"ip\":\"" + WiFi.localIP().toString()
      + "\",\"habitacionId\":" + String(habitacionId)
      + ",\"canal\":" + String(wifiChannel)
      + ",\"rssi\":" + String(WiFi.RSSI())
      + ",\"uptime\":" + String(uptime)
      + ",\"relay\":" + (luzEncendida ? "true" : "false")
      + ",\"modo\":\"normal\",\"espnow\":true}";
    request->send(200, "application/json", info);
  });

  // ============================================
  // /config - Configurar API y habitacion
  // Permite cambiar apiURL, habitacionId sin
  // necesidad de entrar en modo AP.
  // ============================================
  server.on("/config", HTTP_GET, [](AsyncWebServerRequest *request) {
    String html = "<!DOCTYPE html><html><head><meta charset='utf-8'>";
    html += "<meta name='viewport' content='width=device-width,initial-scale=1'>";
    html += "<title>ESP32 Luces - Configurar</title>";
    html += "<style>body{font-family:sans-serif;max-width:500px;margin:20px auto;padding:0 15px;background:#1a1a2e;color:#e0e0e0}";
    html += "h1{color:#00d4ff;text-align:center}h2{color:#ccc;border-bottom:1px solid #333;padding-bottom:5px;margin-top:20px}";
    html += "input{width:100%;padding:10px;margin:5px 0 15px;border:1px solid #333;border-radius:5px;background:#16213e;color:#fff;box-sizing:border-box}";
    html += "button{width:100%;padding:12px;background:#00d4ff;color:#000;border:none;border-radius:5px;font-size:16px;cursor:pointer;font-weight:bold}";
    html += "button:hover{background:#00b8d4}";
    html += ".info{background:#16213e;padding:10px;border-radius:5px;margin:10px 0;font-family:monospace;font-size:12px}";
    html += ".warn{background:#332200;border:1px solid #664400;padding:10px;border-radius:5px;margin:10px 0;font-size:13px}";
    html += "a{display:block;text-align:center;color:#00d4ff;margin:15px 0;text-decoration:none}</style></head><body>";
    html += "<h1>Configurar ESP32 Luces</h1>";

    html += "<div class='info'>MAC: " + WiFi.macAddress() + "<br>IP: " + WiFi.localIP().toString() + "<br>Serial: " + numero_serial + "</div>";

    html += "<form action='/config' method='POST'>";

    html += "<h2>Habitacion</h2>";
    html += "<label>ID de Habitacion:</label>";
    html += "<input type='number' name='habId' value='" + String(habitacionId) + "' min='1' required>";
    html += "<div class='warn'>Debe ser IGUAL al habitacion_id del ESP32 cuarto y bano de esta habitacion.</div>";

    html += "<h2>Servidor</h2>";
    html += "<label>URL del servidor (para heartbeat):</label>";
    html += "<input type='text' name='apiURL' value='" + apiURL + "' placeholder='http://192.168.1.100:3000/'>";

    html += "<h2>WiFi</h2>";
    html += "<label>SSID:</label>";
    html += "<input type='text' name='ssid' value='" + ssid + "' required>";
    html += "<label>Password:</label>";
    html += "<input type='password' name='pass' value='" + pass + "' required>";
    html += "<label>IP Estatica (vacio=DHCP):</label>";
    html += "<input type='text' name='localIP' value='" + localIP + "' placeholder='192.168.1.200'>";
    html += "<label>Gateway (vacio=DHCP):</label>";
    html += "<input type='text' name='gateway' value='" + gateway + "' placeholder='192.168.1.1'>";
    html += "<label>Subnet (vacio=255.255.255.0):</label>";
    html += "<input type='text' name='subnet' value='" + subnet + "' placeholder='255.255.255.0'>";

    html += "<br><button type='submit'>Guardar y Reiniciar</button>";
    html += "</form>";
    html += "<a href='/'>Volver</a>";
    html += "</body></html>";

    request->send(200, "text/html", html);
  });

  server.on("/config", HTTP_POST, [](AsyncWebServerRequest *request) {
    int newHabId = request->hasParam("habId", true) ? request->getParam("habId", true)->value().toInt() : habitacionId;
    String newApiURL = request->hasParam("apiURL", true) ? request->getParam("apiURL", true)->value() : "";
    String newSsid = request->hasParam("ssid", true) ? request->getParam("ssid", true)->value() : ssid;
    String newPass = request->hasParam("pass", true) ? request->getParam("pass", true)->value() : pass;
    String newLocalIP = request->hasParam("localIP", true) ? request->getParam("localIP", true)->value() : "";
    String newGateway = request->hasParam("gateway", true) ? request->getParam("gateway", true)->value() : "";
    String newSubnet = request->hasParam("subnet", true) ? request->getParam("subnet", true)->value() : "";

    if (newHabId > 0 && newSsid.length() > 0) {
      if (newApiURL.length() > 0 && !newApiURL.endsWith("/")) newApiURL += "/";

      saveConfig(newHabId, newSsid, newPass, newLocalIP, newGateway, newSubnet, newApiURL, wifiChannel);

      request->send(200, "text/html", "<!DOCTYPE html><html><head><meta charset='utf-8'>"
        "<style>body{font-family:sans-serif;text-align:center;padding:50px;background:#1a1a2e;color:#e0e0e0}</style></head>"
        "<body><h1>Guardado!</h1><p>Habitacion: " + String(newHabId) + "</p>"
        "<p>API: " + (newApiURL.length() > 0 ? newApiURL : "(sin configurar)") + "</p>"
        "<p>Reiniciando en 3 segundos...</p></body></html>");
      delay(3000);
      ESP.restart();
    } else {
      request->send(400, "text/html", "<!DOCTYPE html><html><head><meta charset='utf-8'>"
        "<style>body{font-family:sans-serif;text-align:center;padding:50px;background:#1a1a2e;color:#e0e0e0}</style></head>"
        "<body><h1>Error</h1><p>ID habitacion y SSID son obligatorios</p>"
        "<a href='/config' style='color:#00d4ff'>Volver</a></body></html>");
    }
  });

  server.on("/reboot", HTTP_GET, [](AsyncWebServerRequest *request) {
    request->send(200, "text/html", "<!DOCTYPE html><html><head><meta charset='utf-8'>"
      "<style>body{font-family:sans-serif;text-align:center;padding:50px;background:#1a1a2e;color:#e0e0e0}</style></head>"
      "<body><h1>Reiniciando...</h1></body></html>");
    delay(1000);
    ESP.restart();
  });

  server.begin();
  Serial.println("Web server activo en " + WiFi.localIP().toString());
}

// ============================================
// SETUP
// ============================================
void setup() {
  Serial.begin(115200);
  Serial.println("\n=== ESP32 Luces WiFi+ESP-NOW ===");

  // Configurar pines
  pinMode(RELE, OUTPUT);
  digitalWrite(RELE, HIGH);  // Apagado por defecto
  pinMode(BTN_CONFIG, INPUT_PULLUP);

  // Obtener serial
  getChipId();

  // Leer configuracion
  readConfig();

  // Marcar inicio para uptime
  tiempoInicio = millis();

  // Si boton BOOT presionado o sin configuracion -> modo config
  delay(100);
  if (digitalRead(BTN_CONFIG) == LOW || habitacionId == 0) {
    if (habitacionId == 0) {
      Serial.println("Sin configuracion -> Modo AP");
    } else {
      Serial.println("Boton BOOT presionado -> Modo AP");
    }
    iniciarModoConfig();
    return;
  }

  // Modo normal: conectar WiFi + iniciar ESP-NOW
  if (conectarWiFi()) {
    // WiFi conectado -> iniciar ESP-NOW en el mismo canal
    if (!initESPNOW()) {
      Serial.println("Fallo ESP-NOW, entrando a modo config...");
      iniciarModoConfig();
      return;
    }

    // Web server para status
    setupWebServerNormal();

    // Primer heartbeat inmediato
    enviarHeartbeat();
    ultimoHeartbeat = millis();

  } else {
    // WiFi fallo -> modo config
    Serial.println("WiFi fallo, entrando a modo config...");
    iniciarModoConfig();
  }
}

// ============================================
// LOOP
// ============================================
void loop() {
  // Modo configuracion: mantener web server AP
  if (modoConfiguracion) {
    // Timeout del AP -> reintentar WiFi
    if (millis() - tiempoInicioAP >= TIEMPO_AP_MS) {
      if (intentosReconexion < MAX_INTENTOS_RECONEXION && ssid.length() > 0) {
        Serial.println("AP timeout, reintentando WiFi...");
        WiFi.softAPdisconnect(true);
        delay(500);
        ESP.restart();
      }
    }
    delay(100);
    return;
  }

  // Modo normal: ESP-NOW + heartbeat

  // Verificar WiFi
  if (WiFi.status() != WL_CONNECTED) {
    wifiConectado = false;
    Serial.println("WiFi perdido! Reintentando...");

    if (conectarWiFi()) {
      wifiConectado = true;
      Serial.println("WiFi reconectado");
    } else {
      intentosReconexion++;
      if (intentosReconexion >= MAX_INTENTOS_RECONEXION) {
        Serial.println("Max reintentos WiFi - reiniciando...");
        ESP.restart();
      }
      delay(5000);
      return;
    }
  }

  // Heartbeat periodico
  if (millis() - ultimoHeartbeat >= INTERVALO_HEARTBEAT) {
    enviarHeartbeat();
    ultimoHeartbeat = millis();
  }

  // Auto-apagado de seguridad
  if (luzEncendida && (millis() - ultimaAlerta > TIEMPO_AUTO_OFF)) {
    digitalWrite(RELE, HIGH);
    luzEncendida = false;
    Serial.println("Auto-off (timeout)");
  }

  // NO usar light sleep - apaga la radio y pierde mensajes ESP-NOW
  delay(100);
}
