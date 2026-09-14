import { Component, OnDestroy, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Subject, takeUntil } from 'rxjs';
import { ToastrService } from 'ngx-toastr';

import { DataService, AuditoriaItem, AuditoriaPagina } from '../../../../services/data.service';

// Acciones conocidas para el filtro (se pueden agregar mas a medida que entran Fases 2/3)
const ACCIONES_DISPONIBLES = [
  { value: '', label: 'Todas' },
  { value: 'INGRESO', label: 'Ingreso (sync)' },
  { value: 'EGRESO', label: 'Egreso (sync)' },
  { value: 'CAMBIO_CAMA_MANUAL', label: 'Cambio cama (manual)' },
  { value: 'INTERCAMBIO_CAMA_MANUAL', label: 'Intercambio cama (manual)' },
  { value: 'MANUAL_CONFIRMADO_POR_ESSI', label: 'Manual confirmado' },
  { value: 'MANUAL_CANCELADO', label: 'Manual cancelado' },
  { value: 'CONFLICTO_DETECTADO', label: 'Conflicto detectado' },
  { value: 'CONFIG_MODIFICADA', label: 'Configuración modificada' },
];

@Component({
  selector: 'app-auditoria',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './auditoria.component.html',
  styleUrl: './auditoria.component.scss',
})
export class AuditoriaComponent implements OnInit, OnDestroy {
  private destroy$ = new Subject<void>();

  // Estado
  registros: AuditoriaItem[] = [];
  total = 0;
  loading = false;
  descargando = false;

  // Paginacion
  pagina = 1;
  pageSize = 25;

  // Filtros
  filtroDesde = '';
  filtroHasta = '';
  filtroAccion = '';

  acciones = ACCIONES_DISPONIBLES;

  constructor(
    private dataService: DataService,
    private toastr: ToastrService
  ) {}

  ngOnInit(): void {
    this.cargar();
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }

  get totalPaginas(): number {
    return Math.max(1, Math.ceil(this.total / this.pageSize));
  }

  cargar(): void {
    this.loading = true;
    const filtros: any = {
      limit: this.pageSize,
      offset: (this.pagina - 1) * this.pageSize,
    };
    if (this.filtroDesde) filtros.desde = `${this.filtroDesde}T00:00:00`;
    if (this.filtroHasta) filtros.hasta = `${this.filtroHasta}T23:59:59`;
    if (this.filtroAccion) filtros.accion = this.filtroAccion;

    this.dataService.listarAuditoria(filtros)
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (res) => {
          this.loading = false;
          if (!res.error && res.body) {
            const pagina = res.body as AuditoriaPagina;
            this.registros = pagina.registros || [];
            this.total = pagina.total || 0;
          } else {
            this.toastr.error('No se pudo cargar la auditoría');
          }
        },
        error: () => {
          this.loading = false;
          this.toastr.error('Error al cargar la auditoría');
        }
      });
  }

  aplicarFiltros(): void {
    this.pagina = 1;
    this.cargar();
  }

  limpiarFiltros(): void {
    this.filtroDesde = '';
    this.filtroHasta = '';
    this.filtroAccion = '';
    this.aplicarFiltros();
  }

  irPagina(p: number): void {
    if (p < 1 || p > this.totalPaginas) return;
    this.pagina = p;
    this.cargar();
  }

  descargarCsv(): void {
    this.descargando = true;
    const filtros: any = {};
    if (this.filtroDesde) filtros.desde = `${this.filtroDesde}T00:00:00`;
    if (this.filtroHasta) filtros.hasta = `${this.filtroHasta}T23:59:59`;
    if (this.filtroAccion) filtros.accion = this.filtroAccion;

    this.dataService.descargarAuditoriaCsv(filtros)
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (blob) => {
          this.descargando = false;
          const url = window.URL.createObjectURL(blob);
          const a = document.createElement('a');
          a.href = url;
          a.download = `auditoria_${new Date().toISOString().slice(0, 10)}.csv`;
          document.body.appendChild(a);
          a.click();
          document.body.removeChild(a);
          window.URL.revokeObjectURL(url);
          this.toastr.success('CSV descargado');
        },
        error: () => {
          this.descargando = false;
          this.toastr.error('Error al descargar CSV');
        }
      });
  }

  /**
   * Devuelve clase CSS para colorear segun el tipo de accion.
   */
  rowClass(accion: string): string {
    if (!accion) return '';
    if (accion === 'MANUAL_CONFIRMADO_POR_ESSI') return 'row-success';
    if (accion === 'CONFLICTO_DETECTADO' || accion === 'MANUAL_EXPIRADO_MARCADO_ROJO' || accion === 'MANUAL_ELIMINADO_AUTO') return 'row-danger';
    if (accion.startsWith('MANUAL_') || accion === 'CAMBIO_CAMA_MANUAL' || accion === 'INTERCAMBIO_CAMA_MANUAL' || accion === 'ALTA_PROGRAMADA' || accion === 'RESERVA_FUTURA' || accion === 'INGRESO_MANUAL') return 'row-manual';
    return '';
  }

  formatearFecha(iso: string | null): string {
    if (!iso) return '';
    const d = new Date(iso);
    if (isNaN(d.getTime())) return iso;
    return d.toLocaleString('es-PE', { hour12: false });
  }
}
