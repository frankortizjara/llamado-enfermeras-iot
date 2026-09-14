import { Component, Inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatDialogRef, MAT_DIALOG_DATA, MatDialogModule } from '@angular/material/dialog';
import { Cama, Habitacion } from '../../../../../services/data.service';

export interface DialogCambiarCamaData {
  camaOrigen: Cama;
  habitacionOrigenNombre: string;
  habitaciones: Habitacion[];
}

interface CamaSeleccionable {
  id: number;
  etiqueta: string;
  paciente: string;
  ocupada: boolean;
  deshabilitada: boolean;
  motivoDeshabilitada?: string;
}

@Component({
  selector: 'app-dialog-cambiar-cama',
  standalone: true,
  imports: [CommonModule, FormsModule, MatDialogModule],
  template: `
    <div class="dialog-wrapper">
      <div class="dialog-header">
        <i class="bi bi-arrow-left-right"></i>
        <h2>Mover paciente</h2>
      </div>

      <div class="dialog-body">
        <div class="info-origen">
          <strong>Paciente:</strong> {{ data.camaOrigen.paciente || '(sin paciente)' }}<br>
          <strong>Cama actual:</strong>
          {{ data.habitacionOrigenNombre }} - {{ data.camaOrigen.nombre }}
        </div>

        <div class="form-group">
          <label>Mover a:</label>
          <select [(ngModel)]="camaDestinoId">
            <option [ngValue]="null">-- Seleccione una cama --</option>
            @for (cama of camasDisponibles; track cama.id) {
              <option [ngValue]="cama.id" [disabled]="cama.deshabilitada"
                      [title]="cama.motivoDeshabilitada || ''">
                {{ cama.etiqueta }} - {{ cama.ocupada ? cama.paciente : '(libre)' }}{{ cama.deshabilitada ? ' [' + cama.motivoDeshabilitada + ']' : '' }}
              </option>
            }
          </select>
        </div>

        @if (camaDestinoSeleccionada && camaDestinoSeleccionada.ocupada) {
          <div class="warning-swap">
            <i class="bi bi-exclamation-triangle"></i>
            La cama destino está ocupada por
            <strong>{{ camaDestinoSeleccionada.paciente }}</strong>.
            Se hará un <strong>intercambio</strong>: ambos pacientes cambiarán de cama.
          </div>
        }

        <div class="form-group">
          <label>Motivo (opcional):</label>
          <textarea [(ngModel)]="motivo" rows="2" maxlength="500"
                    placeholder="Ej: aislamiento, comodidad del paciente, etc."></textarea>
        </div>

        <div class="info-aclaracion">
          <i class="bi bi-info-circle"></i>
          El cambio quedará marcado como <strong>manual (naranja)</strong> hasta que
          la próxima sincronización con EsSi lo confirme.
        </div>
      </div>

      <div class="dialog-footer">
        <button class="btn-cancel" (click)="dialogRef.close()">Cancelar</button>
        <button class="btn-save" (click)="confirmar()" [disabled]="!camaDestinoId">
          <i class="bi bi-check-lg"></i>
          {{ camaDestinoSeleccionada?.ocupada ? 'Intercambiar' : 'Mover' }}
        </button>
      </div>
    </div>
  `,
  styles: [`
    .dialog-wrapper { padding: 0; min-width: 480px; max-width: 600px; }
    .dialog-header { padding: 20px 24px; background: linear-gradient(135deg, #f97316 0%, #ea580c 100%); color: white; display: flex; align-items: center; gap: 12px; }
    .dialog-header i { font-size: 24px; }
    .dialog-header h2 { margin: 0; font-size: 18px; font-weight: 600; }
    .dialog-body { padding: 24px; }
    .info-origen { background: #f3f4f6; padding: 12px; border-radius: 6px; margin-bottom: 16px; line-height: 1.6; }
    .form-group { margin-bottom: 16px; }
    .form-group label { display: block; margin-bottom: 6px; font-weight: 500; color: #374151; }
    .form-group select, .form-group textarea {
      width: 100%; padding: 8px 12px; border: 1px solid #d1d5db; border-radius: 6px;
      font-size: 14px; font-family: inherit;
    }
    .warning-swap { background: #fef3c7; border-left: 4px solid #f59e0b; padding: 10px 14px; margin-bottom: 16px; border-radius: 4px; color: #78350f; }
    .info-aclaracion { background: #fff7ed; border-left: 4px solid #f97316; padding: 10px 14px; border-radius: 4px; color: #7c2d12; font-size: 13px; }
    .info-aclaracion i, .warning-swap i { margin-right: 6px; }
    .dialog-footer { display: flex; justify-content: flex-end; gap: 8px; padding: 16px 24px; border-top: 1px solid #e5e7eb; background: #fafafa; }
    .btn-cancel, .btn-save { padding: 8px 16px; border-radius: 6px; border: none; cursor: pointer; font-size: 14px; font-weight: 500; }
    .btn-cancel { background: #e5e7eb; color: #374151; }
    .btn-cancel:hover { background: #d1d5db; }
    .btn-save { background: #f97316; color: white; }
    .btn-save:hover:not(:disabled) { background: #ea580c; }
    .btn-save:disabled { background: #d1d5db; cursor: not-allowed; }
  `]
})
export class DialogCambiarCamaComponent {
  camaDestinoId: number | null = null;
  motivo: string = '';
  camasDisponibles: CamaSeleccionable[] = [];

  constructor(
    public dialogRef: MatDialogRef<DialogCambiarCamaComponent>,
    @Inject(MAT_DIALOG_DATA) public data: DialogCambiarCamaData
  ) {
    this.construirListaCamasDestino();
  }

  get camaDestinoSeleccionada(): CamaSeleccionable | null {
    return this.camasDisponibles.find(c => c.id === this.camaDestinoId) || null;
  }

  private construirListaCamasDestino(): void {
    const lista: CamaSeleccionable[] = [];
    for (const hab of this.data.habitaciones) {
      for (const cama of hab.camas) {
        if (cama.id === this.data.camaOrigen.id) continue;

        let deshabilitada = false;
        let motivo: string | undefined;
        if (cama.fecha_alta_programada) {
          deshabilitada = true;
          motivo = 'alta programada';
        } else if (cama.marcado_para_eliminar) {
          deshabilitada = true;
          motivo = 'paciente expirado';
        }

        lista.push({
          id: cama.id,
          etiqueta: `${hab.nombre} - ${cama.nombre}`,
          paciente: cama.paciente,
          ocupada: !!(cama.paciente && cama.paciente.trim()),
          deshabilitada,
          motivoDeshabilitada: motivo,
        });
      }
    }
    this.camasDisponibles = lista;
  }

  confirmar(): void {
    if (!this.camaDestinoId) return;
    this.dialogRef.close({
      id_destino: this.camaDestinoId,
      motivo: this.motivo.trim() || null,
    });
  }
}
