import { Component, Inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatDialogRef, MAT_DIALOG_DATA, MatDialogModule } from '@angular/material/dialog';
import { Subject, debounceTime, takeUntil } from 'rxjs';

import { Cama, DataService, IngresoManualPayload } from '../../../../../services/data.service';

export interface DialogIngresarPacienteData {
  cama: Cama;
  habitacionNombre: string;
}

@Component({
  selector: 'app-dialog-ingresar-paciente',
  standalone: true,
  imports: [CommonModule, FormsModule, MatDialogModule],
  template: `
    <div class="dialog-wrapper">
      <div class="dialog-header">
        <i class="bi bi-person-plus-fill"></i>
        <h2>Ingresar paciente manualmente</h2>
      </div>

      <div class="dialog-body">
        <div class="info-cama">
          <strong>Cama destino:</strong>
          {{ data.habitacionNombre }} - {{ data.cama.nombre }}
        </div>

        <div class="form-row">
          <div class="form-group flex-2">
            <label>DNI / Documento *</label>
            <div class="dni-row">
              <input type="text" [(ngModel)]="form.nro_doc_ide_pac"
                     (ngModelChange)="onDniChange($event)"
                     maxlength="20" placeholder="Ej: 12345678" autofocus>
              @if (buscandoDni) {
                <span class="dni-status"><i class="bi bi-hourglass-split"></i></span>
              } @else if (dniEncontrado) {
                <span class="dni-status dni-found" title="Paciente ya existe — datos autocompletados">
                  <i class="bi bi-check-circle-fill"></i>
                </span>
              } @else if (form.nro_doc_ide_pac.length >= 6 && dniBuscado) {
                <span class="dni-status dni-new" title="DNI nuevo">
                  <i class="bi bi-person-plus"></i>
                </span>
              }
            </div>
          </div>
          <div class="form-group">
            <label>Tipo doc.</label>
            <select [(ngModel)]="form.tipo_doc_ide_pac">
              <option value="DNI">DNI</option>
              <option value="CE">Carnet de Extranjería</option>
              <option value="PAS">Pasaporte</option>
              <option value="OTRO">Otro</option>
            </select>
          </div>
        </div>

        <div class="form-group">
          <label>Apellidos y nombres *</label>
          <input type="text" [(ngModel)]="form.ape_nom_pac"
                 maxlength="255" placeholder="Ej: Pérez Gómez, Juan Carlos">
        </div>

        <div class="form-row">
          <div class="form-group">
            <label>Historia clínica</label>
            <input type="text" [(ngModel)]="form.nro_his_cli_cas"
                   maxlength="50" placeholder="Opcional">
          </div>
          <div class="form-group">
            <label>Servicio</label>
            <input type="text" [(ngModel)]="form.des_ser_cama"
                   maxlength="255" placeholder="Ej: Medicina">
          </div>
        </div>

        <div class="form-group">
          <label>Fecha y hora de salida obligatoria *</label>
          <input type="datetime-local" [(ngModel)]="form.fecha_salida_obligatoria"
                 [min]="minFechaSalida">
          <span class="config-hint">
            Si EsSi no confirma este paciente antes de esa fecha, se marcará en rojo y se eliminará automáticamente.
          </span>
        </div>

        <div class="form-group">
          <label>Origen del paciente *</label>
          <div class="radio-group">
            <label class="radio-option">
              <input type="radio" name="perteneceArea"
                     [value]="true" [(ngModel)]="form.pertenece_al_area">
              <span>Pertenece a esta área</span>
            </label>
            <label class="radio-option">
              <input type="radio" name="perteneceArea"
                     [value]="false" [(ngModel)]="form.pertenece_al_area">
              <span>Viene de otra área</span>
            </label>
          </div>
        </div>

        <div class="form-group">
          <label>Motivo (opcional)</label>
          <textarea [(ngModel)]="form.motivo" rows="2" maxlength="500"
                    placeholder="Ej: ingreso de emergencia, transferencia desde UCI, etc."></textarea>
        </div>

        <div class="info-aclaracion">
          <i class="bi bi-info-circle"></i>
          Este ingreso quedará marcado como <strong>manual (naranja)</strong> hasta que
          la sincronización con EsSi lo confirme por DNI.
        </div>
      </div>

      <div class="dialog-footer">
        <button class="btn-cancel" (click)="dialogRef.close()">Cancelar</button>
        <button class="btn-save" (click)="confirmar()"
                [disabled]="!formularioValido() || guardando">
          <i class="bi bi-check-lg"></i>
          {{ guardando ? 'Guardando...' : 'Ingresar paciente' }}
        </button>
      </div>
    </div>
  `,
  styles: [`
    .dialog-wrapper { padding: 0; min-width: 540px; max-width: 640px; }
    .dialog-header { padding: 20px 24px; background: linear-gradient(135deg, #f97316 0%, #ea580c 100%); color: white; display: flex; align-items: center; gap: 12px; }
    .dialog-header i { font-size: 24px; }
    .dialog-header h2 { margin: 0; font-size: 18px; font-weight: 600; }
    .dialog-body { padding: 24px; max-height: 70vh; overflow-y: auto; }
    .info-cama { background: #f3f4f6; padding: 10px 14px; border-radius: 6px; margin-bottom: 16px; }
    .form-row { display: flex; gap: 12px; }
    .form-row .form-group { flex: 1; }
    .form-row .flex-2 { flex: 2; }
    .form-group { margin-bottom: 14px; }
    .form-group label { display: block; margin-bottom: 4px; font-weight: 500; color: #374151; font-size: 13px; }
    .form-group input, .form-group select, .form-group textarea {
      width: 100%; padding: 8px 12px; border: 1px solid #d1d5db; border-radius: 6px;
      font-size: 14px; font-family: inherit; box-sizing: border-box;
    }
    .dni-row { display: flex; align-items: center; gap: 8px; }
    .dni-row input { flex: 1; }
    .dni-status { font-size: 18px; color: #6b7280; }
    .dni-found { color: #16a34a; }
    .dni-new { color: #f97316; }
    .config-hint { font-size: 12px; color: #6b7280; display: block; margin-top: 4px; }
    .radio-group { display: flex; gap: 16px; padding: 6px 0; }
    .radio-option { display: flex; align-items: center; gap: 6px; cursor: pointer; font-size: 14px; }
    .info-aclaracion { background: #fff7ed; border-left: 4px solid #f97316; padding: 10px 14px; border-radius: 4px; color: #7c2d12; font-size: 13px; margin-top: 8px; }
    .info-aclaracion i { margin-right: 6px; }
    .dialog-footer { display: flex; justify-content: flex-end; gap: 8px; padding: 16px 24px; border-top: 1px solid #e5e7eb; background: #fafafa; }
    .btn-cancel, .btn-save { padding: 8px 16px; border-radius: 6px; border: none; cursor: pointer; font-size: 14px; font-weight: 500; }
    .btn-cancel { background: #e5e7eb; color: #374151; }
    .btn-cancel:hover { background: #d1d5db; }
    .btn-save { background: #f97316; color: white; }
    .btn-save:hover:not(:disabled) { background: #ea580c; }
    .btn-save:disabled { background: #d1d5db; cursor: not-allowed; }
  `]
})
export class DialogIngresarPacienteComponent {
  private destroy$ = new Subject<void>();
  private dniInput$ = new Subject<string>();

