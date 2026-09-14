// ============================================
// web_pages.h - Paginas web embebidas
// FIRMWARE UNIFICADO
//
// Todas las paginas HTML y CSS estan embebidas
// directamente en el firmware. Esto permite que
// se actualicen via OTA junto con el codigo.
//
// Ya NO se necesita LittleFS ni subir_littlefs.bat
// ============================================

#ifndef WEB_PAGES_H
#define WEB_PAGES_H

// ============================================
// STYLE.CSS
// ============================================
const char PAGE_STYLE_CSS[] PROGMEM = R"rawliteral(* {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: linear-gradient(180deg, #1565c0 0%, #0d47a1 100%);
    min-height: 100vh;
    color: #fff;
    padding: 10px;
}

/* Fondo segun tipo de dispositivo */
body.bg-bano { background: linear-gradient(180deg, #e65100 0%, #bf360c 100%); }
body.bg-luces { background: linear-gradient(180deg, #263238 0%, #1a1a2e 100%); }

/* Header */
.header {
    background: rgba(255,255,255,0.1);
    border-radius: 10px;
    padding: 12px 15px;
    margin-bottom: 12px;
    display: flex;
    align-items: center;
    gap: 12px;
}

.logo { font-size: 1.8em; }
.header-text h1 { font-size: 1.1em; font-weight: 600; }
.header-text .subtitle { font-size: 0.75em; opacity: 0.7; }

/* Status Pills */
.status-bar {
    display: flex;
    gap: 8px;
    margin-bottom: 12px;
    flex-wrap: wrap;
}

.pill {
    background: rgba(255,255,255,0.15);
    padding: 6px 12px;
    border-radius: 20px;
    font-size: 0.8em;
    display: flex;
    align-items: center;
    gap: 6px;
}

.pill.ok { background: rgba(76,175,80,0.4); }
.pill.error { background: rgba(244,67,54,0.4); }

.dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: #4caf50;
}
.dot.off { background: #f44336; }

/* Tipo Pills */
.tipo-pill { font-weight: 600; letter-spacing: 0.5px; }
.tipo-cuarto { background: rgba(33,150,243,0.5); }
.tipo-bano { background: rgba(0,188,212,0.5); }
.tipo-luces { background: rgba(255,193,7,0.5); color: #333; }

/* Cards */
.card {
    background: rgba(255,255,255,0.1);
    border-radius: 10px;
    padding: 15px;
    margin-bottom: 12px;
}

.card-title {
    font-size: 0.95em;
    font-weight: 600;
    margin-bottom: 12px;
    color: #90caf9;
    border-bottom: 1px solid rgba(255,255,255,0.1);
    padding-bottom: 8px;
}

/* Grid */
.grid-2 {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 10px;
}

/* Form */
.form-group { margin-bottom: 10px; }

.form-group label {
    display: block;
    font-size: 0.8em;
    color: #90caf9;
    margin-bottom: 4px;
}

.form-group input,
.form-group select {
    width: 100%;
    padding: 10px;
    border: 2px solid rgba(255,255,255,0.2);
    border-radius: 8px;
    background: rgba(0,0,0,0.25);
    color: #fff;
    font-size: 14px;
}

.form-group input:focus,
.form-group select:focus {
    outline: none;
    border-color: #64b5f6;
}

.form-group small {
    font-size: 0.7em;
    color: rgba(255,255,255,0.5);
}

.form-group select option { background: #1565c0; }

/* Checkbox */
.checkbox {
    display: flex;
    align-items: center;
    gap: 8px;
    margin: 8px 0;
    font-size: 0.85em;
}
.checkbox input { width: 18px; height: 18px; }

/* Buttons */
.btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 5px;
    padding: 10px 14px;
    border: none;
    border-radius: 8px;
    font-size: 0.85em;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    color: #fff;
    text-decoration: none;
}

.btn:hover { transform: translateY(-1px); opacity: 0.9; }
.btn:active { transform: translateY(0); }
.btn:disabled { opacity: 0.5; cursor: not-allowed; transform: none; }

.btn-primary { background: #1976d2; }
.btn-success { background: #43a047; }
.btn-warning { background: #fb8c00; }
.btn-danger { background: #e53935; }
.btn-secondary { background: #546e7a; }
.btn-info { background: #00acc1; }
.btn-block { width: 100%; }
.btn-sm { padding: 8px 10px; font-size: 0.8em; }

.btn-group {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
}

/* Test Section */
.test-box {
    background: rgba(0,0,0,0.2);
    border-radius: 8px;
    padding: 12px;
    margin-top: 10px;
}
.test-box .grid-2 { margin-bottom: 10px; }

/* Log Section */
.log-box {
    background: rgba(0,0,0,0.25);
    border-radius: 8px;
    padding: 10px;
    margin-top: 12px;
}

.log-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 8px;
}

.log-header span {
    font-size: 0.85em;
    color: #90caf9;
    font-weight: 600;
}

#logContent {
    background: rgba(0,0,0,0.3);
    border-radius: 6px;
    padding: 10px;
    font-family: 'Consolas', monospace;
    font-size: 10px;
    height: 150px;
    overflow-y: auto;
    white-space: pre-wrap;
    word-break: break-all;
    color: #b0bec5;
    line-height: 1.4;
}

#logContent::-webkit-scrollbar { width: 5px; }
#logContent::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.2); border-radius: 3px; }

/* Toast */
.toast {
    position: fixed;
    bottom: 15px;
    left: 50%;
    transform: translateX(-50%);
    background: #323232;
    color: #fff;
    padding: 10px 20px;
    border-radius: 8px;
    font-size: 0.85em;
    z-index: 1000;
    animation: slideUp 0.3s;
}

.toast.success { background: #43a047; }
.toast.error { background: #e53935; }

@keyframes slideUp {
    from { transform: translate(-50%, 100%); opacity: 0; }
    to { transform: translate(-50%, 0); opacity: 1; }
}

/* Nav */
.nav-links {
    display: flex;
    gap: 15px;
    justify-content: center;
    margin-top: 12px;
    flex-wrap: wrap;
}

.nav-links a {
    color: #90caf9;
    text-decoration: none;
    font-size: 0.8em;
}

/* Menu Grid */
.menu-grid {
    display: grid;
    grid-template-columns: 1fr 1fr 1fr;
    gap: 10px;
}

.menu-item {
    background: rgba(255,255,255,0.1);
    border-radius: 10px;
    padding: 15px 8px;
    text-align: center;
    text-decoration: none;
    color: #fff;
    transition: all 0.2s;
}

.menu-item:hover {
    background: rgba(255,255,255,0.15);
    transform: translateY(-2px);
}

.menu-item .icon { font-size: 1.5em; margin-bottom: 6px; }
.menu-item .label { font-size: 0.75em; }

/* Info Box */
.info-box {
    background: rgba(0,0,0,0.2);
    border-radius: 8px;
    padding: 12px;
    border-left: 3px solid #64b5f6;
}

.info-box ol { margin-left: 18px; font-size: 0.85em; }
.info-box li { margin: 6px 0; }

/* Selector de tipo (primera configuracion) */
.tipo-grid {
    display: grid;
    grid-template-columns: 1fr 1fr 1fr;
    gap: 10px;
    margin-bottom: 10px;
}

.tipo-option input[type="radio"] { display: none; }

.tipo-card {
    background: rgba(0,0,0,0.2);
    border: 2px solid rgba(255,255,255,0.15);
    border-radius: 10px;
    padding: 15px 8px;
    text-align: center;
    cursor: pointer;
    transition: all 0.2s;
}

.tipo-option input:checked + .tipo-card {
    border-color: #64b5f6;
    background: rgba(100,181,246,0.2);
}

.tipo-card:hover {
    border-color: rgba(255,255,255,0.4);
}

.tipo-icon { font-size: 2em; margin-bottom: 8px; }
.tipo-name { font-weight: 600; font-size: 0.95em; margin-bottom: 4px; }
.tipo-desc { font-size: 0.7em; opacity: 0.7; }

/* Progress Bar (OTA) */
.progress-bar {
    background: rgba(0,0,0,0.3);
    border-radius: 10px;
    height: 20px;
    overflow: hidden;
}

.progress-fill {
    height: 100%;
    background: #fb8c00;
    border-radius: 10px;
    transition: width 0.3s;
    width: 0%;
}

/* WiFi Form */
hr {
    border: none;
    border-top: 1px solid rgba(255,255,255,0.1);
    margin: 15px 0;
}

h3 {
    font-size: 0.95em;
    color: #90caf9;
    margin-bottom: 10px;
}

/* Relay status */
.on { color: #00ff88; }
.off { color: #ff4444; }

/* Loading */
.loading {
    display: inline-block;
    width: 14px;
    height: 14px;
    border: 2px solid rgba(255,255,255,0.3);
    border-radius: 50%;
    border-top-color: #fff;
    animation: spin 0.8s linear infinite;
}

@keyframes spin { to { transform: rotate(360deg); } }

/* Responsive */
@media (max-width: 400px) {
    .tipo-grid { grid-template-columns: 1fr; }
    .menu-grid { grid-template-columns: 1fr 1fr; }
    .grid-2 { grid-template-columns: 1fr; }
}
)rawliteral";

// ============================================
// INDEX.HTML (tiene template vars: {{tipoDispositivo}}, {{version}})
// ============================================
const char PAGE_INDEX_HTML[] PROGMEM = R"rawliteral(<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
    <title>ESP32 - Sistema de Enfermeras</title>
    <link rel="stylesheet" href="/style.css">
</head>
<body>
    <div class="header">
        <div class="logo">&#x1F3E5;</div>
        <div class="header-text">
            <h1 id="titulo">Sistema de Enfermeras</h1>
            <div class="subtitle" id="subtitulo">ESP32 Unificado v{{version}}</div>
        </div>
    </div>

    <!-- Badge tipo -->
    <div class="status-bar">
        <div class="pill tipo-pill" id="tipoPill">
            <span id="tipoTexto"></span>
        </div>
        <div class="pill">
            <span>v{{version}}</span>
        </div>
    </div>

    <!-- Menu Grid -->
    <div class="menu-grid">
        <a href="/api" class="menu-item">
            <div class="icon">&#x2699;</div>
            <div class="label">Configuracion</div>
        </a>
        <a href="/wifi" class="menu-item">
            <div class="icon">&#x1F4F6;</div>
            <div class="label">WiFi</div>
        </a>
        <a href="/update" class="menu-item">
            <div class="icon">&#x1F4E6;</div>
            <div class="label">Actualizar</div>
        </a>
        <a href="/log" class="menu-item">
            <div class="icon">&#x1F4CB;</div>
            <div class="label">Logs</div>
        </a>
        <a href="/info" class="menu-item">
            <div class="icon">&#x2139;</div>
            <div class="label">Info JSON</div>
        </a>
        <a href="/reboot" class="menu-item" onclick="return confirm('Reiniciar ESP32?')">
            <div class="icon">&#x1F504;</div>
            <div class="label">Reiniciar</div>
        </a>
    </div>

    <!-- Instrucciones contextuales -->
    <div class="card" style="margin-top: 15px;">
        <div class="card-title">Instrucciones</div>
        <div class="info-box" id="instrucciones"></div>
    </div>

    <script>
        var TIPO = "{{tipoDispositivo}}";

        var tipoPill = document.getElementById('tipoPill');
        var tipoTexto = document.getElementById('tipoTexto');
        var instrucciones = document.getElementById('instrucciones');

        if (TIPO === 'bano') document.body.classList.add('bg-bano');
        if (TIPO === 'luces') document.body.classList.add('bg-luces');

        if (TIPO === 'cuarto') {
            tipoTexto.textContent = 'CUARTO';
            tipoPill.classList.add('tipo-cuarto');
            instrucciones.innerHTML = '<ol>' +
                '<li>Ir a <strong>Configuracion</strong></li>' +
                '<li>Ingresar URL del servidor, usuario y password</li>' +
                '<li>Configurar Area ID y Habitacion ID</li>' +
                '<li>Clic en <strong>Login</strong> para obtener token</li>' +
                '<li>Clic en <strong>Registrar ESP32</strong></li>' +
                '<li>Probar alertas con los botones de test</li>' +
                '</ol>';
        } else if (TIPO === 'bano') {
            tipoTexto.textContent = 'BANO';
            tipoPill.classList.add('tipo-bano');
            instrucciones.innerHTML = '<ol>' +
                '<li>Ir a <strong>Configuracion</strong></li>' +
                '<li>Ingresar URL del servidor, usuario y password</li>' +
                '<li>Configurar Area ID y Habitacion ID</li>' +
                '<li>Clic en <strong>Login</strong> y luego <strong>Registrar</strong></li>' +
                '<li>Las alertas del bano siempre usan cama=0</li>' +
                '</ol>';
        } else if (TIPO === 'luces') {
            tipoTexto.textContent = 'LUCES';
            tipoPill.classList.add('tipo-luces');
            instrucciones.innerHTML = '<ol>' +
                '<li>Ir a <strong>Configuracion</strong></li>' +
                '<li>Configurar Habitacion ID (MISMO que el cuarto/bano)</li>' +
                '<li>Opcionalmente configurar URL servidor (heartbeat)</li>' +
                '<li>El rele se activa automaticamente via ESP-NOW</li>' +
                '<li>Auto-apagado despues de 10 min sin actividad</li>' +
                '</ol>';
        }
    </script>
</body>
</html>
)rawliteral";

// ============================================
// SELECTOR.HTML (sin template vars)
// ============================================
const char PAGE_SELECTOR_HTML[] PROGMEM = R"rawliteral(<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
    <title>ESP32 - Configuracion Inicial</title>
    <link rel="stylesheet" href="/style.css">
</head>
<body>
    <div class="header">
        <div class="logo">&#x1F3E5;</div>
        <div class="header-text">
            <h1>Configuracion Inicial</h1>
            <div class="subtitle">Sistema de Enfermeras - ESP32</div>
        </div>
    </div>

    <form action="/setup" method="POST" id="setupForm">
        <!-- Paso 1: Tipo de dispositivo -->
        <div class="card">
            <div class="card-title">1. Tipo de Dispositivo</div>
            <div class="tipo-grid">
                <label class="tipo-option">
                    <input type="radio" name="tipo" value="cuarto" required>
                    <div class="tipo-card">
                        <div class="tipo-icon">&#x1F6CF;</div>
                        <div class="tipo-name">Cuarto</div>
                        <div class="tipo-desc">Control de camas con receptor RF 433MHz</div>
                    </div>
                </label>
                <label class="tipo-option">
                    <input type="radio" name="tipo" value="bano">
                    <div class="tipo-card">
                        <div class="tipo-icon">&#x1F6BF;</div>
                        <div class="tipo-name">Bano</div>
                        <div class="tipo-desc">Control de banio con botones de emergencia</div>
                    </div>
                </label>
                <label class="tipo-option">
                    <input type="radio" name="tipo" value="luces">
                    <div class="tipo-card">
                        <div class="tipo-icon">&#x1F4A1;</div>
                        <div class="tipo-name">Luces</div>
                        <div class="tipo-desc">Receptor ESP-NOW que controla rele del corredor</div>
                    </div>
                </label>
            </div>
        </div>

        <!-- Paso 2: WiFi -->
        <div class="card">
            <div class="card-title">2. Red WiFi</div>
            <div class="form-group">
                <label>SSID (Nombre de Red)</label>
                <input type="text" name="ssid" required placeholder="Nombre de tu WiFi">
            </div>
            <div class="form-group">
                <label>Password</label>
                <input type="password" name="pass" required placeholder="Contrasena WiFi">
            </div>

            <hr>
            <h3>IP Estatica (Opcional)</h3>
            <p style="font-size:0.8em; opacity:0.7; margin-bottom:10px;">Dejar vacio para usar DHCP automatico</p>

            <div class="grid-2">
                <div class="form-group">
                    <label>IP Local</label>
                    <input type="text" name="ip" placeholder="192.168.0.100">
                </div>
                <div class="form-group">
                    <label>Gateway</label>
                    <input type="text" name="gateway" placeholder="192.168.0.1">
                </div>
            </div>
            <div class="grid-2">
                <div class="form-group">
                    <label>Subnet</label>
                    <input type="text" name="subnet" placeholder="255.255.255.0" value="255.255.255.0">
                </div>
                <div class="form-group">
                    <label>DNS 1</label>
                    <input type="text" name="dns1" placeholder="8.8.8.8">
                </div>
            </div>
        </div>

        <button type="submit" class="btn btn-primary btn-block" id="btnGuardar">
            Guardar y Reiniciar
        </button>
    </form>

    <script>
        document.getElementById('setupForm').addEventListener('submit', function(e) {
            var btn = document.getElementById('btnGuardar');
            btn.disabled = true;
            btn.innerHTML = '<span class="loading"></span> Guardando...';
        });
    </script>
</body>
</html>
)rawliteral";

// ============================================
// API_MANAGER.HTML (tiene muchos template vars)
// ============================================
const char PAGE_API_MANAGER_HTML[] PROGMEM = R"rawliteral(<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
    <title>ESP32 - Configuracion</title>
    <link rel="stylesheet" href="/style.css">
</head>
<body>
    <!-- Header -->
    <div class="header">
        <div class="logo">&#x2699;</div>
        <div class="header-text">
            <h1>Configuracion</h1>
            <div class="subtitle" id="subtitulo">ESP32 v{{version}}</div>
        </div>
    </div>

    <!-- Status Bar -->
    <div class="status-bar">
        <div class="pill tipo-pill" id="tipoPill">
            <span id="tipoLabel"></span>
        </div>
        <div class="pill {{tokenClass}}" id="tokenPill">
            <span class="dot {{tokenDot}}"></span>
            <span id="tokenText">{{tokenStatus}}</span>
        </div>
        <div class="pill">
            <span>Hab: {{habitacionId}}</span>
        </div>
    </div>

    <!-- Configuracion del Servidor -->
    <div class="card">
        <div class="card-title">Configuracion del Servidor</div>
        <form id="configForm">
            <div class="form-group">
                <label>URL del Servidor</label>
                <input type="text" name="apiURL" id="apiURL" value="{{apiURL}}" placeholder="http://192.168.0.159:4000/">
            </div>

            <div class="form-group">
                <label>Habitacion ID</label>
                <input type="number" name="habitacionId" id="habitacionIdInput" value="{{habitacionId}}" min="1">
                <small id="habIdHelp">ID de habitacion en BD</small>
            </div>

            <!-- Solo cuarto/bano: auth y area -->
            <div id="seccionAuth">
                <div class="grid-2">
                    <div class="form-group">
                        <label>Usuario</label>
                        <input type="text" name="apiUser" id="apiUser" value="{{apiUser}}" placeholder="admin">
                    </div>
                    <div class="form-group">
                        <label>Password</label>
                        <input type="password" name="apiPass" id="apiPass" value="{{apiPass}}" placeholder="******">
                    </div>
                </div>
                <div class="form-group">
                    <label>Area ID</label>
                    <input type="number" name="areaId" id="areaIdInput" value="{{areaId}}" min="1">
                    <small>ID del area en BD</small>
                </div>
            </div>

            <!-- Solo cuarto: cama unica -->
            <div id="seccionCama">
                <div class="checkbox">
                    <input type="checkbox" name="camaUnica" id="camaUnica" {{camaUnica}}>
                    <label for="camaUnica">Modo cama unica</label>
                </div>
            </div>

            <!-- Solo cuarto/bano: reinicio -->
            <div id="seccionReinicio">
                <div class="checkbox">
                    <input type="checkbox" name="reinicio" id="reinicio" {{reinicio}}>
                    <label for="reinicio">Reiniciar si pierde WiFi</label>
                </div>
            </div>

            <!-- Solo luces: estado rele -->
            <div id="seccionRele" class="card" style="margin:10px 0;padding:10px">
                <div style="display:flex;align-items:center;gap:10px">
                    <span>Estado del Rele:</span>
                    <span class="{{relayClass}}" style="font-weight:bold">{{relayEstado}}</span>
                </div>
                <small>Se controla via MQTT + ESP-NOW</small>
            </div>

            <!-- Solo luces: MQTT -->
            <div id="seccionMqtt">
                <div class="card-title" style="margin-top:10px">MQTT (Luces)</div>
                <div class="grid-2">
                    <div class="form-group">
                        <label>MQTT Puerto</label>
                        <input type="number" name="mqttPort" id="mqttPort" value="{{mqttPort}}" min="1" max="65535">
                        <small>Default: 1883</small>
                    </div>
                    <div class="form-group">
                        <label>MQTT Usuario</label>
                        <input type="text" name="mqttUser" id="mqttUser" value="{{mqttUser}}" placeholder="esp32">
                    </div>
                </div>
                <div class="form-group">
                    <label>MQTT Password</label>
                    <input type="password" name="mqttPass" id="mqttPass" value="{{mqttPass}}" placeholder="******">
                </div>
                <small>Host MQTT se extrae de la URL del servidor</small>
            </div>

            <hr>

            <!-- Heartbeat y OTA (todos) -->
            <div class="card-title" style="margin-top:10px">Heartbeat y OTA</div>

            <div class="grid-2">
                <div class="form-group">
                    <label>Heartbeat (minutos)</label>
                    <input type="number" name="heartbeatMin" id="heartbeatMin" value="{{heartbeatMin}}" min="5" max="30">
                    <small>Cada cuanto enviar estado (5-30 min)</small>
                </div>
                <div class="form-group">
                    <label>OTA: Hora de verificacion</label>
                    <input type="number" name="otaHora" id="otaHora" value="{{otaHora}}" min="0" max="23">
                    <small>0-23 (hora del dia)</small>
                </div>
            </div>

            <div class="grid-2">
                <div class="form-group">
                    <label>OTA: Dia</label>
                    <select name="otaDia" id="otaDia">
                        <option value="0">Diario</option>
                        <option value="1">Lunes</option>
                        <option value="2">Martes</option>
                        <option value="3">Miercoles</option>
                        <option value="4">Jueves</option>
                        <option value="5">Viernes</option>
                        <option value="6">Sabado</option>
                        <option value="7">Domingo</option>
                    </select>
                </div>
                <div class="form-group" style="display:flex;align-items:center;padding-top:20px">
                    <div class="checkbox">
                        <input type="checkbox" name="otaHabilitado" id="otaHabilitado" {{otaHabilitado}}>
                        <label for="otaHabilitado">OTA automatico</label>
                    </div>
                </div>
            </div>

            <button type="submit" class="btn btn-primary btn-block">Guardar Configuracion</button>
        </form>
    </div>

    <!-- Acciones (cuarto/bano) -->
    <div class="card" id="seccionAcciones">
        <div class="card-title">Conexion</div>
        <div class="btn-group">
            <button onclick="doAction('login')" class="btn btn-success" id="btnLogin">
                Login
            </button>
            <button onclick="doAction('registrar')" class="btn btn-info" id="btnRegistrar">
                Registrar ESP32
            </button>
            <button onclick="location.href='/reboot'" class="btn btn-secondary">
                Reiniciar
            </button>
        </div>
    </div>

    <!-- Probar Alertas (cuarto/bano) -->
    <div class="card" id="seccionTest">
        <div class="card-title">Probar Alertas</div>
        <div class="test-box">
            <!-- Selector cama (solo cuarto) -->
            <div class="grid-2" id="testCamaRow">
                <div class="form-group">
                    <label>Seleccionar Cama</label>
                    <select id="testCama">
                        <option value="1">Cama A</option>
                        <option value="2">Cama B</option>
                        <option value="3">Cama C</option>
                        <option value="4">Cama D</option>
                    </select>
                </div>
                <div class="form-group">
                    <label>Tipo de Alerta</label>
                    <select id="testTipo">
                        <option value="1">1 - Urgente</option>
                        <option value="2">2 - Emergencia</option>
                        <option value="3">3 - Apagar</option>
                    </select>
                </div>
            </div>
            <!-- Solo tipo (bano) -->
            <div class="form-group" id="testTipoSolo" style="display:none">
                <label>Tipo de Alerta</label>
                <select id="testTipoBano">
                    <option value="1">1 - Urgente</option>
                    <option value="2">2 - Emergencia</option>
                    <option value="3">3 - Apagar</option>
                </select>
            </div>
            <div class="btn-group">
                <button onclick="testAlerta()" class="btn btn-warning" id="btnTest">
                    Enviar Alerta
                </button>
                <button onclick="doAction('test-apagar')" class="btn btn-secondary" id="btnApagar">
                    Apagar Todas
                </button>
            </div>
        </div>
    </div>

    <!-- Cambiar tipo -->
    <div class="card">
        <div class="card-title">Dispositivo</div>
        <div class="form-group">
            <label>Cambiar tipo de dispositivo</label>
            <div class="btn-group" style="margin-top:8px">
                <select id="nuevoTipo" style="flex:1;padding:10px;border:2px solid rgba(255,255,255,0.2);border-radius:8px;background:rgba(0,0,0,0.25);color:#fff;font-size:14px">
                    <option value="cuarto">Cuarto</option>
                    <option value="bano">Bano</option>
                    <option value="luces">Luces</option>
                </select>
                <button onclick="cambiarTipo()" class="btn btn-danger">Cambiar</button>
            </div>
            <small style="color:#ff9800">Requiere reinicio. La configuracion WiFi se mantiene.</small>
        </div>
    </div>

    <!-- Logs -->
    <div class="log-box">
        <div class="log-header">
            <span>Logs</span>
            <button onclick="refreshLogs()" class="btn btn-sm btn-secondary">Actualizar</button>
        </div>
        <div id="logContent">Cargando...</div>
    </div>

    <!-- Navigation -->
    <div class="nav-links">
        <a href="/">Inicio</a>
        <a href="/wifi">WiFi</a>
        <a href="/update">Actualizar</a>
        <a href="/info">Info</a>
    </div>

    <script>
        var TIPO = "{{tipoDispositivo}}";
        var logInterval;

        // === Fondo segun tipo ===
        if (TIPO === 'bano') document.body.classList.add('bg-bano');
        if (TIPO === 'luces') document.body.classList.add('bg-luces');

        // === Adaptar interfaz segun tipo ===
        (function() {
            var tipoPill = document.getElementById('tipoPill');
            var tipoLabel = document.getElementById('tipoLabel');

            if (TIPO === 'cuarto') {
                tipoLabel.textContent = 'CUARTO';
                tipoPill.classList.add('tipo-cuarto');
                // Mostrar todo
            } else if (TIPO === 'bano') {
                tipoLabel.textContent = 'BANO';
                tipoPill.classList.add('tipo-bano');
                // Ocultar cama unica
                document.getElementById('seccionCama').style.display = 'none';
                // Test: ocultar selector cama, mostrar solo tipo
                document.getElementById('testCamaRow').style.display = 'none';
                document.getElementById('testTipoSolo').style.display = 'block';
            } else if (TIPO === 'luces') {
                tipoLabel.textContent = 'LUCES';
                tipoPill.classList.add('tipo-luces');
                // Ocultar secciones de auth, cama, reinicio, acciones, test
                document.getElementById('seccionAuth').style.display = 'none';
                document.getElementById('seccionCama').style.display = 'none';
                document.getElementById('seccionReinicio').style.display = 'none';
                document.getElementById('seccionAcciones').style.display = 'none';
                document.getElementById('seccionTest').style.display = 'none';
                // Mostrar rele y MQTT
                document.getElementById('seccionRele').style.display = 'block';
                document.getElementById('seccionMqtt').style.display = 'block';
                // Ajustar help text
                document.getElementById('habIdHelp').textContent = 'DEBE ser IGUAL al del cuarto/bano de esta habitacion';
            }

            // Ocultar rele y MQTT para cuarto/bano
            if (TIPO !== 'luces') {
                document.getElementById('seccionRele').style.display = 'none';
                document.getElementById('seccionMqtt').style.display = 'none';
            }

            // Seleccionar OTA dia actual
            var otaDiaSelect = document.getElementById('otaDia');
            otaDiaSelect.value = "{{otaDia}}";

            // Seleccionar tipo actual en cambiar
            document.getElementById('nuevoTipo').value = TIPO;
        })();

        // === Logs ===
        function refreshLogs() {
            fetch('/get-log')
                .then(function(r) { return r.text(); })
                .then(function(data) {
                    var el = document.getElementById('logContent');
                    el.textContent = data || 'Sin logs';
                    el.scrollTop = el.scrollHeight;
                })
                .catch(function(e) { console.error(e); });
        }

        // === Toast ===
        function showToast(msg, type) {
            var existing = document.querySelector('.toast');
            if (existing) existing.remove();
            var toast = document.createElement('div');
            toast.className = 'toast ' + (type || '');
            toast.textContent = msg;
            document.body.appendChild(toast);
            setTimeout(function() { toast.remove(); }, 3000);
        }

        // === Acciones ===
        function doAction(action) {
            var btn = document.getElementById('btn' + action.charAt(0).toUpperCase() + action.slice(1));
            if (btn) {
                btn.disabled = true;
                btn.innerHTML = '<span class="loading"></span>';
            }
            fetch('/' + action, { method: 'POST' })
                .then(function(r) { return r.text(); })
                .then(function(data) {
                    if (data.indexOf('OK') >= 0 || data.indexOf('Registrado') >= 0 || data.indexOf('exitoso') >= 0) {
                        showToast('Completado: ' + action, 'success');
                        if (action === 'login') {
                            document.getElementById('tokenText').textContent = 'Token OK';
                            document.getElementById('tokenPill').className = 'pill ok';
                        }
                    } else {
                        showToast('Revisar logs', 'error');
                    }
                    refreshLogs();
                })
                .catch(function(e) { showToast('Error: ' + e, 'error'); })
                .finally(function() {
                    if (btn) {
                        btn.disabled = false;
                        if (action === 'login') btn.innerHTML = 'Login';
                        if (action === 'registrar') btn.innerHTML = 'Registrar ESP32';
                    }
                });
        }

        // === Test Alerta ===
        function testAlerta() {
            var cama, tipo;
            if (TIPO === 'bano') {
                cama = 0;
                tipo = document.getElementById('testTipoBano').value;
            } else {
                cama = document.getElementById('testCama').value;
                tipo = document.getElementById('testTipo').value;
            }
            var btn = document.getElementById('btnTest');
            btn.disabled = true;
            btn.innerHTML = '<span class="loading"></span>';

            fetch('/test-alerta?cama=' + cama + '&tipo=' + tipo, { method: 'POST' })
                .then(function(r) { return r.text(); })
                .then(function(data) {
                    showToast('Alerta enviada', 'success');
                    refreshLogs();
                })
                .catch(function(e) { showToast('Error', 'error'); })
                .finally(function() {
                    btn.disabled = false;
                    btn.innerHTML = 'Enviar Alerta';
                });
        }

        // === Cambiar Tipo ===
        function cambiarTipo() {
            var nuevoTipo = document.getElementById('nuevoTipo').value;
            if (nuevoTipo === TIPO) {
                showToast('Ya es tipo ' + TIPO, 'error');
                return;
            }
            if (!confirm('Cambiar a tipo "' + nuevoTipo + '"? El ESP32 se reiniciara.')) return;

            fetch('/cambiar-tipo', {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: 'tipo=' + nuevoTipo
            })
            .then(function(r) { return r.text(); })
            .then(function(data) { showToast('Cambiado! Reiniciando...', 'success'); })
            .catch(function(e) { showToast('Error', 'error'); });
        }

        // === Form Submit ===
        document.getElementById('configForm').addEventListener('submit', function(e) {
            e.preventDefault();
            var formData = new FormData(this);
            var btn = this.querySelector('button[type="submit"]');
            btn.disabled = true;
            btn.innerHTML = '<span class="loading"></span> Guardando...';

            fetch('/api', { method: 'POST', body: new URLSearchParams(formData) })
                .then(function(r) { return r.text(); })
                .then(function(data) {
                    showToast('Configuracion guardada', 'success');
                    document.querySelector('.pill:nth-child(3) span').textContent =
                        'Hab: ' + document.getElementById('habitacionIdInput').value;
                })
                .catch(function(e) { showToast('Error al guardar', 'error'); })
                .finally(function() {
                    btn.disabled = false;
                    btn.innerHTML = 'Guardar Configuracion';
                });
        });

        // Iniciar logs
        refreshLogs();
        logInterval = setInterval(refreshLogs, 5000);
    </script>
</body>
</html>
)rawliteral";

// ============================================
// WIFI_MANAGER.HTML (sin template vars)
// ============================================
const char PAGE_WIFI_MANAGER_HTML[] PROGMEM = R"rawliteral(<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
    <title>WiFi - ESP32</title>
    <link rel="stylesheet" href="/style.css">
</head>
<body>
    <div class="header">
        <div class="logo">&#x1F4F6;</div>
        <div class="header-text">
            <h1>Configuracion WiFi</h1>
            <div class="subtitle">{{modoSubtitle}}</div>
        </div>
    </div>

    <!-- Info configuracion anterior (solo visible si hay datos previos) -->
    <div class="card" id="prevConfig" style="{{prevDisplay}}">
        <div class="card-title">Configuracion Anterior</div>
        <div style="font-size:0.85em; line-height:1.8;">
            <div><strong>SSID:</strong> {{prevSsid}}</div>
            <div><strong>IP Configurada:</strong> {{prevIP}}</div>
            <div><strong>Gateway:</strong> {{prevGW}}</div>
            <div><strong>Serial:</strong> {{serial}}</div>
            <div><strong>Tipo:</strong> {{tipoDisp}}</div>
            <div><strong>Firmware:</strong> v{{version}}</div>
            <div style="margin-top:8px; padding:8px; background:rgba(255,152,0,0.3); border-radius:5px;">
                {{reconexionInfo}}
            </div>
        </div>
    </div>

    <div class="card">
        <div class="card-title">Red WiFi</div>
        <form action="/wifi" method="POST">
            <div class="form-group">
                <label>SSID (Nombre de Red)</label>
                <input type="text" name="ssid" required placeholder="Nombre de tu WiFi" value="{{valSsid}}">
            </div>
            <div class="form-group">
                <label>Password</label>
                <input type="password" name="pass" required placeholder="Contrasena WiFi">
                <small>Dejar vacio mantiene la contrasena anterior</small>
            </div>

            <hr>
            <h3>IP Estatica (Opcional)</h3>
            <p style="font-size:0.8em; opacity:0.7; margin-bottom:10px;">Dejar vacio para usar DHCP automatico</p>

            <div class="grid-2">
                <div class="form-group">
                    <label>IP Local</label>
                    <input type="text" name="ip" placeholder="192.168.0.100" value="{{valIP}}">
                </div>
                <div class="form-group">
                    <label>Gateway</label>
                    <input type="text" name="gateway" placeholder="192.168.0.1" value="{{valGW}}">
                </div>
            </div>
            <div class="grid-2">
                <div class="form-group">
                    <label>Subnet</label>
                    <input type="text" name="subnet" placeholder="255.255.255.0" value="{{valSubnet}}">
                </div>
                <div class="form-group">
                    <label>DNS 1</label>
                    <input type="text" name="dns1" placeholder="8.8.8.8" value="{{valDNS1}}">
                </div>
            </div>

            <button type="submit" class="btn btn-primary btn-block">Guardar y Reiniciar</button>
        </form>
    </div>

    <div class="nav-links">
        <a href="/">Inicio</a>
        <a href="/api">Configuracion</a>
    </div>
</body>
</html>
)rawliteral";

// ============================================
// UPDATE.HTML (sin template vars)
// ============================================
const char PAGE_UPDATE_HTML[] PROGMEM = R"rawliteral(<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
    <title>ESP32 - Actualizar Firmware</title>
    <link rel="stylesheet" href="/style.css">
</head>
<body>
    <div class="header">
        <div class="logo">&#x1F4E6;</div>
        <div class="header-text">
            <h1>Actualizar Firmware</h1>
            <div class="subtitle">OTA - Over The Air</div>
        </div>
    </div>

    <!-- Info actual -->
    <div class="card">
        <div class="card-title">Firmware Actual</div>
        <div class="info-box" id="fwInfo">Cargando...</div>
    </div>

    <!-- Upload Manual -->
    <div class="card">
        <div class="card-title">Subir Firmware (.bin)</div>
        <form id="uploadForm">
            <div class="form-group">
                <label>Seleccionar archivo .bin</label>
                <input type="file" name="firmware" id="firmwareFile" accept=".bin" required
                    style="padding:10px;border:2px dashed rgba(255,255,255,0.3);border-radius:8px;width:100%;box-sizing:border-box;background:rgba(0,0,0,0.2);color:#fff">
            </div>
            <div id="fileInfo" style="font-size:0.8em;color:#90caf9;margin-bottom:10px"></div>

            <!-- Barra de progreso -->
            <div id="progressContainer" style="display:none">
                <div class="progress-bar">
                    <div class="progress-fill" id="progressFill"></div>
                </div>
                <div id="progressText" style="text-align:center;font-size:0.85em;margin:8px 0">0%</div>
            </div>

            <div id="alertBox" style="display:none;background:rgba(255,152,0,0.3);border:1px solid #ff9800;padding:10px;border-radius:5px;margin:10px 0;font-size:0.85em">
                No desconecte el dispositivo durante la actualizacion.
            </div>

            <button type="submit" class="btn btn-warning btn-block" id="btnUpload">
                Actualizar Firmware
            </button>
        </form>
    </div>

    <!-- Verificar actualizacion remota -->
    <div class="card">
        <div class="card-title">Verificacion Remota</div>
        <p style="font-size:0.85em;opacity:0.8;margin-bottom:10px">
            Consulta al servidor si hay una nueva version disponible.
        </p>
        <button onclick="checkRemoto()" class="btn btn-info btn-block" id="btnCheck">
            Verificar Ahora
        </button>
        <div id="checkResult" style="margin-top:10px;font-size:0.85em"></div>
        <div id="updateAction" style="display:none;margin-top:10px">
            <div style="background:rgba(76,175,80,0.3);border:1px solid #4caf50;padding:12px;border-radius:5px;margin-bottom:10px">
                <strong id="updateVersionText"></strong>
                <p style="font-size:0.8em;margin:5px 0 0 0;opacity:0.9">El dispositivo se reiniciara automaticamente al terminar.</p>
            </div>
            <button onclick="instalarUpdate()" class="btn btn-warning btn-block" id="btnInstall">
                Descargar e Instalar
            </button>
        </div>
    </div>

    <div class="nav-links">
        <a href="/">Inicio</a>
        <a href="/api">Configuracion</a>
        <a href="/log">Logs</a>
    </div>

    <script>
        // Cargar info del firmware
        fetch('/info')
            .then(function(r) { return r.json(); })
            .then(function(data) {
                document.getElementById('fwInfo').innerHTML =
                    'Version: <strong>' + data.version + '</strong><br>' +
                    'Tipo: <strong>' + data.tipo + '</strong><br>' +
                    'Serial: ' + data.serial + '<br>' +
                    'MAC: ' + data.mac + '<br>' +
                    'IP: ' + data.ip + '<br>' +
                    'Habitacion: ' + data.habitacion_id;
            })
            .catch(function(e) {
                document.getElementById('fwInfo').textContent = 'Error cargando info';
            });

        // Mostrar tamano del archivo
        document.getElementById('firmwareFile').addEventListener('change', function(e) {
            var file = e.target.files[0];
            if (file) {
                var kb = (file.size / 1024).toFixed(1);
                document.getElementById('fileInfo').textContent =
                    'Archivo: ' + file.name + ' (' + kb + ' KB)';
            }
        });

        // Upload firmware
        document.getElementById('uploadForm').addEventListener('submit', function(e) {
            e.preventDefault();
            var fileInput = document.getElementById('firmwareFile');
            if (!fileInput.files[0]) return;

            if (!confirm('Actualizar firmware? El dispositivo se reiniciara.')) return;

            var formData = new FormData();
            formData.append('firmware', fileInput.files[0]);

            var btn = document.getElementById('btnUpload');
            btn.disabled = true;
            btn.innerHTML = '<span class="loading"></span> Subiendo...';

            document.getElementById('progressContainer').style.display = 'block';
            document.getElementById('alertBox').style.display = 'block';

            var xhr = new XMLHttpRequest();
            xhr.open('POST', '/doUpdate', true);

            xhr.upload.onprogress = function(e) {
                if (e.lengthComputable) {
                    var pct = Math.round((e.loaded / e.total) * 100);
                    document.getElementById('progressFill').style.width = pct + '%';
                    document.getElementById('progressText').textContent = pct + '% (' +
                        Math.round(e.loaded / 1024) + '/' + Math.round(e.total / 1024) + ' KB)';
                }
            };

            xhr.onload = function() {
                try {
                    var resp = JSON.parse(xhr.responseText);
                    if (resp.success) {
                        document.getElementById('progressText').textContent = 'Actualizado! Reiniciando...';
                        document.getElementById('progressFill').style.background = '#4caf50';
                        btn.innerHTML = 'Reiniciando...';
                        setTimeout(function() { location.reload(); }, 10000);
                    } else {
                        document.getElementById('progressText').textContent = 'Error: ' + resp.message;
                        document.getElementById('progressFill').style.background = '#f44336';
                        btn.disabled = false;
                        btn.innerHTML = 'Actualizar Firmware';
                    }
                } catch(e) {
                    document.getElementById('progressText').textContent = 'Respuesta inesperada';
                    btn.disabled = false;
                    btn.innerHTML = 'Actualizar Firmware';
                }
            };

            xhr.onerror = function() {
                document.getElementById('progressText').textContent = 'Error de conexion';
                document.getElementById('progressFill').style.background = '#f44336';
                btn.disabled = false;
                btn.innerHTML = 'Actualizar Firmware';
            };

            xhr.send(formData);
        });

        // Verificar remoto con polling de resultado
        var checkInterval = null;

        function checkRemoto() {
            var btn = document.getElementById('btnCheck');
            btn.disabled = true;
            btn.innerHTML = '<span class="loading"></span> Verificando...';
            document.getElementById('checkResult').textContent = '';
            document.getElementById('updateAction').style.display = 'none';

            fetch('/ota-check', { method: 'POST' })
                .then(function(r) { return r.text(); })
                .then(function() {
                    // Polling cada 1.5s para obtener resultado
                    checkInterval = setInterval(pollStatus, 1500);
                })
                .catch(function(e) {
                    showCheckResult('error', 'Error de conexion: ' + e);
                    btn.disabled = false;
                    btn.innerHTML = 'Verificar Ahora';
                });
        }

        function pollStatus() {
            fetch('/ota-status')
                .then(function(r) { return r.json(); })
                .then(function(data) {
                    // status: 0=idle, 1=verificando, 2=update disponible, 3=al dia, 4=error
                    if (data.status === 1) return; // todavia verificando

                    clearInterval(checkInterval);
                    var btn = document.getElementById('btnCheck');
                    btn.disabled = false;
                    btn.innerHTML = 'Verificar Ahora';

                    if (data.status === 2) {
                        // Update disponible
                        showCheckResult('success', 'Nueva version ' + data.version + ' disponible (actual: ' + data.current + ')');
                        document.getElementById('updateVersionText').textContent =
                            'Version ' + data.version + ' lista para instalar';
                        document.getElementById('updateAction').style.display = 'block';
                    } else if (data.status === 3) {
                        showCheckResult('info', 'Firmware al dia (v' + data.current + ')');
                    } else {
                        showCheckResult('error', data.message || 'Error desconocido');
                    }
                })
                .catch(function() {
                    clearInterval(checkInterval);
                    showCheckResult('error', 'Error consultando estado');
                    var btn = document.getElementById('btnCheck');
                    btn.disabled = false;
                    btn.innerHTML = 'Verificar Ahora';
                });
        }

        function showCheckResult(type, msg) {
            var el = document.getElementById('checkResult');
            var colors = {
                success: 'rgba(76,175,80,0.3);border:1px solid #4caf50',
                info: 'rgba(33,150,243,0.3);border:1px solid #2196f3',
                error: 'rgba(244,67,54,0.3);border:1px solid #f44336'
            };
            el.innerHTML = '<div style="background:' + (colors[type] || colors.info) +
                ';padding:8px;border-radius:5px">' + msg + '</div>';
        }

        // Instalar update remoto
        function instalarUpdate() {
            if (!confirm('Descargar e instalar nueva version? El dispositivo se reiniciara.')) return;

            var btn = document.getElementById('btnInstall');
            btn.disabled = true;
            btn.innerHTML = '<span class="loading"></span> Descargando...';

            fetch('/ota-download', { method: 'POST' })
                .then(function(r) {
                    if (r.ok) {
                        showCheckResult('success', 'Descargando firmware... El dispositivo se reiniciara automaticamente.');
                        btn.innerHTML = 'Instalando...';
                        // Esperar y recargar pagina
                        setTimeout(function() { location.reload(); }, 30000);
                    } else {
                        return r.text().then(function(t) { throw new Error(t); });
                    }
                })
                .catch(function(e) {
                    showCheckResult('error', 'Error: ' + e.message);
                    btn.disabled = false;
                    btn.innerHTML = 'Descargar e Instalar';
                });
        }
    </script>
</body>
</html>
)rawliteral";

// ============================================
// LOG.HTML (sin template vars)
// ============================================
const char PAGE_LOG_HTML[] PROGMEM = R"rawliteral(<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Logs - ESP32</title>
    <link rel="stylesheet" href="/style.css">
</head>
<body>
    <div class="header">
        <div class="logo">&#x1F4CB;</div>
        <div class="header-text">
            <h1>Logs del Sistema</h1>
            <div class="subtitle">Registro de actividad</div>
        </div>
    </div>

    <div class="card">
        <div style="display:flex;gap:8px;margin-bottom:12px;flex-wrap:wrap">
            <button onclick="refreshLogs()" class="btn btn-primary">Actualizar</button>
            <button onclick="toggleAutoRefresh()" class="btn btn-info" id="autoBtn">Auto: OFF</button>
            <a href="/" class="btn btn-secondary">Volver</a>
        </div>
        <div id="logContent" style="background:rgba(0,0,0,0.3);border-radius:6px;padding:10px;font-family:'Consolas',monospace;font-size:11px;height:400px;overflow-y:auto;white-space:pre-wrap;word-break:break-all;color:#b0bec5;line-height:1.4">
            Cargando...
        </div>
    </div>

    <div class="nav-links">
        <a href="/">Inicio</a>
        <a href="/api">Configuracion</a>
    </div>

    <script>
        var autoInterval = null;

        function refreshLogs() {
            fetch('/get-log')
                .then(function(r) { return r.text(); })
                .then(function(data) {
                    var el = document.getElementById('logContent');
                    el.textContent = data || 'Sin logs';
                    el.scrollTop = el.scrollHeight;
                })
                .catch(function(e) {
                    document.getElementById('logContent').textContent = 'Error: ' + e;
                });
        }

        function toggleAutoRefresh() {
            var btn = document.getElementById('autoBtn');
            if (autoInterval) {
                clearInterval(autoInterval);
                autoInterval = null;
                btn.textContent = 'Auto: OFF';
                btn.className = 'btn btn-info';
            } else {
                autoInterval = setInterval(refreshLogs, 2000);
                btn.textContent = 'Auto: ON';
                btn.className = 'btn btn-success';
            }
        }

        refreshLogs();
    </script>
</body>
</html>
)rawliteral";

#endif
