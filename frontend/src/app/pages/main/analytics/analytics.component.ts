import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { Subject, takeUntil, forkJoin, of, catchError } from 'rxjs';
import { BaseChartDirective, provideCharts, withDefaultRegisterables } from 'ng2-charts';
import { ChartConfiguration, ChartData } from 'chart.js';

import { ToastrService } from 'ngx-toastr';
import { AuthService } from '../../../../services/auth.service';
import { DataService } from '../../../../services/data.service';

@Component({
  selector: 'app-analytics',
  standalone: true,
  imports: [CommonModule, FormsModule, BaseChartDirective],
  providers: [provideCharts(withDefaultRegisterables())],
  templateUrl: './analytics.component.html',
  styleUrl: './analytics.component.scss'
})
export class AnalyticsComponent implements OnInit, OnDestroy {
  private destroy$ = new Subject<void>();
  private usuario: any;

  // Filtros
  fechaInicio = '';
  fechaFin = '';

  // Estado
  loading = true;
  error: string | null = null;
  areaNombre = '';
  activeTab = 0;

  // Datos crudos
  tiemposData: any = null;
  notasData: any = null;
  ocupacionData: any = null;
  frecuenciaData: any = null;

  // Graficos
  tiemposChartData: ChartData<'bar'> = { labels: [], datasets: [] };
  tiemposChartOptions: ChartConfiguration<'bar'>['options'] = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { display: true },
      title: { display: false }
    },
    scales: {
      y: { beginAtZero: true, title: { display: true, text: 'Minutos' } }
    }
  };

  notasChartData: ChartData<'pie'> = { labels: [], datasets: [] };
  notasChartOptions: ChartConfiguration<'pie'>['options'] = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { display: true, position: 'bottom' },
      title: { display: false }
    }
  };

  ocupacionChartData: ChartData<'line'> = { labels: [], datasets: [] };
  ocupacionChartOptions: ChartConfiguration<'line'>['options'] = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { display: true },
      title: { display: false }
    },
    scales: {
      y: { beginAtZero: true, title: { display: true, text: 'Cantidad' } }
    }
  };

  frecuenciaChartData: ChartData<'bar'> = { labels: [], datasets: [] };
  frecuenciaChartOptions: ChartConfiguration<'bar'>['options'] = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { display: true },
      title: { display: false }
    },
    scales: {
      y: { beginAtZero: true, title: { display: true, text: 'Cantidad' } }
    }
  };

  purgando = false;

  constructor(
    private authService: AuthService,
    private dataService: DataService,
    private router: Router,
    private toastr: ToastrService
  ) {}

  ngOnInit(): void {
    this.usuario = this.authService.getUsuario();
    const permisos = this.usuario?.permisos;
    const tienePermisos = permisos && Object.keys(permisos).length > 0;
    const tieneAcceso = tienePermisos
      ? !!permisos.analytics
      : ['admin', 'jefe_area'].includes(this.usuario?.rol || '');

    if (!this.usuario || !tieneAcceso) {
      this.router.navigateByUrl('/main/principal');
      return;
    }

    this.areaNombre = this.usuario.area_nombre || '';

    // Defaults: ultimo mes
    const hoy = new Date();
    const hace30 = new Date();
    hace30.setDate(hace30.getDate() - 30);
    this.fechaFin = hoy.toISOString().split('T')[0];
    this.fechaInicio = hace30.toISOString().split('T')[0];

    this.cargarDatos();
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }

  cargarDatos(): void {
    if (!this.fechaInicio || !this.fechaFin) return;

    this.loading = true;
    this.error = null;

    const areaId = this.usuario.area_id;
    const fi = this.fechaInicio;
    const ff = this.fechaFin;

    const fallback = { error: true, status: 0, body: null };

    forkJoin({
      tiempos: this.dataService.analyticsTiemposRespuesta(areaId, fi, ff).pipe(catchError(() => of(fallback))),
      notas: this.dataService.analyticsHistorialNotas(areaId, fi, ff).pipe(catchError(() => of(fallback))),
      ocupacion: this.dataService.analyticsOcupacion(areaId, fi, ff).pipe(catchError(() => of(fallback))),
      frecuencia: this.dataService.analyticsFrecuenciaAlertas(areaId, fi, ff).pipe(catchError(() => of(fallback)))
    })
    .pipe(takeUntil(this.destroy$))
    .subscribe({
      next: (results) => {
        this.tiemposData = results.tiempos.error ? null : results.tiempos.body;
        this.notasData = results.notas.error ? null : results.notas.body;
        this.ocupacionData = results.ocupacion.error ? null : results.ocupacion.body;
        this.frecuenciaData = results.frecuencia.error ? null : results.frecuencia.body;

        this.actualizarGraficos();
        this.loading = false;
      },
      error: (err) => {
        console.error('Error cargando analytics:', err);
        this.error = 'Error al cargar los datos de analytics';
        this.loading = false;
      }
    });
  }

  private actualizarGraficos(): void {
    this.actualizarTiemposChart();
    this.actualizarNotasChart();
    this.actualizarOcupacionChart();
    this.actualizarFrecuenciaChart();
  }

  private actualizarTiemposChart(): void {
    if (!this.tiemposData?.por_habitacion?.length) {
      this.tiemposChartData = { labels: ['Sin datos'], datasets: [{ data: [0], label: 'Tiempo promedio (min)' }] };
      return;
    }
    const hab = this.tiemposData.por_habitacion;
    this.tiemposChartData = {
      labels: hab.map((h: any) => `Hab. ${h.habitacion_id}`),
      datasets: [
        {
          data: hab.map((h: any) => h.tiempo_promedio_minutos),
          label: 'Tiempo promedio (min)',
          backgroundColor: 'rgba(54, 162, 235, 0.7)',
          borderColor: 'rgba(54, 162, 235, 1)',
          borderWidth: 1
        }
      ]
    };
  }

  private actualizarNotasChart(): void {
    if (!this.notasData?.por_accion?.length) {
      this.notasChartData = { labels: ['Sin datos'], datasets: [{ data: [1] }] };
      return;
    }
    const acciones = this.notasData.por_accion;
    const colores: Record<string, string> = {
      'CREAR': '#28a745',
      'MODIFICAR': '#ffc107',
      'ELIMINAR': '#dc3545'
    };
    this.notasChartData = {
      labels: acciones.map((a: any) => a.accion),
      datasets: [{
        data: acciones.map((a: any) => a.total),
        backgroundColor: acciones.map((a: any) => colores[a.accion] || '#6c757d')
      }]
    };
  }

  private actualizarOcupacionChart(): void {
    if (!this.ocupacionData?.por_dia?.length) {
      this.ocupacionChartData = { labels: ['Sin datos'], datasets: [{ data: [0], label: 'Ingresos' }] };
      return;
    }
    const dias = this.ocupacionData.por_dia;
    this.ocupacionChartData = {
      labels: dias.map((d: any) => d.fecha),
      datasets: [
        {
          data: dias.map((d: any) => d.ingresos),
          label: 'Ingresos',
          borderColor: '#28a745',
          backgroundColor: 'rgba(40, 167, 69, 0.1)',
          fill: true,
          tension: 0.3
        },
        {
          data: dias.map((d: any) => d.egresos),
          label: 'Egresos',
          borderColor: '#dc3545',
          backgroundColor: 'rgba(220, 53, 69, 0.1)',
          fill: true,
          tension: 0.3
        }
      ]
    };
  }

  private actualizarFrecuenciaChart(): void {
    if (!this.frecuenciaData?.por_hora?.length) {
      this.frecuenciaChartData = { labels: ['Sin datos'], datasets: [{ data: [0], label: 'Alertas' }] };
      return;
    }
    // Llenar todas las 24 horas
    const horasData = new Array(24).fill(0);
    this.frecuenciaData.por_hora.forEach((h: any) => {
      horasData[h.hora] = h.total;
    });
    this.frecuenciaChartData = {
      labels: Array.from({ length: 24 }, (_, i) => `${i.toString().padStart(2, '0')}:00`),
      datasets: [{
        data: horasData,
        label: 'Alertas',
        backgroundColor: 'rgba(255, 99, 132, 0.7)',
        borderColor: 'rgba(255, 99, 132, 1)',
        borderWidth: 1
      }]
    };
  }

  calcularPorcentajeOcupacion(): number {
    const ocupado = this.ocupacionData?.ocupacion_actual || 0;
    const total = this.ocupacionData?.total_camas || 1;
    return Math.round((ocupado / total) * 100);
  }

  calcularPorcentajeDia(total: number): number {
    if (!this.frecuenciaData?.por_dia_semana?.length) return 0;
    const max = Math.max(...this.frecuenciaData.por_dia_semana.map((d: any) => d.total));
    return max > 0 ? Math.round((total / max) * 100) : 0;
  }

  purgarAnalytics(): void {
    if (!confirm('¿Está seguro de eliminar TODOS los datos de analytics (alertas, notas y ocupación) del área ' + this.areaNombre + '? Esta acción no se puede deshacer.')) return;

    this.purgando = true;
    this.dataService.purgarAnalytics().pipe(
      takeUntil(this.destroy$)
    ).subscribe({
      next: (response) => {
        if (!response.error) {
          this.toastr.success(response.body, 'Datos eliminados');
          this.cargarDatos();
        } else {
          this.toastr.error(response.body, 'Error');
        }
        this.purgando = false;
      },
      error: () => {
        this.toastr.error('Error al purgar analytics', 'Error');
        this.purgando = false;
      }
    });
  }

  irAPrincipal(): void {
    this.router.navigateByUrl('/main/principal');
  }
}
