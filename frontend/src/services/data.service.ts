import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Observable, interval, Subject, takeUntil, switchMap, retry, catchError, throwError, shareReplay } from 'rxjs';
import { environment } from '../environments/environment';

export interface ApiResponse<T = any> {
  error: boolean;
  status: number;
  body: T;
}

export interface Habitacion {
  id: number;
  nombre: string;
  camas: Cama[];
}

export interface Cama {
  id: number;
  nombre: string;
  paciente: string;
  nota?: string;
  fecha_nota?: string;
  // Campos de Fase 0/1
  nroDocIdePac?: string;
  origen_cambio?: string;
  confirmado_por_essi?: boolean;
  fecha_cambio_manual?: string | null;
  fecha_alta_programada?: string | null;
  marcado_para_eliminar?: boolean;
  usuario_cambio_id?: number | null;
}

export interface AuditoriaItem {
  id: number;
  fecha_evento: string;
  accion: string;
  codhabcama: string | null;
  codhab: string | null;
  codcama: string | null;
  paciente: string | null;
  nrodocidepac: string | null;
  detalle: string | null;
  usuario_id: number | null;
  usuario_nombre: string | null;
  usuario_login: string | null;
  area_id: number | null;
}

export interface AuditoriaPagina {
  total: number;
  limit: number;
  offset: number;
  registros: AuditoriaItem[];
}

export interface PacienteCatalogo {
  id: number;
  nro_doc_ide_pac: string;
  tipo_doc_ide_pac: string;
  ape_nom_pac: string;
  nro_his_cli_cas: string | null;
  fecha_registro?: string;
  fecha_modificacion?: string;
}

export interface IngresoManualPayload {
  id_cama: number;
  nro_doc_ide_pac: string;
  tipo_doc_ide_pac?: string;
  ape_nom_pac: string;
  nro_his_cli_cas?: string;
  des_ser_cama?: string;
  fecha_salida_obligatoria: string; // ISO
  pertenece_al_area: boolean;
  motivo?: string;
}

export interface HabitacionesResponse {
  habitaciones: Habitacion[];
  ultimaSincronizacion: string;
}

export interface Efemeride {
  id: number;
  titulo: string;
  descripcion?: string;
  dia: number;
  mes: number;
  tipo: string;
  icono?: string;
  estado?: boolean;
}

export interface Cumpleano {
  id: number;
  nombre: string;
  cargo?: string;
  dia: number;
  mes: number;
  area_id?: number;
}

export interface Aviso {
  id: number;
  titulo: string;
  mensaje: string;
  prioridad: 'normal' | 'importante' | 'muy_importante';
  modo_display?: 'permanente' | 'periodico';
  area_id?: number;
  creado_por?: number;
  nombre_creador?: string;
  fecha_inicio?: string;
  fecha_fin?: string;
}

export interface ConfigTv {
  intervalo_efemerides: string;
  intervalo_cumpleanos: string;
  intervalo_avisos: string;
  duracion_overlay: string;
  tamano_fuente_tv: string;
  audio_habilitado: string;
  audio_volumen: string;
  audio_duracion_alerta: string;
  audio_duracion_emergencia: string;
  audio_sonido_alerta: string;
  audio_sonido_emergencia: string;
  [key: string]: string;
}

export interface ContenidoTv {
  efemerides: Efemeride[];
  cumpleanos: Cumpleano[];
  avisos: Aviso[];
  config: ConfigTv;
}

export interface ConfiguracionSistemaItem {
  clave: string;
  valor: string;
  descripcion?: string;
  tipo: 'INT' | 'DECIMAL' | 'BOOLEAN' | 'STRING';
  valor_min?: string | null;
  valor_max?: string | null;
  fecha_modificacion?: string;
  usuario_modifico_id?: number | null;
}

@Injectable({
  providedIn: 'root'
})
export class DataService {
  private apiUrl = environment.apiUrl;

  constructor(private http: HttpClient) {}

