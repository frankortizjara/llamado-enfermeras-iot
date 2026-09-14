import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Subject, takeUntil } from 'rxjs';
import { MatTabsModule } from '@angular/material/tabs';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatDialog } from '@angular/material/dialog';
import { ToastrService } from 'ngx-toastr';

import { DataService, Efemeride, Cumpleano, Aviso, ConfigTv, ConfiguracionSistemaItem } from '../../../../services/data.service';
import { AuthService } from '../../../../services/auth.service';
import { DialogEfemerideComponent } from './dialog-efemeride/dialog-efemeride.component';
import { DialogCumpleanoComponent } from './dialog-cumpleano/dialog-cumpleano.component';
import { DialogAvisoComponent } from './dialog-aviso/dialog-aviso.component';
import { DialogPantallaTvComponent, PantallaTvData } from './dialog-pantalla-tv/dialog-pantalla-tv.component';

@Component({
  selector: 'app-contenido-tv',
  standalone: true,
  imports: [CommonModule, FormsModule, MatTabsModule, MatButtonModule, MatIconModule],
  templateUrl: './contenido-tv.component.html',
  styleUrl: './contenido-tv.component.scss'
})
export class ContenidoTvComponent implements OnInit, OnDestroy {
  private destroy$ = new Subject<void>();

  efemerides: Efemeride[] = [];
  cumpleanos: Cumpleano[] = [];
  avisos: Aviso[] = [];
  pantallasTv: PantallaTvData[] = [];
  esJefeArea = false;
  esAdmin = false;
  // Sub-permisos de contenido TV
  verEfemerides = true;
  verCumpleanos = true;
  verAvisos = true;
  verAudio = false;
  verConfig = false;
  configTv: ConfigTv = {
    intervalo_efemerides: '40',
    intervalo_cumpleanos: '30',
    intervalo_avisos: '15',
    duracion_overlay: '15',
    tamano_fuente_tv: '100',
    audio_habilitado: 'true',
    audio_volumen: '80',
    audio_duracion_alerta: '0',
    audio_duracion_emergencia: '0',
    audio_sonido_alerta: 'Beep01.mp3',
    audio_sonido_emergencia: 'Beep02.mp3'
  };

  // Audio
  sonidosPreset: string[] = [];
  sonidosCustom: string[] = [];
  audioPreview: HTMLAudioElement | null = null;
  subiendoAudio = false;

  // Configuracion del sistema (Fase 0)
  configSistema: ConfiguracionSistemaItem[] = [];
  configSistemaMap: Record<string, ConfiguracionSistemaItem> = {};
  guardandoConfigSistema: Record<string, boolean> = {};

  private mesesNombres = [
    '', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
  ];

  constructor(
    private dataService: DataService,
    private authService: AuthService,
    private dialog: MatDialog,
    private toastr: ToastrService
  ) {}

  ngOnInit(): void {
    const usuario = this.authService.getUsuario();
    this.esJefeArea = ['admin', 'jefe_area'].includes(usuario?.rol || '');
    this.esAdmin = usuario?.rol === 'admin';

    // Sub-permisos de contenido TV
    const permisos = usuario?.permisos;
    const tienePermisos = permisos && Object.keys(permisos).length > 0;
    if (tienePermisos) {
      this.verEfemerides = permisos.contenido_tv_efemerides !== false;
      this.verCumpleanos = permisos.contenido_tv_cumpleanos !== false;
      this.verAvisos = permisos.contenido_tv_avisos !== false;
      this.verAudio = !!permisos.contenido_tv_audio;
      this.verConfig = !!permisos.contenido_tv_config;
    } else {
      // Fallback: jefe_area/admin ven todo, otros solo efemerides/cumpleanos/avisos
      this.verAudio = this.esJefeArea;
      this.verConfig = this.esJefeArea;
    }

    this.cargarEfemerides();
    this.cargarCumpleanos();
    this.cargarAvisos();
    if (this.verConfig) {
      this.cargarConfig();
    }
    if (this.esAdmin) {
      this.cargarConfigSistema();
    }
    if (this.verAudio) {
      this.cargarSonidos();
    }
    if (this.esAdmin) {
      this.cargarPantallasTv();
    }
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
    this.detenerPreview();
  }

  getMesNombre(mes: number): string {
    return this.mesesNombres[mes] || '';
  }

