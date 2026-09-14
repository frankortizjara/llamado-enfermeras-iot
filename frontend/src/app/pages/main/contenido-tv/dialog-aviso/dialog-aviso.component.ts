import { Component, Inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatDialogRef, MAT_DIALOG_DATA, MatDialogModule } from '@angular/material/dialog';
import { Aviso } from '../../../../../services/data.service';

@Component({
  selector: 'app-dialog-aviso',
  standalone: true,
  imports: [CommonModule, FormsModule, MatDialogModule],
  template: `
    <div class="dialog-wrapper">
      <div class="dialog-header">
        <i class="bi bi-megaphone"></i>
        <h2>{{ data ? 'Editar' : 'Nuevo' }} Aviso</h2>
      </div>

      <div class="dialog-body">
        <div class="form-group">
          <label>Título *</label>
          <input type="text" [(ngModel)]="form.titulo" maxlength="255" placeholder="Ej: Reunión de personal">
        </div>

        <div class="form-group">
          <label>Mensaje *</label>
          <textarea [(ngModel)]="form.mensaje" rows="4" placeholder="Escriba el mensaje del aviso..."></textarea>
        </div>

        <div class="form-row">
          <div class="form-group">
            <label>Prioridad</label>
            <select [(ngModel)]="form.prioridad">
              <option value="normal">Normal</option>
              <option value="importante">Importante</option>
              <option value="muy_importante">Muy Importante</option>
            </select>
          </div>
          <div class="form-group">
            <label>Modo de visualización</label>
            <select [(ngModel)]="form.modo_display">
              <option value="periodico">Periódico (cada cierto tiempo)</option>
              <option value="permanente">Permanente (banner fijo)</option>
            </select>
          </div>
        </div>

        <div class="form-row">
          <div class="form-group">
            <label>Fecha inicio</label>
            <input type="date" [(ngModel)]="form.fecha_inicio">
          </div>
          <div class="form-group">
            <label>Fecha fin (opcional)</label>
            <input type="date" [(ngModel)]="form.fecha_fin">
          </div>
        </div>
      </div>

      <div class="dialog-footer">
        <button class="btn-cancel" (click)="dialogRef.close()">Cancelar</button>
        <button class="btn-save" (click)="guardar()" [disabled]="!form.titulo || !form.mensaje">
          <i class="bi bi-check-lg"></i> Guardar
        </button>
      </div>
    </div>
  `,
  styleUrl: '../dialog-efemeride/dialog-efemeride.component.scss'
})
export class DialogAvisoComponent {
  form: any = {
    titulo: '', mensaje: '', prioridad: 'normal', modo_display: 'periodico',
    fecha_inicio: '', fecha_fin: ''
  };

  constructor(
    public dialogRef: MatDialogRef<DialogAvisoComponent>,
    @Inject(MAT_DIALOG_DATA) public data: Aviso | null
  ) {
    if (data) {
      this.form = { ...data, modo_display: data.modo_display || 'periodico' };
    }
  }

  guardar(): void {
    this.dialogRef.close(this.form);
  }
}