  /**
   * Consultar habitaciones EsSi (llamada única)
   */
  consultarHabitacionesEsSi(codHabCama: string): Observable<ApiResponse<HabitacionesResponse>> {
    return this.http.post<ApiResponse<HabitacionesResponse>>(
      `${this.apiUrl}/informacion/consultarHabitacionesEsSi`,
      { codHabCama }
    ).pipe(
      retry({ count: 2, delay: 1000 }),
      catchError(this.handleError)
    );
  }

  /**
   * Consultar habitaciones con polling automático
   * @param codHabCama Código de habitación/cama
   * @param destroy$ Subject para cancelar el polling
   * @param intervalMs Intervalo en milisegundos (default 3000)
   */
  consultarHabitacionesPolling(
    codHabCama: string,
    destroy$: Subject<void>,
    intervalMs = 3000
  ): Observable<ApiResponse<HabitacionesResponse>> {
    return interval(intervalMs).pipe(
      takeUntil(destroy$),
      switchMap(() => this.consultarHabitacionesEsSi(codHabCama)),
      shareReplay(1)
    );
  }

  /**
   * Consultar alertas (llamada única)
   */
  consultarAlertas(areaId: number): Observable<ApiResponse<any>> {
    return this.http.post<ApiResponse<any>>(
      `${this.apiUrl}/informacion/consultarAlertas`,
      { area_id: areaId }
    ).pipe(
      retry({ count: 2, delay: 1000 }),
      catchError(this.handleError)
    );
  }

  /**
   * Consultar alertas con polling automático
   * @param areaId ID del área
   * @param destroy$ Subject para cancelar el polling
   * @param intervalMs Intervalo en milisegundos (default 3000)
   */
  consultarAlertasPolling(
    areaId: number,
    destroy$: Subject<void>,
    intervalMs = 3000
  ): Observable<ApiResponse<any>> {
    return interval(intervalMs).pipe(
      takeUntil(destroy$),
      switchMap(() => this.consultarAlertas(areaId)),
      shareReplay(1)
    );
  }

  /**
   * Editar nota de una cama
   */
  editarNota(id: number, nota: string, fechaNota: string): Observable<ApiResponse<any>> {
    return this.http.post<ApiResponse<any>>(
      `${this.apiUrl}/informacion/editarNota`,
      { id, nota, fecha_nota: fechaNota }
    ).pipe(
      catchError(this.handleError)
    );
  }

  /**
   * Consultar habitaciones del usuario (sistema interno)
   */
  consultarHabitaciones(userId: number): Observable<ApiResponse<Habitacion[]>> {
    return this.http.post<ApiResponse<Habitacion[]>>(
      `${this.apiUrl}/informacion/consultarHabitaciones`,
      { id: userId }
    ).pipe(
      retry({ count: 2, delay: 1000 }),
      catchError(this.handleError)
    );
  }

  /**
   * Reconocer alertas de una habitacion
   */
  reconocerAlerta(habitacionId: number): Observable<ApiResponse<any>> {
    return this.http.post<ApiResponse<any>>(
      `${this.apiUrl}/informacion/reconocerAlerta`,
      { habitacion_id: habitacionId }
    ).pipe(
      catchError(this.handleError)
    );
  }

  /**
   * Analytics: Tiempos de respuesta
   */
  analyticsTiemposRespuesta(areaId: number, fechaInicio: string, fechaFin: string): Observable<ApiResponse<any>> {
    return this.http.post<ApiResponse<any>>(
      `${this.apiUrl}/analytics/tiemposRespuesta`,
      { area_id: areaId, fecha_inicio: fechaInicio, fecha_fin: fechaFin }
    ).pipe(
      catchError(this.handleError)
    );
  }

  /**
   * Analytics: Historial de notas
   */
  analyticsHistorialNotas(areaId: number, fechaInicio: string, fechaFin: string): Observable<ApiResponse<any>> {
    return this.http.post<ApiResponse<any>>(
      `${this.apiUrl}/analytics/historialNotas`,
      { area_id: areaId, fecha_inicio: fechaInicio, fecha_fin: fechaFin }
    ).pipe(
      catchError(this.handleError)
    );
  }

