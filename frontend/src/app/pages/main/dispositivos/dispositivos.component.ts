import { Component, OnInit, OnDestroy, HostListener } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { Subject, takeUntil } from 'rxjs';
import { MatDialog } from '@angular/material/dialog';
import { ToastrService } from 'ngx-toastr';

import { AuthService } from '../../../../services/auth.service';
import { DataService } from '../../../../services/data.service';
import { DialogControlRfComponent, ControlRfData, DialogRfInput } from './dialog-control-rf/dialog-control-rf.component';

export interface Dispositivo {
  id: number;
  numero_serial: string;
  direccion_mac: string;
  ip: string;
  tipo_dispositivo: string;
  habitacion_id: number | null;
  relay_estado: boolean;
  uptime_segundos: number;
  rssi: number;
  ultimo_heartbeat: string;
  online: boolean;
  fecha_registro: string;
}

export interface RoomGroup {
  habitacionId: number;
  cuarto: Dispositivo | null;
  bano: Dispositivo | null;
  luz: Dispositivo | null;
  allOnline: boolean;
  allOffline: boolean;
}

export interface ControlRf {
  id: number;
  habitacion_id: number;
  cama: string;
  dip_config: boolean[];
  descripcion: string;
  fecha_registro: string;
  fecha_modificacion: string;
}

export interface Firmware {
  archivo: string;
  version: string;
  tamano: number;
  tamano_kb: number;
  fecha_subida: string;
  descripcion: string;
}

// View mode: 'rooms' shows grouped by room, 'all' shows flat list, 'rf' shows RF controls, 'firmware' shows OTA
type ViewMode = 'rooms' | 'all' | 'rf' | 'firmware';

@Component({
  selector: 'app-dispositivos',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './dispositivos.component.html',
  styleUrl: './dispositivos.component.scss'
})
export class DispositivosComponent implements OnInit, OnDestroy {
  private destroy$ = new Subject<void>();

  public loading = true;
  public error: string | null = null;
  public dispositivos: Dispositivo[] = [];
  public habitaciones: RoomGroup[] = [];
  public sinAsignar: Dispositivo[] = [];
  public ultimaActualizacion = '';
  public currentPage = 0;
  public itemsPerPage = 12;
  public viewMode: ViewMode = 'all';

  // Controles RF
  public controlesRf: ControlRf[] = [];
  public purgandoDispositivos = false;
  public loadingRf = false;

  // Firmware OTA
  public firmwares: Firmware[] = [];
  public loadingFw = false;
  public subiendoFw = false;
  public fwVersion = '';
  public fwDescripcion = '';

  constructor(
    private router: Router,
    private authService: AuthService,
    private dataService: DataService,
    private dialog: MatDialog,
    private toastr: ToastrService
  ) {}

  ngOnInit(): void {
    if (!this.authService.isAuthenticated()) {
      this.router.navigateByUrl('/login');
      return;
    }
    this.calculateItemsPerPage();
    this.cargarDatos();
    this.iniciarPolling();
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }

  @HostListener('window:resize')
  onResize(): void {
    this.calculateItemsPerPage();
  }

  private calculateItemsPerPage(): void {
    const vh = window.innerHeight;
    const availableHeight = vh - 140;
    const vw = window.innerWidth;
    let cols = 2;
    if (vw >= 1200) cols = 4;
    else if (vw >= 900) cols = 3;
    else if (vw >= 600) cols = 2;
    else cols = 1;

    if (this.viewMode === 'rooms') {
      const cardHeight = 185;
      const rows = Math.max(1, Math.floor(availableHeight / cardHeight));
      this.itemsPerPage = rows * cols;
    } else {
      // Flat view: smaller cards
      const cardHeight = 52;
      const rows = Math.max(1, Math.floor(availableHeight / cardHeight));
      this.itemsPerPage = rows * cols;
    }

    if (this.currentPage >= this.totalPages && this.totalPages > 0) {
      this.currentPage = this.totalPages - 1;
    }
  }

  setViewMode(mode: ViewMode): void {
    this.viewMode = mode;
    this.currentPage = 0;
    this.calculateItemsPerPage();
    if (mode === 'rf' && this.controlesRf.length === 0) {
      this.cargarControlesRf();
    }
    if (mode === 'firmware' && this.firmwares.length === 0) {
      this.cargarFirmwares();
    }
  }

