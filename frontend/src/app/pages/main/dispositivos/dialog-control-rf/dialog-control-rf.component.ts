import { Component, Inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatDialogRef, MAT_DIALOG_DATA, MatDialogModule } from '@angular/material/dialog';

export interface ControlRfData {
  id: number;
  habitacion_id: number | null;
  cama: string;
  dip_config: boolean[];
  descripcion: string;
}

export interface DialogRfInput {
  control: ControlRfData | null;
  habitacionesDisponibles: number[];
}

@Component({
  selector: 'app-dialog-control-rf',
  standalone: true,
  imports: [CommonModule, FormsModule, MatDialogModule],
  template: `
    <div class="dialog-wrapper">
      <div class="dialog-header">
        <i class="bi bi-broadcast-pin"></i>
        <h2>{{ data?.control ? 'Editar' : 'Nuevo' }} Control RF</h2>
      </div>

      <div class="dialog-body">
        <div class="form-row">
          <div class="form-group">
            <label>Habitacion *</label>
            <select [(ngModel)]="form.habitacion_id">
              <option [ngValue]="null" disabled>Seleccionar</option>
              @for (hab of habitaciones; track hab) {
                <option [ngValue]="hab">Hab. {{ hab }}</option>
              }
            </select>
          </div>
          <div class="form-group">
            <label>Cama *</label>
            <select [(ngModel)]="form.cama">
              <option value="" disabled>Seleccionar</option>
              <option value="A">Cama A</option>
              <option value="B">Cama B</option>
              <option value="C">Cama C</option>
              <option value="D">Cama D</option>
              <option value="Bano">Bano</option>
            </select>
          </div>
        </div>

        <!-- DIP Switch Visual 8-bit -->
        <div class="form-group">
          <label>Configuracion DIP Switch (8 bit)</label>
          <div class="dip-container">
            <div class="dip-body">
              <div class="dip-label-on">ON</div>
              <div class="dip-switches">
                @for (pos of dipPositions; track pos) {
                  <div class="dip-switch" [class.active]="form.dip_config[pos]"
                       (click)="toggleDip(pos)">
                    <div class="dip-slider"
                         [class.on]="form.dip_config[pos]">
                    </div>
                  </div>
                }
              </div>
              <div class="dip-numbers">
                @for (pos of dipPositions; track pos) {
                  <span>{{ pos + 1 }}</span>
                }
              </div>
            </div>
            <div class="dip-code">
              Codigo: {{ getDipCode() }}
            </div>
          </div>
        </div>

        <div class="form-group">
          <label>Descripcion</label>
          <input type="text" [(ngModel)]="form.descripcion"
                 placeholder="Nota opcional..." maxlength="255">
        </div>
      </div>

      <div class="dialog-footer">
        <button class="btn-cancel" (click)="dialogRef.close()">Cancelar</button>
        <button class="btn-save" (click)="guardar()"
                [disabled]="!form.habitacion_id || !form.cama">
          <i class="bi bi-check-lg"></i> Guardar
        </button>
      </div>
    </div>
  `,
  styleUrl: '../../contenido-tv/dialog-efemeride/dialog-efemeride.component.scss',
  styles: [`
    .dip-container {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 8px;
      padding: 16px;
      background: #F8FAFC;
      border-radius: 8px;
      border: 1.5px solid #E2E8F0;
    }
    .dip-body {
      background: #1E293B;
      border-radius: 6px;
      padding: 10px 16px 8px;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 4px;
      min-width: 140px;
    }
    .dip-label-on {
      color: #94A3B8;
      font-size: 10px;
      font-weight: 700;
      letter-spacing: 1px;
      text-transform: uppercase;
    }
    .dip-switches {
      display: flex;
      gap: 5px;
    }
    .dip-switch {
      width: 22px;
      height: 38px;
      background: #334155;
      border-radius: 4px;
      cursor: pointer;
      position: relative;
      transition: background 0.15s;
      border: 1px solid #475569;
    }
    .dip-switch:hover {
      background: #3B4C63;
    }
    .dip-switch.active {
      background: #1E40AF;
      border-color: #3B82F6;
    }
    .dip-slider {
      width: 16px;
      height: 14px;
      background: #CBD5E1;
      border-radius: 3px;
      position: absolute;
      left: 50%;
      transform: translateX(-50%);
      bottom: 4px;
      transition: all 0.15s;
    }
    .dip-slider.on {
      bottom: auto;
      top: 4px;
      background: #60A5FA;
    }
    .dip-numbers {
      display: flex;
      gap: 5px;
    }
    .dip-numbers span {
      width: 22px;
      text-align: center;
      color: #94A3B8;
      font-size: 10px;
      font-weight: 600;
    }
    .dip-code {
      font-size: 13px;
      color: #64748B;
      font-family: monospace;
      font-weight: 600;
    }
  `]
})
export class DialogControlRfComponent {
  readonly dipPositions = [0, 1, 2, 3, 4, 5, 6, 7];
  readonly defaultDip: boolean[] = [false, false, false, false, false, false, false, false];

  habitaciones: number[] = [];

  form: ControlRfData = {
    id: 0,
    habitacion_id: null,
    cama: '',
    dip_config: [...this.defaultDip],
    descripcion: ''
  };

  constructor(
    public dialogRef: MatDialogRef<DialogControlRfComponent>,
    @Inject(MAT_DIALOG_DATA) public data: DialogRfInput | null
  ) {
    this.habitaciones = data?.habitacionesDisponibles || [];

    if (data?.control) {
      const ctrl = data.control;
      // Migrate old 4-position configs to 8 by padding with false
      let config = [...(ctrl.dip_config || this.defaultDip)];
      while (config.length < 8) config.push(false);
      this.form = { ...ctrl, dip_config: config };
    }
  }

  toggleDip(index: number): void {
    this.form.dip_config[index] = !this.form.dip_config[index];
  }

  getDipCode(): string {
    return this.form.dip_config.map(v => v ? '1' : '0').join('');
  }

  guardar(): void {
    this.dialogRef.close(this.form);
  }
}
