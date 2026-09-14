// ============================================
// ota.ino - Actualizacion OTA
// FIRMWARE UNIFICADO
//
// DOS MODOS DE ACTUALIZACION:
//
// 1. WEB UPLOAD MANUAL:
//    Usuario sube .bin desde /update en el navegador
//    Funciona sin servidor backend
//
// 2. OTA PROGRAMADO:
//    ESP32 consulta al servidor a la hora/dia configurado
//    Requiere endpoint: POST /api/ota/check
//    Si hay update: descarga el .bin automaticamente
//
// SEGURIDAD:
//    - Verificacion de tamano del firmware
//    - Rollback automatico si falla (dual partition)
//    - No se interrumpe operacion normal durante check
//
// CONSUMO:
//    - Check OTA: 1 HTTP POST de ~300ms (1 vez al dia)
//    - Descarga firmware: ~30-90s (solo cuando hay update)
//    - Impacto termico: despreciable
// ============================================

#include <Update.h>
#include <time.h>

// ============================================
// NTP - Sincronizar reloj para OTA programado
// Peru = UTC-5 (sin horario de verano)
// ============================================
void configurarNTP() {
  configTime(-5 * 3600, 0, "pool.ntp.org", "time.nist.gov");
  Serial.print("NTP sincronizando");

  struct tm timeinfo;
  int intentos = 0;
  while (!getLocalTime(&timeinfo) && intentos < 10) {
    delay(500);
    Serial.print(".");
    intentos++;
  }

  if (intentos < 10) {
    char buf[20];
    strftime(buf, sizeof(buf), "%H:%M %d/%m/%Y", &timeinfo);
    Serial.println(" OK: " + String(buf));
  } else {
    Serial.println(" Fallo (OTA programado no disponible hasta reconexion)");
  }
}

// ============================================
// VERIFICAR OTA PROGRAMADO
// Se llama en cada iteracion del loop()
// Solo ejecuta la verificacion real 1 vez al dia
// a la hora y dia configurados
// ============================================
void verificarOTAProgramado() {
  if (!otaHabilitado || otaEnProgreso) return;
  if (apiURL.length() == 0) return;
  if (WiFi.status() != WL_CONNECTED) return;

  // Solo verificar cada 60 segundos (no cada loop)
  static unsigned long ultimaVerificacion = 0;
  if (millis() - ultimaVerificacion < 60000) return;
  ultimaVerificacion = millis();

  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) return;

  // Reset flag despues de que pase la hora programada
  if (otaVerificadoHoy && timeinfo.tm_hour != otaHora) {
    otaVerificadoHoy = false;
  }

  // Ya verifico esta hora?
  if (otaVerificadoHoy) return;

  // Es la hora correcta?
  if (timeinfo.tm_hour != otaHora) return;

  // Es el dia correcto?
  // otaDia: 0=diario, 1=Lun, 2=Mar, 3=Mie, 4=Jue, 5=Vie, 6=Sab, 7=Dom
  // tm_wday: 0=Dom, 1=Lun, 2=Mar, 3=Mie, 4=Jue, 5=Vie, 6=Sab
  if (otaDia != 0) {
    int diaEsperado = (otaDia == 7) ? 0 : otaDia;  // Convertir Dom=7 a tm_wday=0
    if (timeinfo.tm_wday != diaEsperado) return;
  }

  // Ejecutar verificacion (auto-instalar en OTA programado)
  otaVerificadoHoy = true;
  verificarActualizacionRemota(true);
}

