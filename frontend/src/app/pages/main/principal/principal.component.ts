import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { Subject, takeUntil, interval, switchMap, retry, catchError, of } from 'rxjs';
import { MatDialog } from '@angular/material/dialog';
import { ToastrService } from 'ngx-toastr';
import moment from 'moment-timezone';

import { AuthService } from '../../../../services/auth.service';
import { DataService, Habitacion, Cama, Aviso } from '../../../../services/data.service';
import { AlertService, HabitacionAlerta } from '../../../core/services/alert.service';
import { AudioService } from '../../../core/services/audio.service';
import { TvContentService, TvContentItem } from '../../../core/services/tv-content.service';
import { TokenRefreshService } from '../../../core/services/token-refresh.service';
import { TvOverlayComponent } from '../../tv/tv-overlay/tv-overlay.component';
import { AddNotaComponent } from './add-nota/add-nota.component';
import { DialogCambiarCamaComponent, DialogCambiarCamaData } from './dialog-cambiar-cama/dialog-cambiar-cama.component';
import { DialogIngresarPacienteComponent, DialogIngresarPacienteData } from './dialog-ingresar-paciente/dialog-ingresar-paciente.component';
import { LoadingComponent } from '../../../shared/components/loading/loading.component';
import { ErrorMessageComponent } from '../../../shared/components/error-message/error-message.component';

@Component({
  selector: 'app-principal',
  standalone: true,
  imports: [CommonModule, LoadingComponent, ErrorMessageComponent, TvOverlayComponent],
  templateUrl: './principal.component.html',
  styleUrl: './principal.component.scss'
})
export class PrincipalComponent implements OnInit, OnDestroy {
  private destroy$ = new Subject<void>();
  private notificados: Set<string> = new Set();
  private refreshInterval = 30 * 60 * 1000; // 30 minutos

  // Estado del componente
  public lstHabitaciones: Habitacion[] = [];
  public lstAlerta: HabitacionAlerta[] = [];
  public loading = true;
  public error: string | null = null;
  public ultimaSincronizacion: string = '';
  public esJefeArea = false;

  // Contenido TV overlay
  public contenidoOverlay: TvContentItem | null = null;
  public avisosPermanentes: Aviso[] = [];
  public duracionOverlay = 15;

  // Usuario
  private usuario: any;

  constructor(
    public dialogo: MatDialog,
    private authService: AuthService,
    private dataService: DataService,
    private alertService: AlertService,
    private audioService: AudioService,
    private tvContentService: TvContentService,
    private router: Router,
    private toastr: ToastrService,
    private tokenRefreshService: TokenRefreshService
  ) {}

  ngOnInit(): void {
    // Validar sesión
    if (!this.authService.isAuthenticated()) {
      this.router.navigateByUrl('/login');
      return;
    }

    // Obtener datos del usuario
    this.usuario = this.authService.getUsuario();
    if (!this.usuario) {
      console.warn('Usuario no encontrado en sesión');
      this.router.navigateByUrl('/login');
      return;
    }
    this.esJefeArea = ['admin', 'jefe_area'].includes(this.usuario?.rol || '');

    // Cargar datos iniciales
    this.cargarDatos();

    // Iniciar polling de alertas
    this.iniciarPollingAlertas();

    // Iniciar verificación de notas
    this.iniciarVerificacionNotas();

    // Programar refresh de datos (cada 30 min) sin recargar página
    this.programarRefresh();

    // Iniciar contenido TV
    this.iniciarContenidoTv();

    // Iniciar monitoreo de renovación de token
    this.tokenRefreshService.startMonitoring();
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
    this.alertService.detenerPolling();
    this.audioService.detenerTodos();
    this.tvContentService.detener();
    this.tokenRefreshService.stopMonitoring();
  }