  /**
   * Analytics: Ocupacion de camas
   */
  analyticsOcupacion(areaId: number, fechaInicio: string, fechaFin: string): Observable<ApiResponse<any>> {
    return this.http.post<ApiResponse<any>>(
      `${this.apiUrl}/analytics/ocupacion`,
      { area_id: areaId, fecha_inicio: fechaInicio, fecha_fin: fechaFin }
    ).pipe(
      catchError(this.handleError)
    );
  }

  /**
   * Analytics: Frecuencia de alertas
   */
  analyticsFrecuenciaAlertas(areaId: number, fechaInicio: string, fechaFin: string): Observable<ApiResponse<any>> {
    return this.http.post<ApiResponse<any>>(
      `${this.apiUrl}/analytics/frecuenciaAlertas`,
      { area_id: areaId, fecha_inicio: fechaInicio, fecha_fin: fechaFin }
    ).pipe(
      catchError(this.handleError)
    );
  }

  /**
   * Listar dispositivos ESP32 con estado online
   */
  listarDispositivos(): Observable<ApiResponse<any>> {
    return this.http.get<ApiResponse<any>>(
      `${this.apiUrl}/dispositivos/listar`
    ).pipe(
      retry({ count: 2, delay: 1000 }),
      catchError(this.handleError)
    );
  }

  /**
   * Listar dispositivos con polling automatico
   */
  listarDispositivosPolling(
    destroy$: Subject<void>,
    intervalMs = 30000
  ): Observable<ApiResponse<any>> {
    return interval(intervalMs).pipe(
      takeUntil(destroy$),
      switchMap(() => this.listarDispositivos()),
      shareReplay(1)
    );
  }

  /**
   * Estadisticas de dispositivos en rango de fechas
   */
  estadisticasDispositivos(fechaInicio: string, fechaFin: string): Observable<ApiResponse<any>> {
    return this.http.get<ApiResponse<any>>(
      `${this.apiUrl}/dispositivos/estadisticas`,
      { params: { fecha_inicio: fechaInicio, fecha_fin: fechaFin } }
    ).pipe(
      retry({ count: 2, delay: 1000 }),
      catchError(this.handleError)
    );
  }

  /**
   * Eventos de un dispositivo especifico
   */
  eventosDispositivo(serial: string, fechaInicio: string, fechaFin: string): Observable<ApiResponse<any>> {
    return this.http.get<ApiResponse<any>>(
      `${this.apiUrl}/dispositivos/eventos/${serial}`,
      { params: { fecha_inicio: fechaInicio, fecha_fin: fechaFin } }
    ).pipe(
      retry({ count: 2, delay: 1000 }),
      catchError(this.handleError)
    );
  }

  // ============================================
  // CONTROLES RF
  // ============================================

  /**
   * Listar controles RF configurados
   */
  listarControlesRf(): Observable<ApiResponse<any>> {
    return this.http.get<ApiResponse<any>>(
      `${this.apiUrl}/dispositivos/controles-rf`
    ).pipe(
      retry({ count: 2, delay: 1000 }),
      catchError(this.handleError)
    );
  }

  /**
   * Agregar o editar control RF
   */
  agregarControlRf(data: any): Observable<ApiResponse<any>> {
    return this.http.post<ApiResponse<any>>(
      `${this.apiUrl}/dispositivos/controles-rf`, data
    ).pipe(
      catchError(this.handleError)
    );
  }

  /**
   * Eliminar control RF
   */
  eliminarControlRf(id: number): Observable<ApiResponse<any>> {
    return this.http.delete<ApiResponse<any>>(
      `${this.apiUrl}/dispositivos/controles-rf/${id}`
    ).pipe(
      catchError(this.handleError)
    );
  }

  // ============================================
  // PURGA DE DATOS
  // ============================================

  /**
   * Purgar eventos de conexion/desconexion de dispositivos
   */
  purgarEventosDispositivos(): Observable<ApiResponse<any>> {
    return this.http.delete<ApiResponse<any>>(
      `${this.apiUrl}/dispositivos/purgar-eventos`
    ).pipe(
      catchError(this.handleError)
    );
  }

