import { Injectable } from '@angular/core';
import { BehaviorSubject, Subject, takeUntil, catchError, of } from 'rxjs';
import { DataService, Efemeride, Cumpleano, Aviso, ContenidoTv, ConfigTv } from '../../../services/data.service';

export type TvContentType = 'efemeride' | 'cumpleano' | 'aviso' | 'alerta';

export interface AlertaOverlayData {
  habitacion: string;
  camas: { nombre: string; paciente: string }[];
  esBano: boolean;
  hora: string;
  nota?: string; // NPO, SOP, TAC, etc. — solo para alertas de nota programada
}

export interface TvContentItem {
  tipo: TvContentType;
  data: Efemeride | Cumpleano[] | Aviso | AlertaOverlayData;
}

@Injectable({
  providedIn: 'root'
})
export class TvContentService {
  private destroy$ = new Subject<void>();
  private pausado = false;
  private mostrandoOverlay = false;
  private areaId = 0;

  // Timers
  private pollingTimer: any = null;
  private efemerideTimer: any = null;
  private cumpleanoTimer: any = null;
  private avisoPeriodicoTimer: any = null;
  private ocultarTimer: any = null;
  private initialTimers: any[] = [];

  // Contenido cargado
  private efemerides: Efemeride[] = [];
  private cumpleanos: Cumpleano[] = [];
  private avisosperiodicos: Aviso[] = [];
  private avisosPermanentesData: Aviso[] = [];
  private indiceEfemeride = 0;
  private indiceAvisoPeriodico = 0;

  // Configuración (defaults en minutos/segundos)
  private config: ConfigTv = {
    intervalo_efemerides: '40',
    intervalo_cumpleanos: '30',
    intervalo_avisos: '15',
    duracion_overlay: '15',
    tamano_fuente_tv: '100',
    audio_habilitado: 'true',
    audio_volumen: '80',
    audio_duracion_alerta: '0',
    audio_duracion_emergencia: '0',
    audio_sonido_alerta: 'Beep01.mp3',
    audio_sonido_emergencia: 'Beep02.mp3'
  };

  /** Overlay periódico (efemérides, cumpleaños, avisos periódicos) */
  private contenidoActualSubject = new BehaviorSubject<TvContentItem | null>(null);
  contenidoActual$ = this.contenidoActualSubject.asObservable();

  /** Avisos permanentes (siempre visibles como banner) */
  private avisosPermanentesSubject = new BehaviorSubject<Aviso[]>([]);
  avisosPermanentes$ = this.avisosPermanentesSubject.asObservable();

  /** Duración del overlay en segundos (para progress bar CSS) */
  private duracionSubject = new BehaviorSubject<number>(15);
  duracion$ = this.duracionSubject.asObservable();

  constructor(private dataService: DataService) {}

  /**
   * Inicializar el servicio sin polling propio (para modo público)
   * El componente se encarga de llamar procesarContenido() manualmente
   */
  iniciarSinPolling(): void {
    this.detener();
    this.destroy$ = new Subject<void>();
  }

  iniciar(areaId: number): void {
    this.detener();
    this.destroy$ = new Subject<void>();
    this.areaId = areaId;

    // Cargar contenido inmediatamente
    this.cargarContenido();

    // Polling cada 5 minutos para actualizar contenido y config
    this.pollingTimer = setInterval(() => this.cargarContenido(), 5 * 60 * 1000);
  }

  detener(): void {
    this.destroy$.next();
    this.destroy$.complete();
    this.limpiarTimers();
    this.contenidoActualSubject.next(null);
    this.avisosPermanentesSubject.next([]);
    this.efemerides = [];
    this.cumpleanos = [];
    this.avisosperiodicos = [];
    this.avisosPermanentesData = [];
    this.indiceEfemeride = 0;
    this.indiceAvisoPeriodico = 0;
    this.mostrandoOverlay = false;
  }

  pausar(): void {
    this.pausado = true;
    if (this.mostrandoOverlay) {
      this.ocultarOverlay();
    }
  }

  reanudar(): void {
    this.pausado = false;
  }

  private limpiarTimers(): void {
    [this.pollingTimer, this.efemerideTimer, this.cumpleanoTimer, this.avisoPeriodicoTimer].forEach(t => {
      if (t) clearInterval(t);
    });
    this.initialTimers.forEach(t => clearTimeout(t));
    if (this.ocultarTimer) clearTimeout(this.ocultarTimer);
    this.pollingTimer = null;
    this.efemerideTimer = null;
    this.cumpleanoTimer = null;
    this.avisoPeriodicoTimer = null;
    this.ocultarTimer = null;
    this.initialTimers = [];
  }

  private cargarContenido(): void {
    this.dataService.obtenerContenidoTvHoy(this.areaId).pipe(
      takeUntil(this.destroy$),
      catchError(() => of(null))
    ).subscribe(response => {
      if (response && !response.error && response.body) {
        this.procesarContenido(response.body);
      }
    });
  }