// ============================================
// CONSULTAR SERVIDOR POR ACTUALIZACION
// POST /api/ota/check
// Body: { numero_serial, firmware_version, tipo_dispositivo, direccion_mac }
// Respuesta del backend (envuelto en response.success):
//   { "error": false, "status": 200, "body": {
//       "update": true, "version": "2.1.0",
//       "url": "/api/ota/firmware/firmware_2.1.0.bin" } }
//
// autoInstalar=true:  OTA programado → descarga e instala automaticamente
// autoInstalar=false: Verificacion web → solo guarda resultado en variables globales
// ============================================
void verificarActualizacionRemota(bool autoInstalar) {
  logMessage("OTA: Verificando actualizacion...");
  otaCheckStatus = 1;  // verificando
  otaCheckMessage = "Verificando...";

  HTTPClient http;
  http.begin(apiURL + "api/ota/check");
  http.setTimeout(10000);
  http.addHeader("Content-Type", "application/json");

  String macAddr = WiFi.macAddress();
  String body = "{\"numero_serial\":\"" + numero_serial + "\","
    "\"firmware_version\":\"" FIRMWARE_VERSION "\","
    "\"tipo_dispositivo\":\"" + tipoDispositivo + "\","
    "\"direccion_mac\":\"" + macAddr + "\"}";

  int httpCode = http.POST(body);

  if (httpCode == 200) {
    String response = http.getString();
    DynamicJsonDocument doc(1024);
    DeserializationError error = deserializeJson(doc, response);

    // El backend responde { error: false, status: 200, body: { update: true, ... } }
    if (!error && doc.containsKey("body")) {
      JsonObject bodyObj = doc["body"];

      if (bodyObj.containsKey("update") && bodyObj["update"].as<bool>()) {
        String firmwarePath = bodyObj["url"].as<String>();
        String newVersion = bodyObj.containsKey("version") ? bodyObj["version"].as<String>() : "desconocida";
        logMessage("OTA: Nueva version " + newVersion + " disponible");
        http.end();

        // Construir URL completa: apiURL + ruta relativa (sin / inicial)
        if (firmwarePath.startsWith("/")) firmwarePath = firmwarePath.substring(1);
        String fullUrl = apiURL + firmwarePath;

        if (autoInstalar) {
          // OTA programado: descargar e instalar automaticamente
          descargarFirmwareRemoto(fullUrl);
        } else {
          // Verificacion web: guardar resultado para la UI
          otaCheckStatus = 2;  // update disponible
          otaNewVersion = newVersion;
          otaDownloadUrl = fullUrl;
          otaCheckMessage = "Nueva version " + newVersion + " disponible";
        }
        return;
      } else {
        logMessage("OTA: Firmware al dia (v" FIRMWARE_VERSION ")");
        otaCheckStatus = 3;  // al dia
        otaCheckMessage = "Firmware al dia (v" FIRMWARE_VERSION ")";
      }
    } else {
      logMessage("OTA: Respuesta inesperada del servidor");
      otaCheckStatus = 4;  // error
      otaCheckMessage = "Respuesta inesperada del servidor";
    }
  } else if (httpCode == 404) {
    logMessage("OTA: Endpoint no disponible (404)");
    otaCheckStatus = 4;
    otaCheckMessage = "Servidor no tiene endpoint OTA (404)";
  } else {
    logMessage("OTA: Error verificando (" + String(httpCode) + ")");
    otaCheckStatus = 4;
    otaCheckMessage = "Error de conexion (" + String(httpCode) + ")";
  }

  http.end();
}

// ============================================
// DESCARGAR FIRMWARE DESDE SERVIDOR
// GET url → stream → Update.write
// ============================================
void descargarFirmwareRemoto(String url) {
  logMessage("OTA: Descargando firmware...");
  otaEnProgreso = true;

  HTTPClient http;
  http.begin(url);
  http.setTimeout(30000);
  int httpCode = http.GET();

  if (httpCode == 200) {
    int contentLength = http.getSize();
    WiFiClient *stream = http.getStreamPtr();

    if (contentLength > 0 && Update.begin(contentLength)) {
      logMessage("OTA: Escribiendo " + String(contentLength) + " bytes...");

      size_t written = Update.writeStream(*stream);

      if (written == (size_t)contentLength && Update.end(true)) {
        logMessage("OTA: Exito! Reiniciando...");
        http.end();
        delay(1000);
        ESP.restart();
      } else {
        logMessage("OTA: Error escritura (escrito=" + String(written) + ")");
        Update.abort();
      }
    } else {
      logMessage("OTA: No se pudo iniciar update (size=" + String(contentLength) + ")");
    }
  } else {
    logMessage("OTA: Error descarga (" + String(httpCode) + ")");
  }

  http.end();
  otaEnProgreso = false;
}