  /**
   * Purgar todos los dispositivos ESP32 y sus eventos
   */
  purgarDispositivosEsp32(): Observable<ApiResponse<any>> {
    return this.http.delete<ApiResponse<any>>(
      `${this.apiUrl}/dispositivos/purgar-dispositivos`
    ).pipe(
      catchError(this.handleError)
    );
  }

  /**
   * Eliminar un dispositivo ESP32 individual
   */
  eliminarDispositivo(id: number): Observable<ApiResponse<any>> {
    return this.http.delete<ApiResponse<any>>(
      `${this.apiUrl}/dispositivos/${id}`
    ).pipe(
      catchError(this.handleError)
    );
  }

  /**
   * Purgar datos de analytics del area
   */
  purgarAnalytics(): Observable<ApiResponse<any>> {
    return this.http.delete<ApiResponse<any>>(
      `${this.apiUrl}/analytics/purgar`
    ).pipe(
      catchError(this.handleError)
    );
  }

  // ============================================
  // CONTENIDO TV
  // ============================================

  /**
   * Obtener contenido del día para TV (efemérides + cumpleaños + avisos)
   */
  obtenerContenidoTvHoy(areaId: number): Observable<ApiResponse<ContenidoTv>> {
    return this.http.post<ApiResponse<ContenidoTv>>(
      `${this.apiUrl}/contenido-tv/hoy`,
      { area_id: areaId }
    ).pipe(
      retry({ count: 2, delay: 1000 }),
      catchError(this.handleError)
    );
  }

  /**
   * Listar todas las efemérides
   */
  listarEfemerides(): Observable<ApiResponse<Efemeride[]>> {
    return this.http.get<ApiResponse<Efemeride[]>>(
      `${this.apiUrl}/contenido-tv/efemerides`
    ).pipe(
      retry({ count: 2, delay: 1000 }),
      catchError(this.handleError)
    );
  }

  /**
   * Guardar efeméride (crear o editar)
   */
  guardarEfemeride(data: any): Observable<ApiResponse<any>> {
    return this.http.post<ApiResponse<any>>(
      `${this.apiUrl}/contenido-tv/efemerides`,
      data
    ).pipe(
      catchError(this.handleError)
    );
  }

  /**
   * Eliminar efeméride
   */
  eliminarEfemeride(id: number): Observable<ApiResponse<any>> {
    return this.http.delete<ApiResponse<any>>(
      `${this.apiUrl}/contenido-tv/efemerides/${id}`
    ).pipe(
      catchError(this.handleError)
    );
  }

  /**
   * Listar cumpleaños del área
   */
  listarCumpleanos(): Observable<ApiResponse<Cumpleano[]>> {
    return this.http.get<ApiResponse<Cumpleano[]>>(
      `${this.apiUrl}/contenido-tv/cumpleanos`
    ).pipe(
      retry({ count: 2, delay: 1000 }),
      catchError(this.handleError)
    );
  }

  /**
   * Guardar cumpleaños (crear o editar)
   */
  guardarCumpleano(data: any): Observable<ApiResponse<any>> {
    return this.http.post<ApiResponse<any>>(
      `${this.apiUrl}/contenido-tv/cumpleanos`,
      data
    ).pipe(
      catchError(this.handleError)
    );
  }

  /**
   * Eliminar cumpleaños
   */
  eliminarCumpleano(id: number): Observable<ApiResponse<any>> {
    return this.http.delete<ApiResponse<any>>(
      `${this.apiUrl}/contenido-tv/cumpleanos/${id}`
    ).pipe(
      catchError(this.handleError)
    );
  }

  /**
   * Listar avisos activos del área
   */
  listarAvisos(): Observable<ApiResponse<Aviso[]>> {
    return this.http.get<ApiResponse<Aviso[]>>(
      `${this.apiUrl}/contenido-tv/avisos`
    ).pipe(
      retry({ count: 2, delay: 1000 }),
      catchError(this.handleError)
    );
  }