  // ============ EFEMÉRIDES ============

  cargarEfemerides(): void {
    this.dataService.listarEfemerides()
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (res) => {
          if (!res.error) {
            this.efemerides = res.body || [];
          }
        },
        error: () => this.toastr.error('Error al cargar efemérides')
      });
  }

  agregarEfemeride(efemeride?: Efemeride): void {
    const dialogRef = this.dialog.open(DialogEfemerideComponent, {
      width: '520px',
      maxWidth: '95vw',
      data: efemeride || null
    });

    dialogRef.afterClosed()
      .pipe(takeUntil(this.destroy$))
      .subscribe(result => {
        if (result) {
          this.dataService.guardarEfemeride(result)
            .pipe(takeUntil(this.destroy$))
            .subscribe({
              next: (res) => {
                if (!res.error) {
                  this.toastr.success('Efeméride guardada');
                  this.cargarEfemerides();
                } else {
                  this.toastr.error(res.body as string);
                }
              },
              error: () => this.toastr.error('Error al guardar')
            });
        }
      });
  }

  eliminarEfemeride(id: number): void {
    this.dataService.eliminarEfemeride(id)
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (res) => {
          if (!res.error) {
            this.toastr.success('Efeméride eliminada');
            this.cargarEfemerides();
          }
        },
        error: () => this.toastr.error('Error al eliminar')
      });
  }

  // ============ CUMPLEAÑOS ============

  cargarCumpleanos(): void {
    this.dataService.listarCumpleanos()
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (res) => {
          if (!res.error) {
            this.cumpleanos = res.body || [];
          }
        },
        error: () => this.toastr.error('Error al cargar cumpleaños')
      });
  }

  agregarCumpleano(cumpleano?: Cumpleano): void {
    const dialogRef = this.dialog.open(DialogCumpleanoComponent, {
      width: '520px',
      maxWidth: '95vw',
      data: cumpleano || null
    });

    dialogRef.afterClosed()
      .pipe(takeUntil(this.destroy$))
      .subscribe(result => {
        if (result) {
          this.dataService.guardarCumpleano(result)
            .pipe(takeUntil(this.destroy$))
            .subscribe({
              next: (res) => {
                if (!res.error) {
                  this.toastr.success('Cumpleaños guardado');
                  this.cargarCumpleanos();
                } else {
                  this.toastr.error(res.body as string);
                }
              },
              error: () => this.toastr.error('Error al guardar')
            });
        }
      });
  }

  eliminarCumpleano(id: number): void {
    this.dataService.eliminarCumpleano(id)
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (res) => {
          if (!res.error) {
            this.toastr.success('Cumpleaños eliminado');
            this.cargarCumpleanos();
          }
        },
        error: () => this.toastr.error('Error al eliminar')
      });
  }

  // ============ AVISOS ============

  cargarAvisos(): void {
    this.dataService.listarAvisos()
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (res) => {
          if (!res.error) {
            this.avisos = res.body || [];
          }
        },
        error: () => this.toastr.error('Error al cargar avisos')
      });
  }

  agregarAviso(aviso?: Aviso): void {
    const dialogRef = this.dialog.open(DialogAvisoComponent, {
      width: '520px',
      maxWidth: '95vw',
      data: aviso || null
    });

    dialogRef.afterClosed()
      .pipe(takeUntil(this.destroy$))
      .subscribe(result => {
        if (result) {
          this.dataService.guardarAviso(result)
            .pipe(takeUntil(this.destroy$))
            .subscribe({
              next: (res) => {
                if (!res.error) {
                  this.toastr.success('Aviso guardado');
                  this.cargarAvisos();
                } else {
                  this.toastr.error(res.body as string);
                }
              },
              error: () => this.toastr.error('Error al guardar')
            });
        }
      });
  }

  eliminarAviso(id: number): void {
    this.dataService.eliminarAviso(id)
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (res) => {
          if (!res.error) {
            this.toastr.success('Aviso eliminado');
            this.cargarAvisos();
          }
        },
        error: () => this.toastr.error('Error al eliminar')
      });
  }

  // ============ CONFIGURACIÓN ============

  cargarConfig(): void {
    this.dataService.obtenerConfigTv()
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (res) => {
          if (!res.error && res.body) {
            this.configTv = { ...this.configTv, ...res.body };
          }
        },
        error: () => {}
      });
  }

  guardarConfig(clave: string, valor: any): void {
    this.dataService.actualizarConfigTv(clave, String(valor))
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (res) => {
          if (!res.error) {
            this.toastr.success('Configuración actualizada');
          }
        },
        error: () => this.toastr.error('Error al guardar configuración')
      });
  }

  // ============ CONFIGURACION DEL SISTEMA (Fase 0) ============

  cargarConfigSistema(): void {
    this.dataService.listarConfiguracionSistema()
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (res) => {
          if (!res.error && Array.isArray(res.body)) {
            this.configSistema = res.body;
            this.configSistemaMap = res.body.reduce((acc, item) => {
              acc[item.clave] = item;
              return acc;
            }, {} as Record<string, ConfiguracionSistemaItem>);
          }
        },
        error: () => this.toastr.error('Error al cargar configuración del sistema')
      });
  }

  guardarConfigSistema(clave: string, valor: any): void {
    const valorStr = String(valor ?? '').trim();
    if (!valorStr) {
      this.toastr.warning('El valor no puede estar vacío');
      this.cargarConfigSistema();
      return;
    }
    this.guardandoConfigSistema[clave] = true;
    this.dataService.actualizarConfiguracionSistema(clave, valorStr)
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (res) => {
          this.guardandoConfigSistema[clave] = false;
          if (!res.error) {
            this.toastr.success('Configuración actualizada');
            if (this.configSistemaMap[clave]) {
              this.configSistemaMap[clave].valor = valorStr;
            }
          } else {
            this.toastr.error(typeof res.body === 'string' ? res.body : 'No se pudo guardar');
            this.cargarConfigSistema();
          }
        },
        error: (err) => {
          this.guardandoConfigSistema[clave] = false;
          const msg = err?.error?.body || 'Error al guardar configuración';
          this.toastr.error(typeof msg === 'string' ? msg : 'Error al guardar configuración');
          this.cargarConfigSistema();
        }
      });
  }

  getValorConfigSistema(clave: string): string {
    return this.configSistemaMap[clave]?.valor ?? '';
  }

  setValorConfigSistema(clave: string, valor: string): void {
    if (this.configSistemaMap[clave]) {
      this.configSistemaMap[clave].valor = valor;
    }
  }

  getPrioridadLabel(prioridad: string): string {
    switch (prioridad) {
      case 'muy_importante': return 'Muy Importante';
      case 'importante': return 'Importante';
      default: return 'Normal';
    }
  }

  getPrioridadColor(prioridad: string): string {
    switch (prioridad) {
      case 'muy_importante': return '#DC2626';
      case 'importante': return '#D97706';
      default: return '#1E40AF';
    }
  }

  // ============ AUDIO ============

  get audioHabilitado(): boolean {
    return this.configTv.audio_habilitado === 'true';
  }

  set audioHabilitado(val: boolean) {
    this.configTv.audio_habilitado = val ? 'true' : 'false';
    this.guardarConfig('audio_habilitado', this.configTv.audio_habilitado);
  }

  get todosLosSonidos(): string[] {
    return [...this.sonidosPreset, ...this.sonidosCustom];
  }

  cargarSonidos(): void {
    this.dataService.listarSonidos()
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (res) => {
          if (!res.error && res.body) {
            this.sonidosPreset = res.body.preset || [];
            this.sonidosCustom = res.body.custom || [];
          }
        },
        error: () => {}
      });
  }

  obtenerUrlSonido(filename: string): string {
    if (this.sonidosPreset.includes(filename)) {
      return `assets/audio/${filename}`;
    }
    return `/uploads/audio/${filename}`;
  }

  previewSonido(filename: string): void {
    this.detenerPreview();
    const url = this.obtenerUrlSonido(filename);
    this.audioPreview = new Audio(url);
    this.audioPreview.volume = parseInt(this.configTv.audio_volumen || '80', 10) / 100;
    this.audioPreview.play().catch(() => {
      this.toastr.warning('No se pudo reproducir el sonido');
    });
    // Detener después de 3 segundos (preview corto)
    setTimeout(() => this.detenerPreview(), 3000);
  }

  detenerPreview(): void {
    if (this.audioPreview) {
      this.audioPreview.pause();
      this.audioPreview = null;
    }
  }

  subirSonido(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (!input.files?.length) return;

    const file = input.files[0];
    const ext = file.name.split('.').pop()?.toLowerCase();

    if (ext !== 'mp3' && ext !== 'wav') {
      this.toastr.error('Solo se permiten archivos .mp3 y .wav');
      input.value = '';
      return;
    }

    if (file.size > 2 * 1024 * 1024) {
      this.toastr.error('El archivo no puede exceder 2MB');
      input.value = '';
      return;
    }

    this.subiendoAudio = true;
    this.dataService.subirSonido(file)
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (res) => {
          if (!res.error) {
            this.toastr.success('Sonido subido correctamente');
            this.cargarSonidos();
          } else {
            this.toastr.error(res.body as any);
          }
          this.subiendoAudio = false;
          input.value = '';
        },
        error: () => {
          this.toastr.error('Error al subir sonido');
          this.subiendoAudio = false;
          input.value = '';
        }
      });
  }

  eliminarSonido(filename: string): void {
    // Verificar que no esté en uso
    if (this.configTv.audio_sonido_alerta === filename || this.configTv.audio_sonido_emergencia === filename) {
      this.toastr.warning('No se puede eliminar un sonido que está en uso');
      return;
    }

    this.dataService.eliminarSonido(filename)
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (res) => {
          if (!res.error) {
            this.toastr.success('Sonido eliminado');
            this.cargarSonidos();
          } else {
            this.toastr.error(res.body as any);
          }
        },
        error: () => this.toastr.error('Error al eliminar sonido')
      });
  }

  esPreset(filename: string): boolean {
    return this.sonidosPreset.includes(filename);
  }

  // ============ PANTALLAS TV ============

  cargarPantallasTv(): void {
    this.dataService.listarPantallasTv()
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (res) => {
          if (!res.error) {
            this.pantallasTv = res.body || [];
          }
        },
        error: () => this.toastr.error('Error al cargar pantallas TV')
      });
  }

  agregarPantallaTv(pantalla?: PantallaTvData): void {
    const dialogRef = this.dialog.open(DialogPantallaTvComponent, {
      width: '560px',
      maxWidth: '95vw',
      data: pantalla || null
    });

    dialogRef.afterClosed()
      .pipe(takeUntil(this.destroy$))
      .subscribe(result => {
        if (result) {
          // Asignar area_id del usuario logueado si no viene en el resultado
          if (!result.area_id) {
            const usuario = this.authService.getUsuario();
            result.area_id = usuario?.area_id || null;
          }
          this.dataService.guardarPantallaTv(result)
            .pipe(takeUntil(this.destroy$))
            .subscribe({
              next: (res) => {
                if (!res.error) {
                  this.toastr.success('Pantalla TV guardada');
                  this.cargarPantallasTv();
                } else {
                  this.toastr.error(res.body as string);
                }
              },
              error: () => this.toastr.error('Error al guardar')
            });
        }
      });
  }

  eliminarPantallaTv(id: number): void {
    this.dataService.eliminarPantallaTv(id)
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (res) => {
          if (!res.error) {
            this.toastr.success('Pantalla TV eliminada');
            this.cargarPantallasTv();
          }
        },
        error: () => this.toastr.error('Error al eliminar')
      });
  }

  getEnlacePantalla(token: string): string {
    return `${window.location.origin}/tv/${token}`;
  }

  copiarEnlace(token: string): void {
    const enlace = this.getEnlacePantalla(token);

    if (navigator.clipboard && window.isSecureContext) {
      navigator.clipboard.writeText(enlace).then(() => {
        this.toastr.success('Enlace copiado al portapapeles');
      }).catch(() => {
        this.copiarFallback(enlace);
      });
    } else {
      this.copiarFallback(enlace);
    }
  }

  private copiarFallback(texto: string): void {
    const textarea = document.createElement('textarea');
    textarea.value = texto;
    textarea.style.position = 'fixed';
    textarea.style.opacity = '0';
    document.body.appendChild(textarea);
    textarea.select();
    try {
      document.execCommand('copy');
      this.toastr.success('Enlace copiado al portapapeles');
    } catch {
      this.toastr.error('No se pudo copiar el enlace');
    }
    document.body.removeChild(textarea);
  }
}