  procesarContenido(contenido: ContenidoTv): void {
    this.efemerides = contenido.efemerides || [];
    this.cumpleanos = contenido.cumpleanos || [];

    // Separar avisos por modo
    const avisos = contenido.avisos || [];
    this.avisosPermanentesData = avisos.filter(a => a.modo_display === 'permanente');
    this.avisosperiodicos = avisos.filter(a => a.modo_display !== 'permanente');

    // Emitir avisos permanentes
    this.avisosPermanentesSubject.next(this.avisosPermanentesData);

    // Aplicar config si viene
    if (contenido.config) {
      this.config = { ...this.config, ...contenido.config };
      const dur = parseInt(this.config.duracion_overlay) || 15;
      this.duracionSubject.next(dur);
    }

    // Reiniciar timers con la config
    this.iniciarTimers();
  }

  private iniciarTimers(): void {
    // Limpiar timers anteriores (excepto polling)
    [this.efemerideTimer, this.cumpleanoTimer, this.avisoPeriodicoTimer].forEach(t => {
      if (t) clearInterval(t);
    });
    this.initialTimers.forEach(t => clearTimeout(t));
    this.initialTimers = [];

    const minToMs = (min: string) => (parseInt(min) || 15) * 60 * 1000;

    // Timer de efemérides
    if (this.efemerides.length > 0) {
      const intervaloEfem = minToMs(this.config.intervalo_efemerides);
      // Primera aparición: 30s después del inicio, luego respetar el intervalo configurado
      this.initialTimers.push(setTimeout(() => {
        this.mostrarEfemeride();
        this.efemerideTimer = setInterval(() => this.mostrarEfemeride(), intervaloEfem);
      }, 30 * 1000));
    }

    // Timer de cumpleaños
    if (this.cumpleanos.length > 0) {
      const intervaloCumple = minToMs(this.config.intervalo_cumpleanos);
      // Primera aparición: después del intervalo de efemérides + duración overlay + margen
      const durOverlay = (parseInt(this.config.duracion_overlay) || 15) * 1000;
      const primerCumple = 30 * 1000 + durOverlay + 10 * 1000;
      this.initialTimers.push(setTimeout(() => {
        this.mostrarCumpleanos();
        this.cumpleanoTimer = setInterval(() => this.mostrarCumpleanos(), intervaloCumple);
      }, primerCumple));
    }

    // Timer de avisos periódicos
    if (this.avisosperiodicos.length > 0) {
      const intervaloAvisos = minToMs(this.config.intervalo_avisos);
      const durOverlay = (parseInt(this.config.duracion_overlay) || 15) * 1000;
      const primerAviso = 30 * 1000 + (durOverlay + 10 * 1000) * 2;
      this.initialTimers.push(setTimeout(() => {
        this.mostrarAvisoPeriodico();
        this.avisoPeriodicoTimer = setInterval(() => this.mostrarAvisoPeriodico(), intervaloAvisos);
      }, primerAviso));
    }
  }

  private mostrarEfemeride(): void {
    if (this.pausado || this.mostrandoOverlay || this.efemerides.length === 0) return;
    const efem = this.efemerides[this.indiceEfemeride % this.efemerides.length];
    this.indiceEfemeride++;
    this.mostrar({ tipo: 'efemeride', data: efem });
  }

  private mostrarCumpleanos(): void {
    if (this.pausado || this.mostrandoOverlay || this.cumpleanos.length === 0) return;
    this.mostrar({ tipo: 'cumpleano', data: this.cumpleanos });
  }

  private mostrarAvisoPeriodico(): void {
    if (this.pausado || this.mostrandoOverlay || this.avisosperiodicos.length === 0) return;
    const aviso = this.avisosperiodicos[this.indiceAvisoPeriodico % this.avisosperiodicos.length];
    this.indiceAvisoPeriodico++;
    this.mostrar({ tipo: 'aviso', data: aviso });
  }

  /**
   * Mostrar overlay de alerta de cama (llamado desde tv.component cuando llega alerta nueva)
   * Las alertas tienen prioridad: interrumpen cualquier overlay de contenido activo
   */
  mostrarAlerta(data: AlertaOverlayData): void {
    console.log('[TV-DEBUG] mostrarAlerta llamado. pausado:', this.pausado, 'mostrandoOverlay:', this.mostrandoOverlay);
    if (this.pausado) return;
    // Si hay un overlay de contenido mostrándose, lo interrumpimos
    if (this.mostrandoOverlay) {
      console.log('[TV-DEBUG] Interrumpiendo overlay activo para mostrar alerta');
      this.ocultarOverlay();
    }
    this.mostrar({ tipo: 'alerta', data });
  }

  private mostrar(item: TvContentItem): void {
    this.mostrandoOverlay = true;
    this.contenidoActualSubject.next(item);

    const duracion = (parseInt(this.config.duracion_overlay) || 15) * 1000;
    this.ocultarTimer = setTimeout(() => this.ocultarOverlay(), duracion);
  }

  private ocultarOverlay(): void {
    this.mostrandoOverlay = false;
    this.contenidoActualSubject.next(null);
    if (this.ocultarTimer) {
      clearTimeout(this.ocultarTimer);
      this.ocultarTimer = null;
    }
  }
}
