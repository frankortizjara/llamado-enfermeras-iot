import { Injectable, OnDestroy } from '@angular/core';
import { BehaviorSubject, Observable, Subject, interval, takeUntil, switchMap, retry, catchError, of } from 'rxjs';
import { DataService } from '../../../services/data.service';
import { AudioService } from './audio.service';

export interface Alerta {
  id: number;
  nombre: string; // código de cama
  habitacion_id: number;
  tipo_alerta?: number;
  paciente?: string; // nombre del paciente (asignado dinámicamente)
}

export interface HabitacionAlerta {
  nombre: number; // habitacion_id
  estado: number; // 1 = normal, 2 = emergencia
  camas: Alerta[];
}

/**
 * Servicio para gestión de alertas
 * Extrae la lógica de alertas del PrincipalComponent
 */
@Injectable({
  providedIn: 'root'
})
export class AlertService implements OnDestroy {
  private destroy$ = new Subject<void>();
  private alertas$ = new BehaviorSubject<HabitacionAlerta[]>([]);
  private tieneEmergencia$ = new BehaviorSubject<boolean>(false);
  private habitacionEmergencia$ = new BehaviorSubject<HabitacionAlerta | null>(null);

  private pollingInterval = 3000; // 3 segundos (antes era 1.6s)
  private isPolling = false;

  constructor(
    private dataService: DataService,
    private audioService: AudioService
  ) {}

  /**
   * Obtener observable de alertas
   */
  getAlertas$(): Observable<HabitacionAlerta[]> {
    return this.alertas$.asObservable();
  }

  /**
   * Obtener observable de estado de emergencia
   */
  getTieneEmergencia$(): Observable<boolean> {
    return this.tieneEmergencia$.asObservable();
  }

  /**
   * Obtener habitación en emergencia
   */
  getHabitacionEmergencia$(): Observable<HabitacionAlerta | null> {
    return this.habitacionEmergencia$.asObservable();
  }

  /**
   * Iniciar polling de alertas
   */
  iniciarPolling(areaId: number): void {
    if (this.isPolling) return;
    this.isPolling = true;

    interval(this.pollingInterval).pipe(
      takeUntil(this.destroy$),
      switchMap(() => this.dataService.consultarAlertas(areaId).pipe(
        retry({ count: 2, delay: 1000 }),
        catchError(err => {
          console.error('Error consultando alertas:', err);
          return of({ error: true, body: [] });
        })
      ))
    ).subscribe(response => {
      if (!response.error && response.body) {
        this.procesarAlertas(response.body);
      }
    });
  }

  /**
   * Detener polling de alertas
   */
  detenerPolling(): void {
    this.isPolling = false;
    this.destroy$.next();
  }

  /**
   * Procesar alertas recibidas
   */
  private procesarAlertas(alertas: HabitacionAlerta[]): void {
    this.alertas$.next(alertas);

    // Verificar si hay emergencia (estado 2)
    const emergencia = alertas.find(h => h.estado === 2);

    if (emergencia) {
      this.tieneEmergencia$.next(true);
      this.habitacionEmergencia$.next(emergencia);
      this.audioService.reproducir('emergencia');
    } else if (alertas.length > 0) {
      this.tieneEmergencia$.next(false);
      this.habitacionEmergencia$.next(null);
      this.audioService.reproducir('alerta');
    } else {
      this.tieneEmergencia$.next(false);
      this.habitacionEmergencia$.next(null);
      this.audioService.detenerTodos();
    }
  }

  /**
   * Verificar si una habitación tiene alerta
   */
  habitacionTieneAlerta(habitacionId: number): boolean {
    const alertas = this.alertas$.value;
    return alertas.some(a => a.nombre === habitacionId);
  }

  /**
   * Obtener estado de alerta de una habitación
   * @returns 0 = sin alerta, 1 = alerta normal, 2 = emergencia
   */
  getEstadoAlerta(habitacionId: number): number {
    const alertas = this.alertas$.value;
    const habitacion = alertas.find(a => a.nombre === habitacionId);
    return habitacion?.estado || 0;
  }

  /**
   * Obtener camas con alerta de una habitación
   */
  getCamasConAlerta(habitacionId: number): Alerta[] {
    const alertas = this.alertas$.value;
    const habitacion = alertas.find(a => a.nombre === habitacionId);
    return habitacion?.camas || [];
  }

  /**
   * Verificar si hay alguna emergencia activa
   */
  tieneAlertaEmergencia(): boolean {
    return this.tieneEmergencia$.value;
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
    this.audioService.detenerTodos();
  }
}
