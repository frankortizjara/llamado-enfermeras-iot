import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';
import { TvContentItem, AlertaOverlayData } from '../../../core/services/tv-content.service';
import { Efemeride, Cumpleano, Aviso } from '../../../../services/data.service';

@Component({
  selector: 'app-tv-overlay',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './tv-overlay.component.html',
  styleUrl: './tv-overlay.component.scss'
})
export class TvOverlayComponent {
  /** Contenido periódico (overlay central) */
  @Input() contenido: TvContentItem | null = null;

  /** Avisos permanentes (banner superior) */
  @Input() avisosPermanentes: Aviso[] = [];

  /** Duración del overlay en segundos (para progress bar) */
  @Input() duracionOverlay: number = 15;

  private mesesNombres = [
    '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  get esEfemeride(): boolean {
    return this.contenido?.tipo === 'efemeride';
  }

  get esCumpleano(): boolean {
    return this.contenido?.tipo === 'cumpleano';
  }

  get esAviso(): boolean {
    return this.contenido?.tipo === 'aviso';
  }

  get esAlerta(): boolean {
    return this.contenido?.tipo === 'alerta';
  }

  get efemeride(): Efemeride | null {
    return this.esEfemeride ? this.contenido!.data as Efemeride : null;
  }

  get listaCumpleanos(): Cumpleano[] {
    return this.esCumpleano ? this.contenido!.data as Cumpleano[] : [];
  }

  get aviso(): Aviso | null {
    return this.esAviso ? this.contenido!.data as Aviso : null;
  }

  get alerta(): AlertaOverlayData | null {
    return this.esAlerta ? this.contenido!.data as AlertaOverlayData : null;
  }

  get fechaEfemeride(): string {
    if (!this.efemeride) return '';
    return `${this.efemeride.dia} de ${this.mesesNombres[this.efemeride.mes]}`;
  }

  get tipoEfemerideBadge(): string {
    if (!this.efemeride) return '';
    switch (this.efemeride.tipo) {
      case 'peru': return 'Perú';
      case 'internacional': return 'Internacional';
      default: return 'Salud';
    }
  }

  get prioridadClase(): string {
    if (!this.aviso) return '';
    return `aviso-${this.aviso.prioridad}`;
  }

  get prioridadTexto(): string {
    if (!this.aviso) return '';
    switch (this.aviso.prioridad) {
      case 'muy_importante': return 'MUY IMPORTANTE';
      case 'importante': return 'IMPORTANTE';
      default: return 'AVISO';
    }
  }

  getPrioridadColor(prioridad: string): string {
    switch (prioridad) {
      case 'muy_importante': return '#DC2626';
      case 'importante': return '#D97706';
      default: return '#1E40AF';
    }
  }
}
