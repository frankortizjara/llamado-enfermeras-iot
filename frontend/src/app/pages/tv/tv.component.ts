import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute } from '@angular/router';
import { Subject, takeUntil, interval, switchMap, catchError, of } from 'rxjs';
import moment from 'moment-timezone';

import { DataService, Habitacion, Aviso } from '../../../services/data.service';
import { HabitacionAlerta } from '../../core/services/alert.service';
import { AudioService, AudioConfig } from '../../core/services/audio.service';
import { TvContentService, TvContentItem, AlertaOverlayData } from '../../core/services/tv-content.service';
import { TvOverlayComponent } from './tv-overlay/tv-overlay.component';

@Component({
  selector: 'app-tv',
  standalone: true,
  imports: [CommonModule, TvOverlayComponent],
  templateUrl: './tv.component.html',
  styleUrl: './tv.component.scss'
})
export class TvComponent implements OnInit, OnDestroy {
  private destroy$ = new Subject<void>();
  private dataPollingInterval = 30 * 1000; // 30 segundos
  private alertPollingInterval = 3 * 1000; // 3 segundos

  // Token de la pantalla
  private token = '';

  // Estado
  public lstHabitaciones: Habitacion[] = [];
  public lstAlerta: HabitacionAlerta[] = [];
  public loading = true;
  public errorMsg = '';
  public areaNombre = '';
  public pantallaNombre = '';
  public ultimaSincronizacion = '';

  // Contenido TV overlay
  public contenidoOverlay: TvContentItem | null = null;
  public avisosPermanentes: Aviso[] = [];
  public duracionOverlay = 15;

  // Grid dinámico
  public gridCols = 3;
  public gridRows = 2;

  // Escala de fuente (porcentaje, 100 = normal)
  public escalaFuente = 100;

  // IDs de alertas previas (para detectar nuevas)
  private alertasPreviasIds = new Set<string>();

  // Notas programadas - evitar duplicados
  private notasNotificadas = new Set<string>();

  // Config de pantalla
  private areaId = 0;
  private codHabCama = '';

  // Nota config (para badges)
  private notaConfig: Record<string, { color: string; icon: string }> = {
    'NPO':  { color: '#EF3038', icon: 'bi bi-x-circle-fill' },
    'SOP':  { color: '#7B2FBE', icon: 'bi bi-hospital-fill' },
    'TAC':  { color: '#E67700', icon: 'bi bi-disc-fill' },
    'RMN':  { color: '#0D6EFD', icon: 'bi bi-magnet-fill' },
    'ECO':  { color: '#28A745', icon: 'bi bi-soundwave' },
    'URVI': { color: '#17A2B8', icon: 'bi bi-radioactive' },
  };

  constructor(
    private route: ActivatedRoute,
    private dataService: DataService,
    private audioService: AudioService,
    private tvContentService: TvContentService,
  ) {}