  /**
   * Guardar aviso (crear o editar)
   */
  guardarAviso(data: any): Observable<ApiResponse<any>> {
    return this.http.post<ApiResponse<any>>(
      `${this.apiUrl}/contenido-tv/avisos`,
      data
    ).pipe(
      catchError(this.handleError)
    );
  }

  /**
   * Eliminar aviso
   */
  eliminarAviso(id: number): Observable<ApiResponse<any>> {
    return this.http.delete<ApiResponse<any>>(
      `${this.apiUrl}/contenido-tv/avisos/${id}`
    ).pipe(
      catchError(this.handleError)
    );
  }

  /**
   * Obtener configuración TV
   */
  obtenerConfigTv(): Observable<ApiResponse<ConfigTv>> {
    return this.http.get<ApiResponse<ConfigTv>>(
      `${this.apiUrl}/contenido-tv/config`
    ).pipe(
      retry({ count: 2, delay: 1000 }),
      catchError(this.handleError)
    );
  }

  /**
   * Actualizar configuración TV
   */
  actualizarConfigTv(clave: string, valor: string): Observable<ApiResponse<any>> {
    return this.http.post<ApiResponse<any>>(
      `${this.apiUrl}/contenido-tv/config`,
      { clave, valor }
    ).pipe(
      catchError(this.handleError)
    );
  }

  // ============================================
  // CONFIGURACION DEL SISTEMA (Fase 0)
  // ============================================

  /**
   * Listar todas las claves de configuracion del sistema (sync, ventanas de gracia, etc.)
   */
  listarConfiguracionSistema(): Observable<ApiResponse<ConfiguracionSistemaItem[]>> {
    return this.http.get<ApiResponse<ConfiguracionSistemaItem[]>>(
      `${this.apiUrl}/configuracion`
    ).pipe(
      retry({ count: 2, delay: 1000 }),
      catchError(this.handleError)
    );
  }

  /**
   * Actualizar una clave de configuracion del sistema. Solo admin.
   */
  actualizarConfiguracionSistema(clave: string, valor: string): Observable<ApiResponse<any>> {
    return this.http.put<ApiResponse<any>>(
      `${this.apiUrl}/configuracion/${encodeURIComponent(clave)}`,
      { valor }
    ).pipe(
      catchError(this.handleError)
    );
  }

  // ============================================
  // GESTION MANUAL DE CAMAS (Fase 1)
  // ============================================

  /**
   * Mover o intercambiar paciente entre camas de la misma sub-area.
   * Si la cama destino esta libre -> mover. Si esta ocupada -> intercambio.
   */
  cambiarCamaPaciente(id_origen: number, id_destino: number, motivo?: string): Observable<ApiResponse<any>> {
    return this.http.post<ApiResponse<any>>(
      `${this.apiUrl}/informacion/cambiarCamaPaciente`,
      { id_origen, id_destino, motivo: motivo || null }
    ).pipe(
      catchError(this.handleError)
    );
  }

  /**
   * Cancelar un cambio manual pendiente (vuelve a confiar en EsSi).
   */
  cancelarCambioManual(id_cama: number): Observable<ApiResponse<any>> {
    return this.http.post<ApiResponse<any>>(
      `${this.apiUrl}/informacion/cancelarCambioManual`,
      { id_cama }
    ).pipe(
      catchError(this.handleError)
    );
  }

  // ============================================
  // INGRESO MANUAL DE PACIENTE (Fase 2)
  // ============================================

  /**
   * Busca un paciente por DNI en el catalogo `pacientes`.
   * El backend responde con codigo 404 + mensaje null si no existe (no es error).
   */
  buscarPacientePorDni(dni: string): Observable<ApiResponse<PacienteCatalogo | null>> {
    return this.http.get<ApiResponse<PacienteCatalogo | null>>(
      `${this.apiUrl}/informacion/buscarPacientePorDni/${encodeURIComponent(dni)}`
    ).pipe(
      catchError(this.handleError)
    );
  }

