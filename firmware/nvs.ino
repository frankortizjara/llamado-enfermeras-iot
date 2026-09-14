// ============================================
// nvs.ino - Almacenamiento NVS
// FIRMWARE UNIFICADO
//
// Namespaces:
//   "device-config" - tipo de dispositivo
//   "wifi-config"   - credenciales WiFi
//   "api-config"    - servidor, auth, habitacion
//   "mqtt-config"   - broker MQTT (luces)
//   "ota-config"    - OTA programado, heartbeat
//
// Compatible con firmware anterior:
//   Lee habitacionId como Int con fallback a String
// ============================================

// ============================================
// TIPO DE DISPOSITIVO
// ============================================
void readTipoDispositivo() {
  preferences.begin("device-config", true);
  tipoDispositivo = preferences.getString("tipo", "");
  preferences.end();
  Serial.println("Tipo dispositivo: " + (tipoDispositivo.length() > 0 ? tipoDispositivo : "(vacio)"));
}

void saveTipoDispositivo(String tipo) {
  preferences.begin("device-config", false);
  preferences.putString("tipo", tipo);
  preferences.end();
  tipoDispositivo = tipo;
}

// ============================================
// WIFI
// ============================================
void readWiFiConfig() {
  preferences.begin("wifi-config", true);
  ssid = preferences.getString("ssid", "");
  pass = preferences.getString("pass", "");
  localIP = preferences.getString("localIP", "");
  gateway = preferences.getString("gateway", "");
  subnet = preferences.getString("subnet", "");
  dns1 = preferences.getString("dns1", "");
  dns2 = preferences.getString("dns2", "");
  preferences.end();

  Serial.println("WiFi: ssid=" + ssid + " ip=" + localIP);
}

void saveWiFiConfig(String newSsid, String newPass, String newLocalIP,
                    String newGateway, String newSubnet, String newDns1, String newDns2) {
  preferences.begin("wifi-config", false);
  preferences.putString("ssid", newSsid);
  preferences.putString("pass", newPass);
  preferences.putString("localIP", newLocalIP);
  preferences.putString("gateway", newGateway);
  preferences.putString("subnet", newSubnet);
  preferences.putString("dns1", newDns1);
  preferences.putString("dns2", newDns2);
  preferences.end();

  ssid = newSsid;
  pass = newPass;
  localIP = newLocalIP;
  gateway = newGateway;
  subnet = newSubnet;
  dns1 = newDns1;
  dns2 = newDns2;
}

// ============================================
// API / SERVIDOR
// ============================================
void readAPIConfig() {
  preferences.begin("api-config", true);
  apiURL = preferences.getString("apiURL", "");
  apiUser = preferences.getString("apiUser", "admin");
  apiPassword = preferences.getString("apiPass", "123456");
  areaId = preferences.getInt("areaId", 1);

  // habitacionId: intentar Int, fallback String (compat firmware viejo)
  habitacionId = preferences.getInt("habitacionId", 0);
  if (habitacionId == 0) {
    String habStr = preferences.getString("habitacion", "");
    if (habStr.length() > 0) habitacionId = habStr.toInt();
  }

  authToken = preferences.getString("authToken", "");
  reinicio = preferences.getBool("reinicio", false);
  camaUnica = preferences.getBool("camaUnica", false);
  wifiChannel = preferences.getUChar("canal", 1);
  preferences.end();

  Serial.println("API: " + apiURL + " habId=" + String(habitacionId));
}

void saveAPIConfig() {
  preferences.begin("api-config", false);
  preferences.putString("apiURL", apiURL);
  preferences.putString("apiUser", apiUser);
  preferences.putString("apiPass", apiPassword);
  preferences.putInt("areaId", areaId);
  preferences.putInt("habitacionId", habitacionId);
  preferences.putString("authToken", authToken);
  preferences.putBool("reinicio", reinicio);
  preferences.putBool("camaUnica", camaUnica);
  preferences.putUChar("canal", wifiChannel);
  preferences.end();
}

void saveToken(String token) {
  preferences.begin("api-config", false);
  preferences.putString("authToken", token);
  preferences.end();
  authToken = token;
}

// ============================================
// MQTT CONFIG (solo luces)
// ============================================
void readMQTTConfig() {
  preferences.begin("mqtt-config", true);
  mqttPort = preferences.getUShort("mqttPort", 1883);
  mqttUser = preferences.getString("mqttUser", "esp32");
  mqttPassword = preferences.getString("mqttPass", "CAMBIA_ESTA_PASSWORD");
  preferences.end();

  // Extraer host del apiURL (http://192.168.1.100:4000/ -> 192.168.1.100)
  mqttHost = "";
  if (apiURL.length() > 0) {
    String url = apiURL;
    int idx = url.indexOf("://");
    if (idx >= 0) url = url.substring(idx + 3);
    idx = url.indexOf("/");
    if (idx >= 0) url = url.substring(0, idx);
    idx = url.indexOf(":");
    if (idx >= 0) url = url.substring(0, idx);
    mqttHost = url;
  }

  Serial.println("MQTT: host=" + mqttHost + " port=" + String(mqttPort) + " user=" + mqttUser);
}

void saveMQTTConfig(uint16_t port, String user, String pass) {
  preferences.begin("mqtt-config", false);
  preferences.putUShort("mqttPort", port);
  preferences.putString("mqttUser", user);
  preferences.putString("mqttPass", pass);
  preferences.end();

  mqttPort = port;
  mqttUser = user;
  mqttPassword = pass;
}

// ============================================
// OTA CONFIG
// ============================================
void readOTAConfig() {
  preferences.begin("ota-config", true);
  otaHora = preferences.getUChar("otaHora", 3);
  otaDia = preferences.getUChar("otaDia", 0);
  otaHabilitado = preferences.getBool("otaOn", true);

  // Heartbeat configurable (minutos → millis)
  uint8_t hbMin = preferences.getUChar("hbMin", 5);
  if (hbMin < 5) hbMin = 5;
  if (hbMin > 30) hbMin = 30;
  INTERVALO_HEARTBEAT = (unsigned long)hbMin * 60000UL;

  preferences.end();

  Serial.println("OTA: hora=" + String(otaHora) + " dia=" + String(otaDia) +
    " habilitado=" + String(otaHabilitado) + " heartbeat=" + String(hbMin) + "min");
}

void saveOTAConfig(uint8_t hora, uint8_t dia, bool habilitado, uint8_t hbMin) {
  preferences.begin("ota-config", false);
  preferences.putUChar("otaHora", hora);
  preferences.putUChar("otaDia", dia);
  preferences.putBool("otaOn", habilitado);
  preferences.putUChar("hbMin", hbMin);
  preferences.end();

  otaHora = hora;
  otaDia = dia;
  otaHabilitado = habilitado;
  if (hbMin < 5) hbMin = 5;
  if (hbMin > 30) hbMin = 30;
  INTERVALO_HEARTBEAT = (unsigned long)hbMin * 60000UL;
}