  async ngOnInit(): Promise<void> {
    this.token = this.route.snapshot.paramMap.get('token') || '';

    if (!this.token) {
      this.errorMsg = 'Token de pantalla no proporcionado';
      this.loading = false;
      return;
    }

    // Cargar configuración de la pantalla desde el endpoint público
    this.dataService.obtenerPantallaPublica(this.token)
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (res) => {
          if (res.error) {
            this.errorMsg = 'Pantalla no encontrada o desactivada';
            this.loading = false;
            return;
          }

          const config = res.body;
          this.areaId = config.area_id || 0;
          this.areaNombre = config.area_nombre || '';
          this.pantallaNombre = config.nombre || '';
          this.codHabCama = config.cod_hab_cama || config.area_nombre || '';

          // Iniciar carga de datos
          this.cargarConfigAudio();
          this.cargarDatos();
          this.iniciarPollingAlertas();
          this.iniciarPollingDatos();
          this.iniciarContenidoTv();
          this.iniciarVerificacionNotas();

          // Intentar desbloquear audio automáticamente (para TV boxes con --autoplay-policy=no-user-gesture-required)
          this.audioService.desbloquear();
        },
        error: () => {
          this.errorMsg = 'Error al conectar con el servidor';
          this.loading = false;
        }
      });
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
    this.audioService.detenerTodos();
    this.tvContentService.detener();
  }

  cargarDatos(): void {
    this.loading = true;
    this.dataService.consultarHabitacionesPublica(this.token)
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (response) => {
          if (!response.error && response.body) {
            const data = response.body;
            if (data.habitaciones) {
              this.lstHabitaciones = data.habitaciones;
              this.ultimaSincronizacion = data.ultimaSincronizacion || '';
            } else {
              this.lstHabitaciones = data as any;
            }
            this.calcularGrid();
          }
          this.loading = false;
        },
        error: () => {
          this.loading = false;
        }
      });
  }

  private iniciarPollingAlertas(): void {
    if (!this.areaId) return;

    interval(this.alertPollingInterval).pipe(
      takeUntil(this.destroy$),
      switchMap(() => this.dataService.consultarAlertasPublica(this.token).pipe(
        catchError(() => of({ error: true, body: [], status: 0 }))
      ))
    ).subscribe(response => {
      if (!response.error && response.body) {
        this.procesarAlertas(response.body);
      }
    });
  }

  private procesarAlertas(alertas: HabitacionAlerta[]): void {
    // 1. Guardar y mapear pacientes PRIMERO
    this.lstAlerta = alertas;
    this.mapearPacientesAlertas();

    // 2. Detectar alertas nuevas (solo estado 1, no emergencias)
    const alertasActualesIds = new Set<string>();
    const nuevasIds: string[] = [];

    alertas.forEach(a => {
      const id = `${a.nombre}-${a.estado}`;
      alertasActualesIds.add(id);
      if (a.estado === 1 && !this.alertasPreviasIds.has(id)) {
        nuevasIds.push(id);
      }
    });
    this.alertasPreviasIds = alertasActualesIds;

    // 3. Mostrar overlay para alertas nuevas (usar lstAlerta que ya tiene pacientes mapeados)
    console.log('[TV-DEBUG] Alertas recibidas:', alertas.length, 'Nuevas:', nuevasIds.length);
    if (nuevasIds.length > 0) {
      // Buscar la primera alerta nueva en lstAlerta (ya tiene pacientes mapeados)
      const nuevaId = nuevasIds[0];
      const [nombreHab] = nuevaId.split('-');
      const a = this.lstAlerta.find(al => String(al.nombre) === nombreHab && al.estado === 1);

      if (a) {
        const esBano = a.camas?.every((c: any) => c.paciente === 'Baño') ?? false;
        const overlayData: AlertaOverlayData = {
          habitacion: String(a.nombre),
          camas: a.camas.map((c: any) => ({
            nombre: c.nombre || '',
            paciente: c.paciente || 'Sin asignar'
          })),
          esBano,
          hora: moment().format('hh:mm A')
        };
        console.log('[TV-DEBUG] Mostrando overlay:', overlayData);
        this.tvContentService.mostrarAlerta(overlayData);
      }
    }

    // 4. Audio y pausar/reanudar overlays
    const hayEmergencia = alertas.some(a => a.estado === 2);
    if (hayEmergencia) {
      this.tvContentService.pausar();
      this.audioService.reproducir('emergencia');
    } else if (alertas.length > 0) {
      this.tvContentService.reanudar();
      this.audioService.reproducir('alerta');
    } else {
      this.tvContentService.reanudar();
      this.audioService.detenerTodos();
    }
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

    // Iniciar servicio sin polling propio (nosotros controlamos la carga)
    this.tvContentService.iniciarSinPolling();
    this.iniciarContenidoTvPublico();
  }

  private iniciarContenidoTvPublico(): void {
    const cargar = () => {
      this.dataService.obtenerContenidoTvPublica(this.token).pipe(
        takeUntil(this.destroy$),
        catchError(() => of(null))
      ).subscribe(response => {
        if (response && !response.error && response.body) {
          this.tvContentService.procesarContenido(response.body);
        }
      });
    };

    cargar();
    // Polling cada 5 minutos
    interval(5 * 60 * 1000).pipe(takeUntil(this.destroy$)).subscribe(() => cargar());
  }

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
            cama.nombre = camaHabitacion.nombre; // Corregir "-" → "A"
          }

          if (camaHabitacion?.paciente) {
            cama.paciente = camaHabitacion.paciente;
          }
        }
      });
    });
  }

  private iniciarPollingDatos(): void {
    interval(this.dataPollingInterval).pipe(
      takeUntil(this.destroy$),
      switchMap(() => this.dataService.consultarHabitacionesPublica(this.token).pipe(
        catchError(() => of(null))
      ))
    ).subscribe(response => {
      if (response && !response.error && response.body) {
        const data = response.body;
        if (data.habitaciones) {
          this.lstHabitaciones = data.habitaciones;
          this.ultimaSincronizacion = data.ultimaSincronizacion || '';
        } else {
          this.lstHabitaciones = data as any;
        }
        this.calcularGrid();
      }
    });
  }

  private calcularGrid(): void {
    const total = this.lstHabitaciones.length;
    if (total <= 4)       { this.gridCols = 2; this.gridRows = 2; }
    else if (total <= 6)  { this.gridCols = 3; this.gridRows = 2; }
    else if (total <= 9)  { this.gridCols = 3; this.gridRows = 3; }
    else if (total <= 12) { this.gridCols = 4; this.gridRows = 3; }
    else if (total <= 16) { this.gridCols = 4; this.gridRows = 4; }
    else                  { this.gridCols = 5; this.gridRows = 4; }
  }

  private cargarConfigAudio(): void {
    this.dataService.obtenerConfigTvPublica(this.token)
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (res) => {
          if (!res.error && res.body) {
            const config = res.body as Record<string, string>;
            this.audioService.aplicarConfig({
              audio_habilitado: config['audio_habilitado'] || 'true',
              audio_volumen: config['audio_volumen'] || '80',
              audio_duracion_alerta: config['audio_duracion_alerta'] || '0',
              audio_duracion_emergencia: config['audio_duracion_emergencia'] || '0',
              audio_sonido_alerta: config['audio_sonido_alerta'] || 'Beep01.mp3',
              audio_sonido_emergencia: config['audio_sonido_emergencia'] || 'Beep02.mp3',
            } as AudioConfig);

            // Aplicar escala de fuente
            const escala = parseInt(config['tamano_fuente_tv']) || 100;
            this.escalaFuente = Math.max(80, Math.min(200, escala));
          }
        },
        error: () => {}
      });
  }

  // === Helpers de visualización ===

  getNombreApellido(nombreCompleto: string): string {
    if (!nombreCompleto) return '';
    return nombreCompleto.trim();
  }

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

  // === Helpers de alertas ===

  tieneAlertaSimple(habitacionNombre: string): boolean {
    return this.lstAlerta?.some(
      h => String(h.nombre) === habitacionNombre && h.estado === 1
    ) ?? false;
  }

  tieneAlertaBano(habitacionNombre: string): boolean {
    const alerta = this.lstAlerta?.find(
      h => String(h.nombre) === habitacionNombre
    );
    if (!alerta) return false;
    return alerta.camas?.some((c: any) => c.paciente === 'Baño') ?? false;
  }

  esSoloAlertaBano(habitacionNombre: string): boolean {
    const alerta = this.lstAlerta?.find(
      h => String(h.nombre) === habitacionNombre
    );
    if (!alerta) return false;
    return alerta.camas?.every((c: any) => c.paciente === 'Baño') ?? false;
  }

  camaEnAlerta(habitacionNombre: string, camaNombre: string): boolean {
    const alerta = this.lstAlerta?.find(
      h => String(h.nombre) === habitacionNombre && h.estado === 1
    );
    if (!alerta) return false;
    return alerta.camas?.some((c: any) => c.nombre === camaNombre) ?? false;
  }

  esEmergenciaBano(alerta: HabitacionAlerta): boolean {
    return alerta.camas?.some((c: any) => c.paciente === 'Baño') ?? false;
  }

  getPacienteDeAlerta(habitacionNombre: string | number, camaNombre: string): string {
    const habitacion = this.lstHabitaciones.find(
      h => h.nombre === String(habitacionNombre)
    );
    if (!habitacion) return '';
    const cama = habitacion.camas?.find(c => c.nombre === camaNombre);
    return cama?.paciente ? this.getNombreApellido(cama.paciente) : '';
  }

  // === Verificación de notas programadas (overlay en TV) ===

  private iniciarVerificacionNotas(): void {
    interval(1000)
      .pipe(takeUntil(this.destroy$))
      .subscribe(() => this.verificarRecordatoriosNotas());
  }

  private verificarRecordatoriosNotas(): void {
    const ahora = moment().tz('America/Lima');
    const fechaActual = ahora.format('YYYY-MM-DDTHH:mm');

    for (const habitacion of this.lstHabitaciones) {
      if (!habitacion.camas) continue;

      for (const cama of habitacion.camas) {
        if (!cama.nota || !cama.fecha_nota) continue;

        const fechaNota = moment(cama.fecha_nota).format('YYYY-MM-DDTHH:mm');
        const identificador = `${habitacion.nombre}-${cama.nombre}-${cama.nota}-${fechaNota}`;

        // Mostrar overlay en la hora exacta
        if (fechaActual === fechaNota && !this.notasNotificadas.has(identificador)) {
          this.notasNotificadas.add(identificador);
          console.log('[TV-DEBUG] Nota programada detectada:', identificador);

          const overlayData: AlertaOverlayData = {
            habitacion: String(habitacion.nombre),
            camas: [{
              nombre: cama.nombre,
              paciente: cama.paciente || 'Sin asignar'
            }],
            esBano: false,
            hora: moment(cama.fecha_nota).format('hh:mm A'),
            nota: cama.nota
          };
          this.tvContentService.mostrarAlerta(overlayData);

          // Limpiar después de 60s para permitir re-notificación si se reprograma
          setTimeout(() => this.notasNotificadas.delete(identificador), 60000);
        }
      }
    }
  }
}
