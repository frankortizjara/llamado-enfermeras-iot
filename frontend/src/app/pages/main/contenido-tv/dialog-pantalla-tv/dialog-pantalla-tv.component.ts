import { Component, Inject, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatDialogRef, MAT_DIALOG_DATA, MatDialogModule } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { Subject, takeUntil } from 'rxjs';
import { DataService } from '../../../../../services/data.service';

export interface PantallaTvData {
  id?: number;
  nombre: string;
  token: string;
  area_id?: number;
  area_nombre?: string;
  cod_hab_cama?: string;
  estado: boolean;
}

interface ServicioHospitalario {
  servicio: string;
  serv_hos_cod: string;
  estacion: string;
  est_enf_cod: string;
  ori_cen_asi_cod: string;
  cen_asi_cod: string;
  are_hos_cod: string;
}

interface SubArea {
  codHabCama: string;
  desEstCama: string;
  desSerCama: string;
  totalCamas: number;
}

@Component({
  selector: 'app-dialog-pantalla-tv',
  standalone: true,
  imports: [CommonModule, FormsModule, MatDialogModule, MatButtonModule],
  template: `
    <div class="dialog-wrapper">
      <div class="dialog-header">
        <i class="bi bi-display"></i>
        <h2>{{ data ? 'Editar' : 'Nueva' }} Pantalla TV</h2>
      </div>

      <div class="dialog-body">
        <div class="form-group">
          <label>Nombre de la pantalla *</label>
          <input type="text" [(ngModel)]="form.nombre" maxlength="100" placeholder="Ej: TV1 - Medicina Interna">
        </div>

        @if (!data) {
          <div class="form-group">
            <label>Token (se genera automáticamente)</label>
            <div class="token-row">
              <input type="text" [value]="form.token" readonly class="token-input">
              <button type="button" class="btn-regenerar" (click)="generarToken()" title="Regenerar token">
                <i class="bi bi-arrow-clockwise"></i>
              </button>
            </div>
          </div>
        }

        <div class="form-group">
          <label>Servicio hospitalario *</label>
          <select [(ngModel)]="selectedServicio" (change)="onServicioChange()">
            <option value="">-- Seleccionar servicio --</option>
            @for (s of serviciosUnicos; track s) {
              <option [value]="s">{{ s }}</option>
            }
          </select>
        </div>

        @if (selectedServicio) {
          <div class="form-group">
            <label>Estación</label>
            <select [(ngModel)]="selectedEstacion" (change)="onEstacionChange()">
              <option value="">-- Seleccionar estación --</option>
              @for (e of estacionesFiltradas; track e.estacion) {
                <option [value]="e.estacion">{{ e.estacion }}</option>
              }
            </select>
          </div>
        }

        @if (loadingSubAreas) {
          <div class="form-group">
            <span class="loading-text"><i class="bi bi-hourglass-split"></i> Cargando sub-áreas...</span>
          </div>
        }

        @if (subAreas.length > 0) {
          <div class="form-group">
            <label>Sub-área (codHabCama) *</label>
            <select [(ngModel)]="form.cod_hab_cama">
              <option value="">-- Seleccionar sub-área --</option>
              @for (sa of subAreas; track sa.codHabCama) {
                <option [value]="sa.codHabCama">{{ sa.desSerCama }} - {{ sa.desEstCama }} ({{ sa.totalCamas }} camas)</option>
              }
            </select>
          </div>
        }

        <div class="form-group">
          <label>Área (para alertas) *</label>
          <select [(ngModel)]="form.area_id">
            <option [ngValue]="null">-- Seleccionar área --</option>
            @for (area of areas; track area.id) {
              <option [ngValue]="area.id">{{ area.nombre }}</option>
            }
          </select>
        </div>

        <div class="form-group">
          <label>Área nombre (para título en TV)</label>
          <input type="text" [(ngModel)]="form.area_nombre" maxlength="255" placeholder="Ej: Medicina Interna">
        </div>

        @if (data) {
          <div class="form-group">
            <label class="toggle-label">
              <span>Estado</span>
              <label class="toggle-switch">
                <input type="checkbox" [(ngModel)]="form.estado">
                <span class="toggle-slider"></span>
              </label>
              <span class="toggle-text">{{ form.estado ? 'Activa' : 'Desactivada' }}</span>
            </label>
          </div>
        }

        @if (form.token) {
          <div class="enlace-preview">
            <label>Enlace de la pantalla:</label>
            <div class="enlace-url">
              <code>{{ getEnlace() }}</code>
              <button type="button" class="btn-copy" (click)="copiarEnlace()" [title]="copiado ? 'Copiado!' : 'Copiar enlace'">
                <i [class]="copiado ? 'bi bi-check-lg' : 'bi bi-clipboard'"></i>
              </button>
            </div>
          </div>
        }
      </div>

      <div class="dialog-footer">
        <button class="btn-cancel" (click)="dialogRef.close()">Cancelar</button>
        <button class="btn-save" (click)="guardar()" [disabled]="!form.nombre || !form.cod_hab_cama || !form.area_id">
          <i class="bi bi-check-lg"></i> Guardar
        </button>
      </div>
    </div>
  `,
  styleUrl: './dialog-pantalla-tv.component.scss'
})
export class DialogPantallaTvComponent implements OnInit, OnDestroy {
  private destroy$ = new Subject<void>();