  cargarDatos(): void {
    this.loading = true;
    this.error = null;

    this.dataService.listarDispositivos().pipe(
      takeUntil(this.destroy$)
    ).subscribe({
      next: (response) => {
        if (!response.error) {
          this.dispositivos = response.body || [];
          this.groupByRoom();
          this.autoSelectView();
          this.ultimaActualizacion = new Date().toLocaleTimeString();
        } else {
          this.error = 'Error al cargar dispositivos';
        }
        this.loading = false;
      },
      error: (err) => {
        this.error = 'Error de conexion con el servidor';
        this.loading = false;
      }
    });
  }

  private iniciarPolling(): void {
    this.dataService.listarDispositivosPolling(this.destroy$, 30000).pipe(
      takeUntil(this.destroy$)
    ).subscribe({
      next: (response) => {
        if (!response.error) {
          this.dispositivos = response.body || [];
          this.groupByRoom();
          this.ultimaActualizacion = new Date().toLocaleTimeString();
        }
      }
    });
  }

  private autoSelectView(): void {
    // If there are rooms, default to room view; otherwise flat view
    if (this.habitaciones.length > 0) {
      this.viewMode = 'rooms';
    } else {
      this.viewMode = 'all';
    }
    this.calculateItemsPerPage();
  }

  private groupByRoom(): void {
    const roomMap = new Map<number, RoomGroup>();
    this.sinAsignar = [];

    for (const d of this.dispositivos) {
      const habId = d.habitacion_id;

      // If no room assigned, add to unassigned list
      if (habId === null || habId === undefined) {
        this.sinAsignar.push(d);
        continue;
      }

      if (!roomMap.has(habId)) {
        roomMap.set(habId, {
          habitacionId: habId,
          cuarto: null,
          bano: null,
          luz: null,
          allOnline: false,
          allOffline: false
        });
      }

      const room = roomMap.get(habId)!;
      const tipo = (d.tipo_dispositivo || '').toLowerCase();

      if (tipo === 'cuarto') {
        room.cuarto = d;
      } else if (tipo === 'bano' || tipo === 'baño') {
        room.bano = d;
      } else if (tipo === 'luces' || tipo === 'luz') {
        room.luz = d;
      } else {
        // Unknown type: assign to first empty slot
        if (!room.cuarto) room.cuarto = d;
        else if (!room.bano) room.bano = d;
        else if (!room.luz) room.luz = d;
        else this.sinAsignar.push(d); // Overflow goes to unassigned
      }
    }

    // Calculate online status for each room
    for (const room of roomMap.values()) {
      const devices = [room.cuarto, room.bano, room.luz].filter(d => d !== null);
      room.allOnline = devices.length > 0 && devices.every(d => d!.online);
      room.allOffline = devices.length === 0 || devices.every(d => !d!.online);
    }

    this.habitaciones = Array.from(roomMap.values()).sort((a, b) => a.habitacionId - b.habitacionId);
  }

  // Pagination for current view mode
  get totalItems(): number {
    if (this.viewMode === 'rooms') {
      return this.habitaciones.length;
    }
    return this.dispositivos.length;
  }

  get totalPages(): number {
    return Math.max(1, Math.ceil(this.totalItems / this.itemsPerPage));
  }

  get paginatedRooms(): RoomGroup[] {
    const start = this.currentPage * this.itemsPerPage;
    return this.habitaciones.slice(start, start + this.itemsPerPage);
  }

  get paginatedDevices(): Dispositivo[] {
    const start = this.currentPage * this.itemsPerPage;
    return this.dispositivos.slice(start, start + this.itemsPerPage);
  }

  nextPage(): void {
    if (this.currentPage < this.totalPages - 1) {
      this.currentPage++;
    }
  }

  prevPage(): void {
    if (this.currentPage > 0) {
      this.currentPage--;
    }
  }

