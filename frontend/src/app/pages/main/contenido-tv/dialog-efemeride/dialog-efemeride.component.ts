import { Component, Inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatDialogRef, MAT_DIALOG_DATA, MatDialogModule } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatButtonModule } from '@angular/material/button';
import { Efemeride } from '../../../../../services/data.service';

@Component({
  selector: 'app-dialog-efemeride',
  standalone: true,
  imports: [
    CommonModule, FormsModule, MatDialogModule,
    MatFormFieldModule, MatInputModule, MatSelectModule, MatButtonModule
  ],
  template: `
    <div class="dialog-wrapper">
      <div class="dialog-header">
        <i class="bi bi-calendar-heart"></i>
        <h2>{{ data ? 'Editar' : 'Nueva' }} Efeméride</h2>
      </div>

      <div class="dialog-body">
        <div class="form-group">
          <label>Título *</label>
          <input type="text" [(ngModel)]="form.titulo" maxlength="255" placeholder="Ej: Día Mundial de la Salud">
        </div>

        <div class="form-group">
          <label>Descripción</label>
          <textarea [(ngModel)]="form.descripcion" rows="3" placeholder="Descripción breve de la efeméride"></textarea>
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

        <div class="form-group">
          <label>Tipo</label>
          <select [(ngModel)]="form.tipo">
            <option value="salud">Salud</option>
            <option value="peru">Perú</option>
            <option value="internacional">Internacional</option>
          </select>
        </div>

        <div class="form-group">
          <label>Icono</label>
          <div class="icon-grid">
            @for (ic of iconosDisponibles; track ic.clase) {
              <button type="button"
                class="icon-option"
                [class.selected]="form.icono === ic.clase"
                (click)="form.icono = ic.clase"
                [title]="ic.nombre">
                <i [class]="ic.clase"></i>
              </button>
            }
          </div>
          @if (form.icono) {
            <div class="icon-selected">
              <i [class]="form.icono"></i>
              <span>{{ form.icono }}</span>
              <button type="button" class="btn-clear" (click)="form.icono = ''">x</button>
            </div>
          }
        </div>
      </div>

      <div class="dialog-footer">
        <button class="btn-cancel" (click)="dialogRef.close()">Cancelar</button>
        <button class="btn-save" (click)="guardar()" [disabled]="!form.titulo || !form.dia || !form.mes">
          <i class="bi bi-check-lg"></i> Guardar
        </button>
      </div>
    </div>
  `,
  styleUrl: './dialog-efemeride.component.scss'
})
export class DialogEfemerideComponent {
  form: any = {
    titulo: '', descripcion: '', dia: 1, mes: 1, tipo: 'salud', icono: ''
  };

  dias = Array.from({ length: 31 }, (_, i) => i + 1);
  meses = [
    { value: 1, label: 'Enero' }, { value: 2, label: 'Febrero' },
    { value: 3, label: 'Marzo' }, { value: 4, label: 'Abril' },
    { value: 5, label: 'Mayo' }, { value: 6, label: 'Junio' },
    { value: 7, label: 'Julio' }, { value: 8, label: 'Agosto' },
    { value: 9, label: 'Septiembre' }, { value: 10, label: 'Octubre' },
    { value: 11, label: 'Noviembre' }, { value: 12, label: 'Diciembre' },
  ];

  iconosDisponibles = [
    { clase: 'bi bi-heart-pulse', nombre: 'Salud' },
    { clase: 'bi bi-hospital', nombre: 'Hospital' },
    { clase: 'bi bi-hospital-fill', nombre: 'Hospital' },
    { clase: 'bi bi-plus-circle', nombre: 'Cruz' },
    { clase: 'bi bi-shield-plus', nombre: 'Escudo' },
    { clase: 'bi bi-shield-check', nombre: 'Protección' },
    { clase: 'bi bi-bandaid', nombre: 'Curita' },
    { clase: 'bi bi-capsule', nombre: 'Cápsula' },
    { clase: 'bi bi-droplet', nombre: 'Gota' },
    { clase: 'bi bi-droplet-fill', nombre: 'Gota' },
    { clase: 'bi bi-thermometer-half', nombre: 'Termómetro' },
    { clase: 'bi bi-heart', nombre: 'Corazón' },
    { clase: 'bi bi-heart-fill', nombre: 'Corazón' },
    { clase: 'bi bi-heart-pulse-fill', nombre: 'Cardio' },
    { clase: 'bi bi-activity', nombre: 'Actividad' },
    { clase: 'bi bi-lungs', nombre: 'Pulmones' },
    { clase: 'bi bi-eye', nombre: 'Vista' },
    { clase: 'bi bi-ear', nombre: 'Audición' },
    { clase: 'bi bi-person-walking', nombre: 'Fisioterapia' },
    { clase: 'bi bi-puzzle', nombre: 'Alzheimer' },
    { clase: 'bi bi-lightning', nombre: 'Epilepsia' },
    { clase: 'bi bi-bug', nombre: 'Virus' },
    { clase: 'bi bi-globe', nombre: 'Mundial' },
    { clase: 'bi bi-calendar-heart', nombre: 'Calendario' },
    { clase: 'bi bi-gender-female', nombre: 'Mujer' },
    { clase: 'bi bi-people', nombre: 'Personas' },
    { clase: 'bi bi-emoji-smile', nombre: 'Sonrisa' },
    { clase: 'bi bi-emoji-smile-fill', nombre: 'Sonrisa' },
    { clase: 'bi bi-award', nombre: 'Premio' },
    { clase: 'bi bi-star-fill', nombre: 'Estrella' },
    { clase: 'bi bi-ribbon-fill', nombre: 'Listón' },
    { clase: 'bi bi-life-preserver', nombre: 'Salvavidas' },
    { clase: 'bi bi-wind', nombre: 'Respiración' },
    { clase: 'bi bi-soundwave', nombre: 'Ecografía' },
    { clase: 'bi bi-radioactive', nombre: 'Radiología' },
    { clase: 'bi bi-universal-access', nombre: 'Accesibilidad' },
    { clase: 'bi bi-person-badge', nombre: 'Profesional' },
    { clase: 'bi bi-tree', nombre: 'Naturaleza' },
    { clase: 'bi bi-apple', nombre: 'Nutrición' },
    { clase: 'bi bi-chat-heart', nombre: 'Psicología' },
  ];

  constructor(
    public dialogRef: MatDialogRef<DialogEfemerideComponent>,
    @Inject(MAT_DIALOG_DATA) public data: Efemeride | null
  ) {
    if (data) {
      this.form = { ...data };
    }
  }

  guardar(): void {
    this.dialogRef.close(this.form);
  }
}
