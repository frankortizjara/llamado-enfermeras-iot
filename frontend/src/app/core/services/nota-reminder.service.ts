import { Injectable, OnDestroy } from '@angular/core';
import { Subject, BehaviorSubject, Observable } from 'rxjs';
import { ToastrService } from 'ngx-toastr';
import * as moment from 'moment-timezone';

export interface Nota {
  id: number;
  nombre: string;
  paciente: string;
  nota: string;
  fecha_nota: string;
}

export interface ReminderEvent {
  tipo: 'warning' | 'error';
  nota: Nota;
  mensaje: string;
}

/**
 * Servicio para gestión de recordatorios de notas
 * Extrae la lógica de recordatorios del PrincipalComponent
 */
@Injectable({
  providedIn: 'root'
})
export class NotaReminderService implements OnDestroy {
  private destroy$ = new Subject<void>();
  private intervalId: ReturnType<typeof setInterval> | null = null;
  private notas: Nota[] = [];
  private notasNotificadas: Set<string> = new Set();

  private reminderEvent$ = new Subject<ReminderEvent>();
  private isRunning$ = new BehaviorSubject<boolean>(false);

  // Horas pares para recordatorios (8:00, 10:00, 12:00, etc.)
  private horasRecordatorio = [8, 10, 12, 14, 16, 18, 20, 22];

  constructor(private toastr: ToastrService) {}

  /**
   * Observable de eventos de recordatorio
   */
  getReminderEvents$(): Observable<ReminderEvent> {
    return this.reminderEvent$.asObservable();
  }

  /**
   * Iniciar verificación de recordatorios
   */
  iniciarVerificacion(notas: Nota[]): void {
    this.notas = notas;

    if (this.intervalId) {
      this.detenerVerificacion();
    }

    this.isRunning$.next(true);

    // Verificar cada segundo
    this.intervalId = setInterval(() => {
      this.verificarRecordatorios();
    }, 1000);
  }

  /**
   * Actualizar lista de notas
   */
  actualizarNotas(notas: Nota[]): void {
    this.notas = notas;
  }

  /**
   * Detener verificación de recordatorios
   */
  detenerVerificacion(): void {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
    }
    this.isRunning$.next(false);
  }

  /**
   * Verificar recordatorios pendientes
   */
  private verificarRecordatorios(): void {
    const ahora = moment().tz('America/Lima');
    const horaActual = ahora.hour();
    const minutoActual = ahora.minute();
    const segundoActual = ahora.second();

    // Solo verificar en segundos 0 para evitar múltiples notificaciones
    if (segundoActual !== 0) return;

    this.notas.forEach(nota => {
      if (!nota.nota || nota.nota === '0000') return;

      const horaNota = this.parseHoraNota(nota.nota);
      if (!horaNota) return;

      const { hora: horaNotaNum, minuto: minutoNotaNum } = horaNota;
      const notaKey = `${nota.id}-${nota.nota}`;

      // Recordatorio 5 minutos antes (solo en horas pares)
      if (this.horasRecordatorio.includes(horaActual)) {
        if (horaActual === horaNotaNum && minutoActual === (minutoNotaNum - 5)) {
          if (!this.notasNotificadas.has(`${notaKey}-warning`)) {
            this.emitirRecordatorio('warning', nota,
              `Recordatorio: En 5 minutos - ${nota.paciente || nota.nombre}`);
            this.notasNotificadas.add(`${notaKey}-warning`);
          }
        }

        // Recordatorio en la hora exacta
        if (horaActual === horaNotaNum && minutoActual === minutoNotaNum) {
          if (!this.notasNotificadas.has(`${notaKey}-error`)) {
            this.emitirRecordatorio('error', nota,
              `¡ATENCIÓN! Hora de nota - ${nota.paciente || nota.nombre}`);
            this.notasNotificadas.add(`${notaKey}-error`);
          }
        }
      }
    });

    // Limpiar notificaciones antiguas cada hora
    if (minutoActual === 0) {
      this.limpiarNotificacionesAntiguas();
    }
  }

  /**
   * Parsear hora de la nota (formato HHMM)
   */
  private parseHoraNota(notaStr: string): { hora: number; minuto: number } | null {
    if (!notaStr || notaStr.length !== 4) return null;

    const hora = parseInt(notaStr.substring(0, 2), 10);
    const minuto = parseInt(notaStr.substring(2, 4), 10);

    if (isNaN(hora) || isNaN(minuto)) return null;
    if (hora < 0 || hora > 23 || minuto < 0 || minuto > 59) return null;

    return { hora, minuto };
  }

  /**
   * Emitir evento de recordatorio
   */
  private emitirRecordatorio(tipo: 'warning' | 'error', nota: Nota, mensaje: string): void {
    const event: ReminderEvent = { tipo, nota, mensaje };
    this.reminderEvent$.next(event);

    // Mostrar toastr
    if (tipo === 'warning') {
      this.toastr.warning(mensaje, 'Recordatorio', {
        timeOut: 10000,
        closeButton: true
      });
    } else {
      this.toastr.error(mensaje, '¡Atención!', {
        timeOut: 15000,
        closeButton: true
      });
    }
  }

  /**
   * Limpiar notificaciones antiguas
   */
  private limpiarNotificacionesAntiguas(): void {
    // Limpiar set de notificaciones cada hora para permitir re-notificación
    this.notasNotificadas.clear();
  }

  /**
   * Verificar si el servicio está corriendo
   */
  isRunning(): boolean {
    return this.isRunning$.value;
  }

  ngOnDestroy(): void {
    this.detenerVerificacion();
    this.destroy$.next();
    this.destroy$.complete();
  }
}