  form: PantallaTvData = {
    nombre: '',
    token: '',
    area_nombre: '',
    cod_hab_cama: '',
    estado: true,
  };

  // Áreas
  areas: { id: number; nombre: string }[] = [];

  // Servicios hospitalarios
  serviciosHospitalarios: ServicioHospitalario[] = [];
  serviciosUnicos: string[] = [];
  estacionesFiltradas: ServicioHospitalario[] = [];
  subAreas: SubArea[] = [];
  selectedServicio = '';
  selectedEstacion = '';
  loadingSubAreas = false;
  copiado = false;

  constructor(
    public dialogRef: MatDialogRef<DialogPantallaTvComponent>,
    @Inject(MAT_DIALOG_DATA) public data: PantallaTvData | null,
    private dataService: DataService
  ) {
    if (data) {
      this.form = { ...data };
    } else {
      this.generarToken();
    }
  }

  ngOnInit(): void {
    this.cargarAreas();
    this.cargarServicios();
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }

  generarToken(): void {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    let token = '';
    for (let i = 0; i < 16; i++) {
      token += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    this.form.token = token;
  }

  cargarAreas(): void {
    this.dataService.listarAreas().pipe(
      takeUntil(this.destroy$)
    ).subscribe({
      next: (res) => {
        if (!res.error) {
          this.areas = res.body || [];
        }
      },
      error: () => {}
    });
  }

  cargarServicios(): void {
    this.dataService.listarServiciosHospitalarios().pipe(
      takeUntil(this.destroy$)
    ).subscribe({
      next: (res) => {
        if (!res.error) {
          this.serviciosHospitalarios = res.body || [];
          this.serviciosUnicos = [...new Set(this.serviciosHospitalarios.map((s: any) => s.servicio))];

          // Si estamos editando, intentar restaurar la selección
          if (this.data?.cod_hab_cama) {
            this.restaurarSeleccion();
          }
        }
      },
      error: () => {}
    });
  }

  private restaurarSeleccion(): void {
    // Intentar encontrar el servicio que corresponde al cod_hab_cama guardado
    for (const servicio of this.serviciosHospitalarios) {
      this.selectedServicio = servicio.servicio;
      this.onServicioChange();

      const estacion = this.estacionesFiltradas.find(e => e.estacion === servicio.estacion);
      if (estacion) {
        this.selectedEstacion = estacion.estacion;
        this.onEstacionChange();
        return;
      }
    }
  }

  onServicioChange(): void {
    this.estacionesFiltradas = this.serviciosHospitalarios.filter(
      s => s.servicio === this.selectedServicio
    );
    this.selectedEstacion = '';
    this.subAreas = [];
  }

  onEstacionChange(): void {
    if (!this.selectedEstacion) {
      this.subAreas = [];
      return;
    }

    const servicio = this.estacionesFiltradas.find(e => e.estacion === this.selectedEstacion);
    if (!servicio) return;

    this.loadingSubAreas = true;
    this.dataService.previewSubAreas({
      oriCenAsiCod: servicio.ori_cen_asi_cod,
      cenAsiCod: servicio.cen_asi_cod,
      areHosCod: servicio.are_hos_cod,
      servHosCod: servicio.serv_hos_cod,
      estEnfCod: servicio.est_enf_cod,
    }).pipe(takeUntil(this.destroy$)).subscribe({
      next: (res) => {
        if (!res.error && res.body) {
          this.subAreas = res.body || [];
        }
        this.loadingSubAreas = false;
      },
      error: () => {
        this.loadingSubAreas = false;
      }
    });
  }

  getEnlace(): string {
    const base = window.location.origin;
    return `${base}/tv/${this.form.token}`;
  }

  copiarEnlace(): void {
    navigator.clipboard.writeText(this.getEnlace()).then(() => {
      this.copiado = true;
      setTimeout(() => this.copiado = false, 2000);
    });
  }

  guardar(): void {
    // Auto-completar area_nombre si no se proporcionó
    if (!this.form.area_nombre && this.form.cod_hab_cama) {
      const subArea = this.subAreas.find(sa => sa.codHabCama === this.form.cod_hab_cama);
      if (subArea) {
        this.form.area_nombre = `${subArea.desSerCama} - ${subArea.desEstCama}`;
      }
    }

    this.dialogRef.close(this.form);
  }
}