  /**
   * Ingresa un paciente manualmente en una cama libre.
   */
  ingresarPacienteManual(payload: IngresoManualPayload): Observable<ApiResponse<any>> {
    return this.http.post<ApiResponse<any>>(
      `${this.apiUrl}/informacion/ingresarPacienteManual`,
      payload
    ).pipe(
      catchError(this.handleError)
    );
  }

  // ============================================
  // AUDITORIA (Fase 1)
  // ============================================

  listarAuditoria(filtros: {
    desde?: string;
    hasta?: string;
    usuario_id?: number;
    accion?: string;
    area_id?: number;
    limit?: number;
    offset?: number;
  } = {}): Observable<ApiResponse<AuditoriaPagina>> {
    const params: Record<string, string> = {};
    if (filtros.desde) params['desde'] = filtros.desde;
    if (filtros.hasta) params['hasta'] = filtros.hasta;
    if (filtros.usuario_id) params['usuario_id'] = String(filtros.usuario_id);
    if (filtros.accion) params['accion'] = filtros.accion;
    if (filtros.area_id) params['area_id'] = String(filtros.area_id);
    if (filtros.limit !== undefined) params['limit'] = String(filtros.limit);
    if (filtros.offset !== undefined) params['offset'] = String(filtros.offset);

    return this.http.get<ApiResponse<AuditoriaPagina>>(
      `${this.apiUrl}/auditoria/cambios`,
      { params }
    ).pipe(
      retry({ count: 1, delay: 500 }),
      catchError(this.handleError)
    );
  }

  /**
   * Descarga el CSV de auditoria. Devuelve el Blob para usar con FileSaver.
   */
  descargarAuditoriaCsv(filtros: {
    desde?: string;
    hasta?: string;
    usuario_id?: number;
    accion?: string;
    area_id?: number;
  } = {}): Observable<Blob> {
    const params: Record<string, string> = {};
    if (filtros.desde) params['desde'] = filtros.desde;
    if (filtros.hasta) params['hasta'] = filtros.hasta;
    if (filtros.usuario_id) params['usuario_id'] = String(filtros.usuario_id);
    if (filtros.accion) params['accion'] = filtros.accion;
    if (filtros.area_id) params['area_id'] = String(filtros.area_id);

    return this.http.get(
      `${this.apiUrl}/auditoria/exportar.csv`,
      { params, responseType: 'blob' }
    ).pipe(
      catchError(this.handleError)
    );
  }

  // ============================================
  // ADMINISTRACIÓN DE USUARIOS
  // ============================================

  /**
   * Listar servicios hospitalarios con códigos EsSi
   */
  listarServiciosHospitalarios(): Observable<ApiResponse<any>> {
    return this.http.get<ApiResponse<any>>(
      `${this.apiUrl}/usuarios/servicios-hospitalarios`
    ).pipe(
      retry({ count: 2, delay: 1000 }),
      catchError(this.handleError)
    );
  }

  /**
   * Listar areas activas
   */
  listarAreas(): Observable<ApiResponse<any>> {
    return this.http.get<ApiResponse<any>>(
      `${this.apiUrl}/usuarios/areas`
    ).pipe(
      retry({ count: 2, delay: 1000 }),
      catchError(this.handleError)
    );
  }

  /**
   * Preview sub-areas (codHabCama) desde API externa EsSi
   */
  previewSubAreas(data: { oriCenAsiCod: string; cenAsiCod: string; areHosCod: string; servHosCod: string; estEnfCod: string }): Observable<ApiResponse<any>> {
    return this.http.post<ApiResponse<any>>(
      `${this.apiUrl}/usuarios/preview-sub-areas`,
      data
    ).pipe(
      catchError(this.handleError)
    );
  }

  /**
   * Listar todos los usuarios (solo admin)
   */
  listarUsuarios(): Observable<ApiResponse<any>> {
    return this.http.get<ApiResponse<any>>(
      `${this.apiUrl}/usuarios/listar`
    ).pipe(
      retry({ count: 2, delay: 1000 }),
      catchError(this.handleError)
    );
  }

