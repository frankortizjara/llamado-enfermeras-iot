import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { Subject, takeUntil } from 'rxjs';

import { ToastrService } from 'ngx-toastr';
import { AuthService } from '../../../../../services/auth.service';
import { DataService } from '../../../../../services/data.service';

interface DeviceStats {
  id: number;
  numero_serial: string;
  direccion_mac: string;
  ip: string;
  tipo_dispositivo: string;
  habitacion_id: number | null;
  estado: boolean;
  online: boolean;
  ultimo_heartbeat: string;
  fecha_registro: string;
  total_desconexiones: number;
  total_reconexiones: number;
  total_reemplazos: number;
  ultimo_evento_fecha: string | null;
  ultimo_evento_tipo: string | null;
}

interface DeviceEvent {
  id: number;
  numero_serial: string;
  tipo_evento: string;
  detalles: any;
  fecha: string;
}

@Component({
  selector: 'app-estadisticas-dispositivos',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './estadisticas-dispositivos.component.html',
  styleUrl: './estadisticas-dispositivos.component.scss'
})
export class EstadisticasDispositivosComponent implements OnInit, OnDestroy {
  private destroy$ = new Subject<void>();

  public loading = true;
  public loadingEventos = false;
  public error: string | null = null;
  public dispositivos: DeviceStats[] = [];
  public eventos: DeviceEvent[] = [];
  public selectedSerial: string | null = null;

  // Filtros de fecha
  public fechaInicio: string = '';
  public fechaFin: string = '';

  // Resumen
  public totalDesconexiones = 0;
  public totalReconexiones = 0;
  public totalReemplazos = 0;

  public purgando = false;

  constructor(
    private router: Router,
    private authService: AuthService,
    private dataService: DataService,
    private toastr: ToastrService
  ) {}

  ngOnInit(): void {
    if (!this.authService.isAuthenticated()) {
      this.router.navigateByUrl('/login');
      return;
    }

    // Defaults: ultimos 30 dias
    const hoy = new Date();
    const hace30 = new Date();
    hace30.setDate(hace30.getDate() - 30);

    this.fechaFin = this.formatDate(hoy);
    this.fechaInicio = this.formatDate(hace30);

    this.cargarEstadisticas();
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }

  cargarEstadisticas(): void {
    this.loading = true;
    this.error = null;
    this.selectedSerial = null;
    this.eventos = [];

    this.dataService.estadisticasDispositivos(this.fechaInicio, this.fechaFin).pipe(
      takeUntil(this.destroy$)
    ).subscribe({
      next: (response) => {
        if (!response.error) {
          this.dispositivos = response.body || [];
          this.calcularResumen();
        } else {
          this.error = 'Error al cargar estadísticas';
        }
        this.loading = false;
      },
      error: () => {
        this.error = 'Error de conexión con el servidor';
        this.loading = false;
      }
    });
  }

  private calcularResumen(): void {
    this.totalDesconexiones = this.dispositivos.reduce((sum, d) => sum + (d.total_desconexiones || 0), 0);
    this.totalReconexiones = this.dispositivos.reduce((sum, d) => sum + (d.total_reconexiones || 0), 0);
    this.totalReemplazos = this.dispositivos.reduce((sum, d) => sum + (d.total_reemplazos || 0), 0);
  }

  verEventos(serial: string): void {
    if (this.selectedSerial === serial) {
      this.selectedSerial = null;
      this.eventos = [];
      return;
    }

    this.selectedSerial = serial;
    this.loadingEventos = true;
    this.eventos = [];

    this.dataService.eventosDispositivo(serial, this.fechaInicio, this.fechaFin).pipe(
      takeUntil(this.destroy$)
    ).subscribe({
      next: (response) => {
        if (!response.error) {
          this.eventos = response.body || [];
        }
        this.loadingEventos = false;
      },
      error: () => {
        this.loadingEventos = false;
      }
    });
  }

  purgarEventos(): void {
    if (!confirm('¿Está seguro de eliminar TODOS los datos de conexión y desconexión? Esta acción no se puede deshacer.')) return;

    this.purgando = true;
    this.dataService.purgarEventosDispositivos().pipe(
      takeUntil(this.destroy$)
    ).subscribe({
      next: (response) => {
        if (!response.error) {
          this.toastr.success(response.body, 'Datos eliminados');
          this.cargarEstadisticas();
        } else {
          this.toastr.error(response.body, 'Error');
        }
        this.purgando = false;
      },
      error: () => {
        this.toastr.error('Error al purgar eventos', 'Error');
        this.purgando = false;
      }
    });
  }

  irADispositivos(): void {
    this.router.navigateByUrl('/main/dispositivos');
  }

  private formatDate(date: Date): string {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

  getTipoLabel(tipo: string): string {
    const labels: Record<string, string> = {
      'luces': 'Luz',
      'cuarto': 'Cuarto',
      'bano': 'Baño',
      'desconocido': 'Desconocido'
    };
    return labels[tipo] || tipo || 'Desconocido';
  }

  getTipoIcon(tipo: string): string {
    const icons: Record<string, string> = {
      'luces': 'bi-lightbulb-fill',
      'cuarto': 'bi-door-open-fill',
      'bano': 'bi-droplet-fill',
      'desconocido': 'bi-question-circle-fill'
    };
    return icons[tipo] || 'bi-cpu-fill';
  }

  getEventoIcon(tipo: string): string {
    const icons: Record<string, string> = {
      'online': 'bi-arrow-up-circle-fill',
      'offline': 'bi-arrow-down-circle-fill',
      'reemplazo': 'bi-arrow-repeat'
    };
    return icons[tipo] || 'bi-circle';
  }

  getEventoLabel(tipo: string): string {
    const labels: Record<string, string> = {
      'online': 'Conectado',
      'offline': 'Desconectado',
      'reemplazo': 'Reemplazado'
    };
    return labels[tipo] || tipo;
  }

  formatFecha(fecha: string): string {
    if (!fecha) return '-';
    const d = new Date(fecha);
    return d.toLocaleString('es-PE', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  }

  formatFechaCorta(fecha: string): string {
    if (!fecha) return '-';
    const d = new Date(fecha);
    const ahora = new Date();
    const diffMs = ahora.getTime() - d.getTime();
    const diffMin = Math.floor(diffMs / 60000);

    if (diffMin < 1) return '<1 min';
    if (diffMin < 60) return `${diffMin} min`;
    const diffH = Math.floor(diffMin / 60);
    if (diffH < 24) return `${diffH}h`;
    return d.toLocaleDateString('es-PE');
  }

  get dispositivosActivos(): DeviceStats[] {
    return this.dispositivos.filter(d => d.estado);
  }

  get dispositivosInactivos(): DeviceStats[] {
    return this.dispositivos.filter(d => !d.estado);
  }
}