  purgarDispositivos(): void {
    if (!confirm('¿Está seguro de eliminar TODOS los dispositivos ESP32 registrados y sus eventos? Los dispositivos se volverán a registrar automáticamente cuando envíen heartbeat.')) return;

    this.purgandoDispositivos = true;
    this.dataService.purgarDispositivosEsp32().pipe(
      takeUntil(this.destroy$)
    ).subscribe({
      next: (response) => {
        if (!response.error) {
          this.toastr.success(response.body, 'Dispositivos eliminados');
          this.cargarDatos();
        } else {
          this.toastr.error(response.body, 'Error');
        }
        this.purgandoDispositivos = false;
      },
      error: () => {
        this.toastr.error('Error al purgar dispositivos', 'Error');
        this.purgandoDispositivos = false;
      }
    });
  }

  eliminarDispositivo(d: Dispositivo, event: Event): void {
    event.stopPropagation();
    const label = `${this.getTipoLabel(d.tipo_dispositivo)} - Hab. ${d.habitacion_id ?? 'Sin asignar'} (${d.numero_serial})`;
    if (!confirm(`¿Eliminar el dispositivo "${label}"?`)) return;

    this.dataService.eliminarDispositivo(d.id).pipe(
      takeUntil(this.destroy$)
    ).subscribe({
      next: (response) => {
        if (!response.error) {
          this.toastr.success(response.body, 'Dispositivo eliminado');
          this.cargarDatos();
        } else {
          this.toastr.error(response.body, 'Error');
        }
      },
      error: () => {
        this.toastr.error('Error al eliminar dispositivo', 'Error');
      }
    });
  }

  irAPrincipal(): void {
    this.router.navigateByUrl('/main/principal');
  }

  irAEstadisticas(): void {
    this.router.navigateByUrl('/main/dispositivos/estadisticas');
  }

  formatUptime(segundos: number): string {
    if (!segundos) return '-';
    const h = Math.floor(segundos / 3600);
    const m = Math.floor((segundos % 3600) / 60);
    if (h > 0) return `${h}h ${m}m`;
    return `${m}m`;
  }