  /**
   * Crear o buscar area hospitalaria
   */
  crearArea(data: { nombre: string; codigo_essi: any }): Observable<ApiResponse<any>> {
    return this.http.post<ApiResponse<any>>(
      `${this.apiUrl}/usuarios/crear-area`,
      data
    ).pipe(
      catchError(this.handleError)
    );
  }

  /**
   * Registrar nuevo usuario
   */
  registrarUsuario(data: { id?: number; nombre: string; usuario: string; clave: string; estado?: boolean }): Observable<ApiResponse<any>> {
    return this.http.post<ApiResponse<any>>(
      `${this.apiUrl}/usuarios/registrar`,
      data
    ).pipe(
      catchError(this.handleError)
    );
  }

  /**
   * Asignar usuario a área con rol
   */
  asignarUsuario(data: { id?: number; usuario_id: number; area_id?: number; area_nombre?: string; rol: string; estado?: boolean; permisos?: any }): Observable<ApiResponse<any>> {
    return this.http.post<ApiResponse<any>>(
      `${this.apiUrl}/usuarios/asignar`,
      data
    ).pipe(
      catchError(this.handleError)
    );
  }

  /**
   * Eliminar usuario
   */
  eliminarUsuario(id: number): Observable<ApiResponse<any>> {
    return this.http.put<ApiResponse<any>>(
      `${this.apiUrl}/usuarios/eliminar`,
      { id }
    ).pipe(
      catchError(this.handleError)
    );
  }

  /**
   * Cambiar clave de un usuario (admin)
   */
  cambiarClave(id: number, clave: string): Observable<ApiResponse<any>> {
    return this.http.put<ApiResponse<any>>(
      `${this.apiUrl}/usuarios/cambiar-clave`,
      { id, clave }
    ).pipe(
      catchError(this.handleError)
    );
  }

  /**
   * Cambiar mi propia clave
   */
  cambiarMiClave(clave_actual: string, clave_nueva: string): Observable<ApiResponse<any>> {
    return this.http.put<ApiResponse<any>>(
      `${this.apiUrl}/usuarios/cambiar-mi-clave`,
      { clave_actual, clave_nueva }
    ).pipe(
      catchError(this.handleError)
    );
  }

  // ============================================
  // OTA / FIRMWARE
  // ============================================

  /**
   * Listar firmwares disponibles en el servidor
   */
  listarFirmwares(): Observable<ApiResponse<any>> {
    return this.http.get<ApiResponse<any>>(
      `${this.apiUrl}/ota/list`
    ).pipe(
      retry({ count: 2, delay: 1000 }),
      catchError(this.handleError)
    );
  }

  /**
   * Subir un archivo de firmware .bin
   */
  subirFirmware(file: File, version: string, descripcion: string): Observable<ApiResponse<any>> {
    const formData = new FormData();
    formData.append('firmware', file);
    formData.append('version', version);
    formData.append('descripcion', descripcion);
    return this.http.post<ApiResponse<any>>(
      `${this.apiUrl}/ota/upload`,
      formData
    ).pipe(
      catchError(this.handleError)
    );
  }

  /**
   * URL directa para descargar un firmware .bin (sin auth, lo usa tambien el ESP32)
   */
  getUrlDescargaFirmware(filename: string): string {
    return `${this.apiUrl}/ota/firmware/${encodeURIComponent(filename)}`;
  }

  /**
   * Eliminar un firmware del servidor
   */
  eliminarFirmware(filename: string): Observable<ApiResponse<any>> {
    return this.http.delete<ApiResponse<any>>(
      `${this.apiUrl}/ota/firmware/${encodeURIComponent(filename)}`
    ).pipe(
      catchError(this.handleError)
    );
  }

  // ============================================
  // AUDIO CONFIG
  // ============================================

  /**
   * Listar sonidos disponibles (preset + custom)
   */
  listarSonidos(): Observable<ApiResponse<{ preset: string[]; custom: string[] }>> {
    return this.http.get<ApiResponse<{ preset: string[]; custom: string[] }>>(
      `${this.apiUrl}/audio-config/sonidos`
    ).pipe(
      catchError(this.handleError)
    );
  }

