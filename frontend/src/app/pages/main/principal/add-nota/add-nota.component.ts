import { Component, Inject, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { ToastrService } from 'ngx-toastr';
import { DataService } from '../../../../../services/data.service';
import 'moment-timezone';
import moment from 'moment';
import { HabitacionModelo } from '../../../../../models/apiModelo';

interface NotaChip {
  code: string;
  label: string;
  icon: string;
  color: string;
}

interface CambioNota {
  id: number;
  nota: string | null;
  hora: string | null;
}

@Component({
  selector: 'app-add-nota',
  standalone: true,
  imports: [
    FormsModule,
    MatButtonModule,
    MatDialogModule,
  ],
  templateUrl: './add-nota.component.html',
  styleUrl: './add-nota.component.scss'
})
export class AddNotaComponent implements OnInit {
  public lstDatos: any[] = [];
  public lstHabitaciones: HabitacionModelo[] = [];
  public habitacionSeleccionada: any = null;
  public cambios: CambioNota[] = [];

  public notaChips: NotaChip[] = [
    { code: 'NPO',  label: 'Nada por v\u00eda oral',                    icon: 'bi bi-x-circle-fill',   color: '#EF3038' },
    { code: 'SOP',  label: 'Sala de operaciones',                  icon: 'bi bi-hospital-fill',   color: '#7B2FBE' },
    { code: 'TAC',  label: 'Tomograf\u00eda',                           icon: 'bi bi-disc-fill',       color: '#E67700' },
    { code: 'RMN',  label: 'Resonancia magn\u00e9tica',                 icon: 'bi bi-magnet-fill',     color: '#0D6EFD' },
    { code: 'ECO',  label: 'Ecograf\u00eda',                            icon: 'bi bi-soundwave',       color: '#28A745' },
    { code: 'URVI', label: 'Unidad radiol\u00f3gica intervencionista',   icon: 'bi bi-radioactive',     color: '#17A2B8' },
  ];

  constructor(
    private dataService: DataService,
    public dialogRef: MatDialogRef<AddNotaComponent>,
    private toastr: ToastrService,
    @Inject(MAT_DIALOG_DATA) public data: { habitaciones: HabitacionModelo[], preseleccionada?: string },
  ) {
    this.lstHabitaciones = data.habitaciones;
  }

  ngOnInit(): void {
    moment.locale('es');
    moment().tz('America/Lima');

    // Si viene una habitación preseleccionada, seleccionarla automáticamente
    if (this.data.preseleccionada) {
      const hab = this.lstHabitaciones.find(h => h.nombre === this.data.preseleccionada);
      if (hab) {
        this.habitacionSeleccionada = hab;
        this.camaHabitacion(hab);
      }
    }
  }

  camaHabitacion(habitacionSeleccionada: any): void {
    this.lstDatos = [];
    this.cambios = [];

    if (habitacionSeleccionada != null) {
      for (const itm of this.lstHabitaciones) {
        if (itm.nombre === habitacionSeleccionada.nombre) {
          this.lstDatos = itm.camas || [];
        }
      }
    }
  }

  selectChip(camaId: number, code: string): void {
    const current = this.getNotaValue(camaId) || this.getCamaNota(camaId);
    const parts = current ? current.split('-').filter((p: string) => p.trim()) : [];

    if (parts.includes(code)) {
      // Deseleccionar: quitar el chip
      const nuevas = parts.filter((p: string) => p !== code);
      this.setCambio(camaId, 'nota', nuevas.join('-'));
    } else {
      // Seleccionar: agregar el chip
      parts.push(code);
      this.setCambio(camaId, 'nota', parts.join('-'));
    }
  }

  isChipActive(camaId: number, code: string): boolean {
    const current = this.getNotaValue(camaId) || this.getCamaNota(camaId);
    if (!current) return false;
    const parts = current.split('-').map((p: string) => p.trim());
    return parts.includes(code);
  }

  private getCamaNota(camaId: number): string {
    const cama = this.lstDatos.find((c: any) => c.id === camaId);
    return cama?.nota || '';
  }

  onNotaInput(camaId: number, event: Event): void {
    const value = (event.target as HTMLInputElement).value;
    this.setCambio(camaId, 'nota', value.toUpperCase());
  }

  onHoraInput(camaId: number, event: Event): void {
    const value = (event.target as HTMLInputElement).value;
    this.setCambio(camaId, 'hora', value);
  }

  private setCambio(camaId: number, campo: 'nota' | 'hora', valor: string): void {
    const index = this.cambios.findIndex(c => c.id === camaId);
    if (index === -1) {
      const nuevo: CambioNota = { id: camaId, nota: null, hora: null };
      nuevo[campo] = valor;
      this.cambios.push(nuevo);
    } else {
      this.cambios[index][campo] = valor;
    }
  }

  getNotaValue(camaId: number): string {
    const cambio = this.cambios.find(c => c.id === camaId);
    return cambio?.nota ?? '';
  }

  getHoraValue(camaId: number): string {
    const cambio = this.cambios.find(c => c.id === camaId);
    return cambio?.hora ?? '';
  }

  convertir(fecha?: string): string {
    return fecha ? moment(fecha).format('HH:mm') : '';
  }

  limpiarNota(camaId: number): void {
    const confirmado = window.confirm('¿Estás seguro de que quieres eliminar esta nota?');
    if (!confirmado) return;

    this.dataService.editarNota(camaId, '', '').subscribe({
      next: () => {
        const cama = this.lstDatos.find((c: any) => c.id === camaId);
        if (cama) {
          cama.nota = '';
          cama.fecha_nota = '';
        }
        this.cambios = this.cambios.filter(c => c.id !== camaId);
        this.toastr.success('Nota eliminada', '\u00c9xito', {
          timeOut: 2000,
          positionClass: 'toast-top-center',
          progressBar: true,
        });
      },
      error: () => {
        this.toastr.error('Error al eliminar nota', 'Error', {
          timeOut: 2000,
          positionClass: 'toast-top-center',
          progressBar: true,
        });
      }
    });
  }

  guardar(): void {
    if (this.cambios.length === 0) {
      this.salir(true);
      return;
    }

    let guardados = 0;
    const total = this.cambios.length;

    for (const cambio of this.cambios) {
      const cama = this.lstDatos.find((c: any) => c.id === cambio.id);
      const nota = cambio.nota ?? cama?.nota ?? '';
      const hora = cambio.hora ?? this.convertir(cama?.fecha_nota) ?? '';

      if (hora && !nota) {
        this.toastr.warning(
          'No puedes establecer hora sin nota.',
          'Advertencia',
          { timeOut: 2000, positionClass: 'toast-top-center', progressBar: true }
        );
        return;
      }

      let fechaCompleta = '';
      if (nota && hora) {
        const dia = moment().tz('America/Lima').format('YYYY-MM-DD');
        fechaCompleta = `${dia}T${hora}`;
      }

      this.dataService.editarNota(cambio.id, nota, fechaCompleta).subscribe({
        next: () => {
          guardados++;
          if (guardados === total) {
            this.toastr.success('Cambios guardados exitosamente', '\u00c9xito', {
              timeOut: 2000,
              positionClass: 'toast-top-center',
              progressBar: true,
            });
            this.salir(true);
          }
        },
        error: () => {
          this.toastr.error('Error al guardar nota', 'Error', {
            timeOut: 2000,
            positionClass: 'toast-top-center',
            progressBar: true,
          });
        }
      });
    }
  }

  salir(status: any): void {
    this.dialogRef.close(status);
  }
}