  formatHeartbeat(fecha: string): string {
    if (!fecha) return 'Nunca';
    const date = new Date(fecha);
    const ahora = new Date();
    const diffMs = ahora.getTime() - date.getTime();
    const diffMin = Math.floor(diffMs / 60000);

    if (diffMin < 1) return '<1 min';
    if (diffMin < 60) return `${diffMin} min`;
    const diffH = Math.floor(diffMin / 60);
    if (diffH < 24) return `${diffH}h`;
    return date.toLocaleDateString();
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

  getRssiLabel(rssi: number): string {
    if (rssi >= -50) return 'Excelente';
    if (rssi >= -60) return 'Buena';
    if (rssi >= -70) return 'Regular';
    return 'Debil';
  }

  getRssiClass(rssi: number): string {
    if (rssi >= -50) return 'signal-excellent';
    if (rssi >= -60) return 'signal-good';
    if (rssi >= -70) return 'signal-fair';
    return 'signal-weak';
  }

  get dispositivosOnline(): number {
    return this.dispositivos.filter(d => d.online).length;
  }

  get dispositivosOffline(): number {
    return this.dispositivos.filter(d => !d.online).length;
  }

  get habAsignadas(): number {
    return this.habitaciones.length;
  }

  // ============================================
  // CONTROLES RF
  // ============================================

  cargarControlesRf(): void {
    this.loadingRf = true;
    this.dataService.listarControlesRf().pipe(
      takeUntil(this.destroy$)
    ).subscribe({
      next: (response) => {
        if (!response.error) {
          this.controlesRf = response.body || [];
        }
        this.loadingRf = false;
      },
      error: () => {
        this.loadingRf = false;
      }
    });
  }

  abrirDialogRf(control?: ControlRf): void {
    const controlData: ControlRfData | null = control ? {
      id: control.id,
      habitacion_id: control.habitacion_id,
      cama: control.cama,
      dip_config: [...control.dip_config],
      descripcion: control.descripcion
    } : null;

    const data: DialogRfInput = {
      control: controlData,
      habitacionesDisponibles: this.habitaciones.map(h => h.habitacionId)
    };

    const dialogRef = this.dialog.open(DialogControlRfComponent, {
      width: '500px',
      maxWidth: '95vw',
      data
    });

    dialogRef.afterClosed().pipe(
      takeUntil(this.destroy$)
    ).subscribe((result: ControlRfData | undefined) => {
      if (result) {
        this.guardarControlRf(result);
      }
    });
  }

  private guardarControlRf(data: ControlRfData): void {
    this.dataService.agregarControlRf(data).pipe(
      takeUntil(this.destroy$)
    ).subscribe({
      next: (response) => {
        if (!response.error) {
          this.toastr.success(response.body, 'Control RF');
          this.cargarControlesRf();
        } else {
          this.toastr.error(response.body, 'Error');
        }
      },
      error: (err) => {
        this.toastr.error(err.error?.body || 'Error al guardar', 'Error');
      }
    });
  }

  eliminarControlRf(control: ControlRf): void {
    this.dataService.eliminarControlRf(control.id).pipe(
      takeUntil(this.destroy$)
    ).subscribe({
      next: (response) => {
        if (!response.error) {
          this.toastr.success(response.body, 'Control RF');
          this.cargarControlesRf();
        } else {
          this.toastr.error(response.body, 'Error');
        }
      },
      error: () => {
        this.toastr.error('Error al eliminar', 'Error');
      }
    });
  }

  getDipDisplay(config: boolean[]): string {
    return (config || []).map(v => v ? '1' : '0').join('');
  }

  // ============================================
  // FIRMWARE OTA
  // ============================================

  cargarFirmwares(): void {
    this.loadingFw = true;
    this.dataService.listarFirmwares().pipe(
      takeUntil(this.destroy$)
    ).subscribe({
      next: (response) => {
        if (!response.error) {
          this.firmwares = response.body || [];
        }
        this.loadingFw = false;
      },
      error: () => {
        this.loadingFw = false;
      }
    });
  }

  subirFirmware(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (!input.files?.length) return;

    const file = input.files[0];
    const ext = file.name.split('.').pop()?.toLowerCase();

    if (ext !== 'bin') {
      this.toastr.error('Solo se permiten archivos .bin', 'Error');
      input.value = '';
      return;
    }

    if (file.size > 2 * 1024 * 1024) {
      this.toastr.error('El archivo no puede exceder 2MB', 'Error');
      input.value = '';
      return;
    }

    if (!this.fwVersion.trim()) {
      this.toastr.error('Ingresa la version del firmware', 'Error');
      return;
    }

    // Validar formato version (X.X.X)
    if (!/^\d+\.\d+\.\d+$/.test(this.fwVersion.trim())) {
      this.toastr.error('La version debe tener formato X.X.X (ej: 2.0.0)', 'Error');
      return;
    }

    this.subiendoFw = true;
    this.dataService.subirFirmware(file, this.fwVersion.trim(), this.fwDescripcion.trim()).pipe(
      takeUntil(this.destroy$)
    ).subscribe({
      next: (response) => {
        if (!response.error) {
          this.toastr.success('Firmware subido correctamente', 'OTA');
          this.fwVersion = '';
          this.fwDescripcion = '';
          this.cargarFirmwares();
        } else {
          this.toastr.error(response.body, 'Error');
        }
        this.subiendoFw = false;
        input.value = '';
      },
      error: (err) => {
        const msg = err.error?.body || err.error?.message || err.message || 'Error al subir firmware';
        this.toastr.error(msg, 'Error');
        this.subiendoFw = false;
        input.value = '';
      }
    });
  }

  descargarFirmware(fw: Firmware): void {
    const url = this.dataService.getUrlDescargaFirmware(fw.archivo);
    const a = document.createElement('a');
    a.href = url;
    a.download = fw.archivo;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
  }

  eliminarFirmware(fw: Firmware): void {
    if (!confirm(`Eliminar firmware ${fw.version} (${fw.archivo})?`)) return;

    this.dataService.eliminarFirmware(fw.archivo).pipe(
      takeUntil(this.destroy$)
    ).subscribe({
      next: (response) => {
        if (!response.error) {
          this.toastr.success('Firmware eliminado', 'OTA');
          this.cargarFirmwares();
        } else {
          this.toastr.error(response.body, 'Error');
        }
      },
      error: () => {
        this.toastr.error('Error al eliminar firmware', 'Error');
      }
    });
  }

  formatFecha(fecha: string): string {
    if (!fecha) return '-';
    const d = new Date(fecha);
    return d.toLocaleDateString('es-PE', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' });
  }
}