  /**
   * Subir un archivo de sonido personalizado
   */
  subirSonido(file: File): Observable<ApiResponse<{ filename: string; originalname: string; size: number }>> {
    const formData = new FormData();
    formData.append('audio', file);
    return this.http.post<ApiResponse<{ filename: string; originalname: string; size: number }>>(
      `${this.apiUrl}/audio-config/upload`,
      formData
    ).pipe(
      catchError(this.handleError)
    );
  }

  /**
   * Eliminar un sonido personalizado
   */
  eliminarSonido(filename: string): Observable<ApiResponse<any>> {
    return this.http.delete<ApiResponse<any>>(
      `${this.apiUrl}/audio-config/sonidos/${encodeURIComponent(filename)}`
    ).pipe(
      catchError(this.handleError)
    );
  }

  // ============================================
  // PANTALLAS TV (admin CRUD)
  // ============================================

  listarPantallasTv(): Observable<ApiResponse<any>> {
    return this.http.get<ApiResponse<any>>(
      `${this.apiUrl}/contenido-tv/pantallas`
    ).pipe(
      retry({ count: 2, delay: 1000 }),
      catchError(this.handleError)
    );
  }

  guardarPantallaTv(data: any): Observable<ApiResponse<any>> {
    return this.http.post<ApiResponse<any>>(
      `${this.apiUrl}/contenido-tv/pantallas`,
      data
    ).pipe(
      catchError(this.handleError)
    );
  }

  eliminarPantallaTv(id: number): Observable<ApiResponse<any>> {
    return this.http.delete<ApiResponse<any>>(
      `${this.apiUrl}/contenido-tv/pantallas/${id}`
    ).pipe(
      catchError(this.handleError)
    );
  }

  // ============================================
  // TV PÚBLICA (sin autenticación)
  // ============================================

  obtenerPantallaPublica(token: string): Observable<ApiResponse<any>> {
    return this.http.get<ApiResponse<any>>(
      `${this.apiUrl}/tv-publica/${token}`
    ).pipe(
      retry({ count: 2, delay: 1000 }),
      catchError(this.handleError)
    );
  }

  consultarHabitacionesPublica(token: string): Observable<ApiResponse<HabitacionesResponse>> {
    return this.http.get<ApiResponse<HabitacionesResponse>>(
      `${this.apiUrl}/tv-publica/${token}/habitaciones`
    ).pipe(
      retry({ count: 2, delay: 1000 }),
      catchError(this.handleError)
    );
  }

  consultarAlertasPublica(token: string): Observable<ApiResponse<any>> {
    return this.http.get<ApiResponse<any>>(
      `${this.apiUrl}/tv-publica/${token}/alertas`
    ).pipe(
      retry({ count: 2, delay: 1000 }),
      catchError(this.handleError)
    );
  }

  obtenerContenidoTvPublica(token: string): Observable<ApiResponse<ContenidoTv>> {
    return this.http.get<ApiResponse<ContenidoTv>>(
      `${this.apiUrl}/tv-publica/${token}/contenido`
    ).pipe(
      retry({ count: 2, delay: 1000 }),
      catchError(this.handleError)
    );
  }

  obtenerConfigTvPublica(token: string): Observable<ApiResponse<ConfigTv>> {
    return this.http.get<ApiResponse<ConfigTv>>(
      `${this.apiUrl}/tv-publica/${token}/config`
    ).pipe(
      retry({ count: 2, delay: 1000 }),
      catchError(this.handleError)
    );
  }

  /**
   * Manejador de errores centralizado
   */
  private handleError(error: any): Observable<never> {
    let errorMessage = 'Error desconocido';

    if (error.error instanceof ErrorEvent) {
      // Error del lado del cliente
      errorMessage = `Error: ${error.error.message}`;
    } else {
      // Error del lado del servidor
      errorMessage = `Error ${error.status}: ${error.message}`;
    }

    console.error('DataService Error:', errorMessage);
    return throwError(() => new Error(errorMessage));
  }
}