  /**
   * Cargar datos de habitaciones
   */
  cargarDatos(): void {
    this.loading = true;
    this.error = null;

    // Usar codHabCama de config_essi (sub-area seleccionada al configurar usuario)
    const codHabCama = this.usuario.permisos?.config_essi?.codHabCama || this.usuario.area_nombre;
    console.log('[Principal] Usuario:', this.usuario.nombre, '| codHabCama:', codHabCama, '| area_id:', this.usuario.area_id, '| rol:', this.usuario.rol);
    console.log('[Principal] config_essi:', JSON.stringify(this.usuario.permisos?.config_essi));

    if (!codHabCama) {
      console.warn('[Principal] codHabCama no configurado - no se pueden cargar camas');
      this.error = 'No tienes un area/sub-area asignada. Contacta al administrador.';
      this.loading = false;
      return;
    }

    this.dataService.consultarHabitacionesEsSi(codHabCama)
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (response) => {
          console.log('[Principal] Respuesta habitaciones:', JSON.stringify(response).substring(0, 500));
          if (!response.error && response.body) {
            const data = response.body;
            if (data.habitaciones) {
              this.lstHabitaciones = data.habitaciones;
              this.ultimaSincronizacion = data.ultimaSincronizacion || '';
              console.log('[Principal] Habitaciones cargadas:', this.lstHabitaciones.length);
            } else {
              // Compatibilidad: si viene como array directo
              this.lstHabitaciones = data as any;
            }
          }
          this.loading = false;
        },
        error: (err) => {
          console.error('[Principal] Error cargando habitaciones:', err);
          this.error = 'Error al cargar las habitaciones';
          this.loading = false;
        }
      });
  }

  /**
   * Iniciar polling de alertas
   */
  private iniciarPollingAlertas(): void {
    // Suscribirse a cambios de alertas
    this.alertService.getAlertas$()
      .pipe(takeUntil(this.destroy$))
      .subscribe(alertas => {
        this.lstAlerta = alertas;
        this.mapearPacientesAlertas();

        // Pausar overlays durante emergencias
        const hayEmergencia = alertas.some(a => a.estado === 2);
        if (hayEmergencia) {
          this.tvContentService.pausar();
        } else {
          this.tvContentService.reanudar();
        }
      });

    // Iniciar polling
    this.alertService.iniciarPolling(this.usuario.area_id);
  }

  /**
   * Mapear datos de pacientes a las alertas
   */
  private esBano(nombre: string): boolean {
    return nombre === 'Baño' || nombre === 'Bano';
  }

  private mapearPacientesAlertas(): void {
    this.lstAlerta.forEach(alerta => {
      alerta.camas.forEach((cama: any) => {
        if (this.esBano(cama.nombre)) {
          cama.nombre = '';
          cama.paciente = 'Baño';
          return;
        }

        const habitacion = this.lstHabitaciones.find(
          h => h.nombre === String(alerta.nombre)
        );

        if (habitacion) {
          let camaHabitacion = habitacion.camas.find(
            c => c.nombre === cama.nombre
          );

          // Cama única: codigo_cama = "-" → tomar la primera (y única) cama
          if (!camaHabitacion && cama.nombre === '-' && habitacion.camas.length === 1) {
            camaHabitacion = habitacion.camas[0];
            cama.nombre = camaHabitacion.nombre;
          }

          if (camaHabitacion?.paciente) {
            cama.paciente = camaHabitacion.paciente;
          }
        }
      });
    });
  }

  /**
   * Iniciar verificación de notas con recordatorios
   */
  private iniciarVerificacionNotas(): void {
    interval(1000)
      .pipe(takeUntil(this.destroy$))
      .subscribe(() => this.verificarRecordatoriosNotas());
  }

  /**
   * Verificar recordatorios de notas
   */
  private verificarRecordatoriosNotas(): void {
    moment.locale('es');
    const ahora = moment().tz('America/Lima');
    const fechaActual = ahora.format('YYYY-MM-DDTHH:mm');

    for (const habitacion of this.lstHabitaciones) {
      if (!habitacion.camas) continue;

      for (const cama of habitacion.camas) {
        if (!cama.nota || !cama.fecha_nota) continue;

        const fechaNota = cama.fecha_nota;
        const minAntes = moment(fechaNota).subtract(5, 'minutes').format('YYYY-MM-DDTHH:mm');
        const identificador = `${cama.paciente}-${habitacion.nombre}-${cama.nombre}-${cama.nota}-${fechaNota}`;

        // Recordatorio 5 minutos antes
        if (fechaActual === minAntes && !this.notificados.has(`${identificador}-warning`)) {
          this.mostrarRecordatorio(cama, habitacion, 'warning');
          this.notificados.add(`${identificador}-warning`);
          this.limpiarNotificacionDespues(identificador, 'warning');
        }

        // Recordatorio en la hora exacta
        if (fechaActual === fechaNota && !this.notificados.has(`${identificador}-exact`)) {
          this.mostrarRecordatorio(cama, habitacion, 'exact');
          this.notificados.add(`${identificador}-exact`);
          this.limpiarNotificacionDespues(identificador, 'exact');
        }
      }
    }
  }

  /**
   * Mostrar recordatorio de nota
   */
  private mostrarRecordatorio(cama: Cama, habitacion: Habitacion, tipo: 'warning' | 'exact'): void {
    const horaFormateada = moment(cama.fecha_nota).format('h:mm A');
    const mensaje = `
      <strong>Paciente:</strong> ${cama.paciente} <br>
      <strong>Cama:</strong> ${habitacion.nombre} (${cama.nombre}) <br>
      <strong>Nota:</strong> ${cama.nota} <br>
      <strong>Hora:</strong> ${horaFormateada}
    `;

    if (tipo === 'warning') {
      this.toastr.warning(mensaje, 'RECORDATORIO DENTRO DE 5 MINUTOS', {
        enableHtml: true,
        timeOut: 60000,
        positionClass: 'toast-bottom-left',
        progressBar: true
      });
    } else {
      this.toastr.error(mensaje, 'ASISTIR', {
        enableHtml: true,
        timeOut: 60000,
        positionClass: 'toast-bottom-right',
        progressBar: true
      });
    }

    // Reproducir audio
    this.audioService.reproducir('alerta');
    setTimeout(() => this.audioService.detener('alerta'), 4000);
  }

  /**
   * Limpiar notificación después de un tiempo
   */
  private limpiarNotificacionDespues(identificador: string, tipo: string): void {
    setTimeout(() => {
      this.notificados.delete(`${identificador}-${tipo}`);
    }, 60000);
  }

  /**
   * Programar refresh de datos sin recargar página
   */
  private programarRefresh(): void {
    interval(this.refreshInterval)
      .pipe(takeUntil(this.destroy$))
      .subscribe(() => this.cargarDatos());
  }

  private iniciarContenidoTv(): void {
    this.tvContentService.contenidoActual$
      .pipe(takeUntil(this.destroy$))
      .subscribe(contenido => {
        this.contenidoOverlay = contenido;
      });

    this.tvContentService.avisosPermanentes$
      .pipe(takeUntil(this.destroy$))
      .subscribe(avisos => {
        this.avisosPermanentes = avisos;
      });

    this.tvContentService.duracion$
      .pipe(takeUntil(this.destroy$))
      .subscribe(dur => {
        this.duracionOverlay = dur;
      });

    this.tvContentService.iniciar(this.usuario.area_id);
  }

  /**
   * Abrir diálogo para agregar nota
   */
  // Mapa de colores e iconos para notas comunes
  private notaConfig: Record<string, { color: string; icon: string }> = {
    'NPO':  { color: '#EF3038', icon: 'bi bi-x-circle-fill' },
    'SOP':  { color: '#7B2FBE', icon: 'bi bi-hospital-fill' },
    'TAC':  { color: '#E67700', icon: 'bi bi-disc-fill' },
    'RMN':  { color: '#0D6EFD', icon: 'bi bi-magnet-fill' },
    'ECO':  { color: '#28A745', icon: 'bi bi-soundwave' },
    'URVI': { color: '#17A2B8', icon: 'bi bi-radioactive' },
  };

  getNotaColor(nota: string): string {
    return this.notaConfig[nota?.toUpperCase()]?.color || '#EF3038';
  }

  getNotaIcon(nota: string): string {
    return this.notaConfig[nota?.toUpperCase()]?.icon || 'bi bi-chat-square-text-fill';
  }

  formatNotaHora(fechaNota: string): string {
    if (!fechaNota) return '';
    return moment(fechaNota).format('HH:mm');
  }

  formatNotaFecha(fechaNota: string): string {
    if (!fechaNota) return '';
    return moment(fechaNota).format('DD/MM');
  }

  addNota(): void {
    this.abrirDialogoNota();
  }

  addNotaPaciente(habitacion: Habitacion, cama: Cama): void {
    this.abrirDialogoNota(habitacion.nombre);
  }

  private abrirDialogoNota(preseleccionada?: string): void {
    const dialogRef = this.dialogo.open(AddNotaComponent, {
      width: '520px',
      maxWidth: '95vw',
      data: { habitaciones: this.lstHabitaciones, preseleccionada }
    });

    dialogRef.afterClosed()
      .pipe(takeUntil(this.destroy$))
      .subscribe((result: boolean) => {
        if (result === true || result === null) {
          this.cargarDatos();
        }
      });
  }

  // ============ FASE 1: cambio manual de cama ============

  /**
   * Solo enfermera/jefe/admin ven los botones de gestion manual.
   */
  get puedeGestionarCamas(): boolean {
    const rol = this.usuario?.rol;
    return rol === 'admin' || rol === 'jefe_area' || rol === 'enfermera';
  }

  esCamaManualPendiente(cama: Cama): boolean {
    return !!(cama.origen_cambio && cama.origen_cambio.startsWith('MANUAL_') && !cama.confirmado_por_essi);
  }

  abrirDialogoCambiarCama(habitacion: Habitacion, cama: Cama, event: Event): void {
    event.stopPropagation();
    if (!this.puedeGestionarCamas) {
      this.toastr.warning('No tiene permisos para mover pacientes');
      return;
    }
    if (!cama.paciente || !cama.paciente.trim()) {
      this.toastr.info('La cama no tiene paciente para mover');
      return;
    }

    const data: DialogCambiarCamaData = {
      camaOrigen: cama,
      habitacionOrigenNombre: habitacion.nombre,
      habitaciones: this.lstHabitaciones,
    };

    const ref = this.dialogo.open(DialogCambiarCamaComponent, {
      width: '560px',
      maxWidth: '95vw',
      data,
    });

    ref.afterClosed()
      .pipe(takeUntil(this.destroy$))
      .subscribe(result => {
        if (!result) return;
        this.dataService.cambiarCamaPaciente(cama.id, result.id_destino, result.motivo)
          .pipe(takeUntil(this.destroy$))
          .subscribe({
            next: (res) => {
              if (!res.error) {
                this.toastr.success(typeof res.body === 'string' ? res.body : 'Paciente movido');
                this.cargarDatos();
              } else {
                this.toastr.error(typeof res.body === 'string' ? res.body : 'No se pudo mover el paciente');
              }
            },
            error: (err) => {
              const msg = err?.error?.body || 'Error al mover paciente';
              this.toastr.error(typeof msg === 'string' ? msg : 'Error al mover paciente');
            }
          });
      });
  }

  // ============ FASE 2: ingreso manual de paciente ============

  esCamaIngresoManualPendiente(cama: Cama): boolean {
    return cama.origen_cambio === 'MANUAL_INGRESO' && !cama.confirmado_por_essi;
  }

  esCamaExpiradaRoja(cama: Cama): boolean {
    return !!cama.marcado_para_eliminar;
  }

  esCamaLibre(cama: Cama): boolean {
    return !cama.paciente || !cama.paciente.trim();
  }

  abrirDialogoIngresarPaciente(habitacion: Habitacion, cama: Cama, event: Event): void {
    event.stopPropagation();
    if (!this.puedeGestionarCamas) {
      this.toastr.warning('No tiene permisos para ingresar pacientes');
      return;
    }
    if (!this.esCamaLibre(cama)) {
      this.toastr.info('La cama ya tiene un paciente');
      return;
    }

    const data: DialogIngresarPacienteData = {
      cama,
      habitacionNombre: habitacion.nombre,
    };

    const ref = this.dialogo.open(DialogIngresarPacienteComponent, {
      width: '620px',
      maxWidth: '95vw',
      data,
    });

    ref.afterClosed()
      .pipe(takeUntil(this.destroy$))
      .subscribe(payload => {
        if (!payload) return;
        this.dataService.ingresarPacienteManual(payload)
          .pipe(takeUntil(this.destroy$))
          .subscribe({
            next: (res) => {
              if (!res.error) {
                this.toastr.success(typeof res.body === 'string' ? res.body : 'Paciente ingresado');
                this.cargarDatos();
              } else {
                this.toastr.error(typeof res.body === 'string' ? res.body : 'No se pudo ingresar el paciente');
              }
            },
            error: (err) => {
              const msg = err?.error?.body || 'Error al ingresar paciente';
              this.toastr.error(typeof msg === 'string' ? msg : 'Error al ingresar paciente');
            }
          });
      });
  }

  cancelarCambioManual(cama: Cama, event: Event): void {
    event.stopPropagation();
    if (!this.puedeGestionarCamas) {
      this.toastr.warning('No tiene permisos');
      return;
    }
    if (!confirm('¿Cancelar el cambio manual de esta cama? El sistema volverá a confiar en los datos de EsSi.')) {
      return;
    }
    this.dataService.cancelarCambioManual(cama.id)
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (res) => {
          if (!res.error) {
            this.toastr.success('Cambio manual cancelado');
            this.cargarDatos();
          } else {
            this.toastr.error(typeof res.body === 'string' ? res.body : 'No se pudo cancelar');
          }
        },
        error: () => this.toastr.error('Error al cancelar cambio manual')
      });
  }

  /**
   * Obtener longitud de string
   */
  long(nombre: string): number {
    return nombre?.length || 0;
  }

  /**
   * Obtener nombre y apellido del paciente
   */
  getNombreApellido(nombreCompleto: string): string {
    if (!nombreCompleto) return '';
    const partes = nombreCompleto.trim().split(/\s+/);
    if (partes.length === 1) return partes[0];
    return `${partes[0]} ${partes[partes.length - 1]}`;
  }

  /**
   * Verificar si habitación tiene alerta máxima
   */
  esAlertaMax(habitacionNombre: string): boolean {
    return this.lstAlerta?.some(
      h => String(h.nombre) === habitacionNombre && h.estado === 2
    ) ?? false;
  }

  /**
   * Verificar si habitación tiene alerta simple (tipo 1 - urgente)
   */
  tieneAlertaSimple(habitacionNombre: string): boolean {
    return this.lstAlerta?.some(
      h => String(h.nombre) === habitacionNombre && h.estado === 1
    ) ?? false;
  }

  /**
   * Verificar si habitación tiene alerta de baño
   */
  tieneAlertaBano(habitacionNombre: string): boolean {
    const alerta = this.lstAlerta?.find(
      h => String(h.nombre) === habitacionNombre
    );
    if (!alerta) return false;
    return alerta.camas?.some((c: any) => c.paciente === 'Baño') ?? false;
  }

  /**
   * Verificar si la alerta es SOLO de baño (no incluye camas normales)
   */
  esSoloAlertaBano(habitacionNombre: string): boolean {
    const alerta = this.lstAlerta?.find(
      h => String(h.nombre) === habitacionNombre
    );
    if (!alerta) return false;
    return alerta.camas?.every((c: any) => c.paciente === 'Baño') ?? false;
  }

  /**
   * Verificar si una emergencia incluye baño
   */
  esEmergenciaBano(alerta: HabitacionAlerta): boolean {
    return alerta.camas?.some((c: any) => c.paciente === 'Baño') ?? false;
  }

  /**
   * Verificar si una cama específica está en alerta
   */
  camaEnAlerta(habitacionNombre: string, camaNombre: string): boolean {
    const alerta = this.lstAlerta?.find(
      h => String(h.nombre) === habitacionNombre && h.estado === 1
    );
    if (!alerta) return false;
    return alerta.camas?.some((c: any) => c.nombre === camaNombre) ?? false;
  }

  /**
   * Reconocer alertas de una habitacion (solo jefe_area)
   */
  reconocerAlerta(habitacionId: number): void {
    this.dataService.reconocerAlerta(habitacionId)
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (response) => {
          if (!response.error) {
            this.toastr.success(response.body, 'Alerta reconocida');
          } else {
            this.toastr.error(response.body, 'Error');
          }
        },
        error: (err) => {
          console.error('Error reconociendo alerta:', err);
          this.toastr.error('Error al reconocer la alerta', 'Error');
        }
      });
  }

  /**
   * Obtener el nombre del paciente de una cama en alerta
   */
  getPacienteDeAlerta(habitacionNombre: string | number, camaNombre: string): string {
    const habitacion = this.lstHabitaciones.find(
      h => h.nombre === String(habitacionNombre)
    );
    if (!habitacion) return '';

    const cama = habitacion.camas?.find(c => c.nombre === camaNombre);
    return cama?.paciente ? this.getNombreApellido(cama.paciente) : '';
  }
}