  form: IngresoManualPayload = {
    id_cama: 0,
    nro_doc_ide_pac: '',
    tipo_doc_ide_pac: 'DNI',
    ape_nom_pac: '',
    nro_his_cli_cas: '',
    des_ser_cama: '',
    fecha_salida_obligatoria: '',
    pertenece_al_area: true,
    motivo: '',
  };

  buscandoDni = false;
  dniEncontrado = false;
  dniBuscado = false;
  guardando = false;
  minFechaSalida: string;

  constructor(
    public dialogRef: MatDialogRef<DialogIngresarPacienteComponent>,
    @Inject(MAT_DIALOG_DATA) public data: DialogIngresarPacienteData,
    private dataService: DataService
  ) {
    this.form.id_cama = data.cama.id;

    // Sugerir fecha de salida = mañana 12:00
    const manana = new Date();
    manana.setDate(manana.getDate() + 1);
    manana.setHours(12, 0, 0, 0);
    this.form.fecha_salida_obligatoria = this.toLocalIsoNoZ(manana);

    // Min: 5 min en el futuro (datetime-local no acepta segundos en min razonablemente)
    const min = new Date(Date.now() + 5 * 60 * 1000);
    this.minFechaSalida = this.toLocalIsoNoZ(min);

    // Debounce de busqueda por DNI
    this.dniInput$
      .pipe(debounceTime(450), takeUntil(this.destroy$))
      .subscribe(dni => this.buscarDni(dni));
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }

  /**
   * Convierte un Date a formato YYYY-MM-DDTHH:mm (lo que pide datetime-local).
   */
  private toLocalIsoNoZ(d: Date): string {
    const pad = (n: number) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  onDniChange(dni: string): void {
    this.dniEncontrado = false;
    this.dniBuscado = false;
    const limpio = (dni || '').trim();
    if (limpio.length < 6) return;
    this.dniInput$.next(limpio);
  }

  private buscarDni(dni: string): void {
    this.buscandoDni = true;
    this.dataService.buscarPacientePorDni(dni)
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (res) => {
          this.buscandoDni = false;
          this.dniBuscado = true;
          if (!res.error && res.body) {
            this.dniEncontrado = true;
            // Autocompletar solo si el usuario no lo escribio aun
            const p = res.body;
            if (!this.form.ape_nom_pac) this.form.ape_nom_pac = p.ape_nom_pac;
            if (!this.form.nro_his_cli_cas) this.form.nro_his_cli_cas = p.nro_his_cli_cas || '';
            if (p.tipo_doc_ide_pac) this.form.tipo_doc_ide_pac = p.tipo_doc_ide_pac;
          } else {
            this.dniEncontrado = false;
          }
        },
        error: () => {
          this.buscandoDni = false;
          this.dniBuscado = true;
          this.dniEncontrado = false;
        }
      });
  }

  formularioValido(): boolean {
    return !!(
      this.form.nro_doc_ide_pac && this.form.nro_doc_ide_pac.trim() &&
      this.form.ape_nom_pac && this.form.ape_nom_pac.trim() &&
      this.form.fecha_salida_obligatoria &&
      this.form.pertenece_al_area !== undefined
    );
  }

  confirmar(): void {
    if (!this.formularioValido()) return;

    // Convertir datetime-local a ISO con segundos para Joi.isoDate()
    const fechaIso = `${this.form.fecha_salida_obligatoria}:00`;

    const payload: IngresoManualPayload = {
      ...this.form,
      nro_doc_ide_pac: this.form.nro_doc_ide_pac.trim(),
      ape_nom_pac: this.form.ape_nom_pac.trim(),
      nro_his_cli_cas: this.form.nro_his_cli_cas?.trim() || undefined,
      des_ser_cama: this.form.des_ser_cama?.trim() || undefined,
      motivo: this.form.motivo?.trim() || undefined,
      fecha_salida_obligatoria: fechaIso,
    };

    this.dialogRef.close(payload);
  }
}