// ============================================
// WEB UPLOAD OTA - Handler para ESPAsyncWebServer
// Se registra en setupWebServer()
// ============================================
void setupOTAWebHandler() {
  // Pagina de upload (embebida en flash)
  server.on("/update", HTTP_GET, [](AsyncWebServerRequest *request) {
    request->send_P(200, "text/html", PAGE_UPDATE_HTML);
  });

  // Recibir firmware via upload
  server.on("/doUpdate", HTTP_POST,
    // Callback cuando termina el upload
    [](AsyncWebServerRequest *request) {
      bool success = !Update.hasError();
      AsyncWebServerResponse *response = request->beginResponse(
        200, "application/json",
        success ? "{\"success\":true,\"message\":\"Actualizado! Reiniciando...\"}"
                : "{\"success\":false,\"message\":\"Error en la actualizacion\"}");
      response->addHeader("Connection", "close");
      request->send(response);
      if (success) {
        logMessage("OTA Web: Exito! Reiniciando...");
        delay(1000);
        ESP.restart();
      }
    },
    // Callback para cada chunk del archivo
    [](AsyncWebServerRequest *request, const String& filename, size_t index, uint8_t *data, size_t len, bool final) {
      if (index == 0) {
        logMessage("OTA Web: Inicio upload " + filename);
        otaEnProgreso = true;
        if (!Update.begin(UPDATE_SIZE_UNKNOWN)) {
          logMessage("OTA Web: Error begin");
          Update.printError(Serial);
        }
      }

      if (!Update.hasError()) {
        if (Update.write(data, len) != len) {
          logMessage("OTA Web: Error write");
          Update.printError(Serial);
        }
      }

      if (final) {
        if (Update.end(true)) {
          logMessage("OTA Web: Upload completo (" + String(index + len) + " bytes)");
        } else {
          logMessage("OTA Web: Error end");
          Update.printError(Serial);
        }
        otaEnProgreso = false;
      }
    }
  );

  // Verificar manualmente desde web (solo consulta, no auto-instala)
  // NOTA: NO llamar verificarActualizacionRemota() aqui porque es bloqueante
  // y bloquea el web server async. Se usa flag → loop() lo ejecuta.
  server.on("/ota-check", HTTP_POST, [](AsyncWebServerRequest *request) {
    otaCheckStatus = 1;
    otaNewVersion = "";
    otaDownloadUrl = "";
    otaCheckMessage = "Verificando...";
    otaPendienteVerificar = true;
    request->send(200, "text/plain", "Verificando...");
  });

  // Estado de la ultima verificacion (para polling desde la web)
  server.on("/ota-status", HTTP_GET, [](AsyncWebServerRequest *request) {
    String json = "{\"status\":" + String(otaCheckStatus) +
      ",\"message\":\"" + otaCheckMessage + "\"" +
      ",\"version\":\"" + otaNewVersion + "\"" +
      ",\"current\":\"" FIRMWARE_VERSION "\"" +
      ",\"updating\":" + (otaEnProgreso ? "true" : "false") + "}";
    request->send(200, "application/json", json);
  });

  // Descargar e instalar firmware (usuario confirma desde la web)
  // NOTA: NO llamar descargarFirmwareRemoto() aqui porque es bloqueante.
  // Se usa flag → loop() lo ejecuta despues de enviar la respuesta.
  server.on("/ota-download", HTTP_POST, [](AsyncWebServerRequest *request) {
    if (otaDownloadUrl.length() == 0) {
      request->send(400, "text/plain", "No hay firmware para descargar");
      return;
    }
    if (otaEnProgreso) {
      request->send(409, "text/plain", "Actualizacion ya en progreso");
      return;
    }
    otaPendienteDescargar = true;
    request->send(200, "text/plain", "Descargando...");
  });
}
