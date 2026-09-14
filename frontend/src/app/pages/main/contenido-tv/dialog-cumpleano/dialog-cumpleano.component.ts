import { Component, Inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatDialogRef, MAT_DIALOG_DATA, MatDialogModule } from '@angular/material/dialog';
import { Cumpleano } from '../../../../../services/data.service';

@Component({
  selector: 'app-dialog-cumpleano',
  standalone: true,
  imports: [CommonModule, FormsModule, MatDialogModule],
  template: `
    <div class="dialog-wrapper">
      <div class="dialog-header">
        <i class="bi bi-balloon-heart"></i>
        <h2>{{ data ? 'Editar' : 'Nuevo' }} Cumpleaños</h2>
      </div>

      <div class="dialog-body">
        <div class="form-group">
          <label>Nombre completo *</label>
          <input type="text" [(ngModel)]="form.nombre" maxlength="255" placeholder="Ej: María García López">
        </div>

        <div class="form-group">
          <label>Cargo</label>
          <select [(ngModel)]="form.cargo">
            <option value="">Seleccionar...</option>
            @for (c of cargos; track c) {
              <option [value]="c">{{ c }}</option>
            }
          </select>
        </div>

        <div class="form-row">
          <div class="form-group">
            <label>Día *</label>
            <select [(ngModel)]="form.dia">
              @for (d of dias; track d) {
                <option [ngValue]="d">{{ d }}</option>
              }
            </select>
          </div>
          <div class="form-group">
            <label>Mes *</label>
            <select [(ngModel)]="form.mes">
              @for (m of meses; track m.value) {
                <option [ngValue]="m.value">{{ m.label }}</option>
              }
            </select>
          </div>
        </div>
      </div>

      <div class="dialog-footer">
        <button class="btn-cancel" (click)="dialogRef.close()">Cancelar</button>
        <button class="btn-save" (click)="guardar()" [disabled]="!form.nombre || !form.dia || !form.mes">
          <i class="bi bi-check-lg"></i> Guardar
        </button>
      </div>
    </div>
  `,
  styleUrl: '../dialog-efemeride/dialog-efemeride.component.scss'
})
export class DialogCumpleanoComponent {
  form: any = { nombre: '', cargo: '', dia: 1, mes: 1 };

  dias = Array.from({ length: 31 }, (_, i) => i + 1);
  meses = [
    { value: 1, label: 'Enero' }, { value: 2, label: 'Febrero' },
    { value: 3, label: 'Marzo' }, { value: 4, label: 'Abril' },
    { value: 5, label: 'Mayo' }, { value: 6, label: 'Junio' },
    { value: 7, label: 'Julio' }, { value: 8, label: 'Agosto' },
    { value: 9, label: 'Septiembre' }, { value: 10, label: 'Octubre' },
    { value: 11, label: 'Noviembre' }, { value: 12, label: 'Diciembre' },
  ];

  cargos = [
    'Médico', 'Enfermera', 'Técnico en Enfermería', 'Obstetra',
    'Nutricionista', 'Psicólogo', 'Tecnólogo Médico', 'Farmacéutico',
    'Trabajador Social', 'Administrativo', 'Otro'
  ];

  constructor(
    public dialogRef: MatDialogRef<DialogCumpleanoComponent>,
    @Inject(MAT_DIALOG_DATA) public data: Cumpleano | null
  ) {
    if (data) {
      this.form = { ...data };
    }
  }

  guardar(): void {
    this.dialogRef.close(this.form);
  }
}
