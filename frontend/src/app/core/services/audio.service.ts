import { Injectable } from '@angular/core';

export type AudioType = 'alerta' | 'emergencia';

export interface AudioConfig {
  audio_habilitado: string;
  audio_volumen: string;
  audio_duracion_alerta: string;
  audio_duracion_emergencia: string;
  audio_sonido_alerta: string;
  audio_sonido_emergencia: string;
}

/**
 * Servicio centralizado para control de audio
 * Maneja la reproducción de sonidos de alerta con configuración dinámica
 */
@Injectable({
  providedIn: 'root'
})
export class AudioService {
  private audioElements: Map<AudioType, HTMLAudioElement> = new Map();
  private isPlaying: Map<AudioType, boolean> = new Map();
  private duracionTimers: Map<AudioType, any> = new Map();
  private currentType: AudioType | null = null;
  private volume = 0.8;
  private _audioDesbloqueado = false;
  private _habilitado = true;

  private audioFiles: Record<AudioType, string> = {
    alerta: 'assets/audio/Beep01.mp3',
    emergencia: 'assets/audio/Beep02.mp3'
  };

  private duraciones: Record<AudioType, number> = {
    alerta: 0,
    emergencia: 0
  };

  constructor() {
    this.initializeAudio();
  }

  get audioDesbloqueado(): boolean {
    return this._audioDesbloqueado;
  }

  get habilitado(): boolean {
    return this._habilitado;
  }

  /**
   * Desbloquear audio mediante interacción del usuario.
   * Los navegadores requieren un gesto del usuario antes de permitir play().
   */
  async desbloquear(): Promise<boolean> {
    let exito = false;
    for (const audio of this.audioElements.values()) {
      try {
        audio.muted = true;
        await audio.play();
        audio.pause();
        audio.muted = false;
        audio.currentTime = 0;
        exito = true;
      } catch {
        // Navegador bloqueó autoplay
      }
    }
    this._audioDesbloqueado = exito;
    return exito;
  }

  /**
   * Aplicar configuración desde el backend (config_tv)
   */
  aplicarConfig(config: AudioConfig): void {
    this._habilitado = config.audio_habilitado !== 'false';

    // Volumen
    const vol = parseInt(config.audio_volumen || '80', 10);
    this.setVolumen(Math.max(0, Math.min(100, vol)) / 100);

    // Duraciones
    this.duraciones.alerta = parseInt(config.audio_duracion_alerta || '0', 10);
    this.duraciones.emergencia = parseInt(config.audio_duracion_emergencia || '0', 10);

    // Sonidos (solo cambiar si son diferentes)
    const nuevoAlerta = this.resolverUrlSonido(config.audio_sonido_alerta || 'Beep01.mp3');
    const nuevoEmergencia = this.resolverUrlSonido(config.audio_sonido_emergencia || 'Beep02.mp3');

    if (this.audioFiles.alerta !== nuevoAlerta || this.audioFiles.emergencia !== nuevoEmergencia) {
      // Detener todo antes de reconfigurar
      this.detenerTodos();

      this.audioFiles.alerta = nuevoAlerta;
      this.audioFiles.emergencia = nuevoEmergencia;

      // Reinicializar elementos de audio con nuevas URLs
      this.initializeAudio();
    }
  }

  /**
   * Resuelve la URL del archivo de sonido.
   * Presets: assets/audio/nombre.mp3
   * Custom: /uploads/audio/nombre.mp3
   */
  private resolverUrlSonido(filename: string): string {
    const presets = ['Beep01.mp3', 'Beep02.mp3'];
    if (presets.includes(filename)) {
      return `assets/audio/${filename}`;
    }
    return `/uploads/audio/${filename}`;
  }

  private initializeAudio(): void {
    // Limpiar timers
    this.duracionTimers.forEach(timer => clearTimeout(timer));
    this.duracionTimers.clear();

    Object.entries(this.audioFiles).forEach(([type, src]) => {
      const existing = this.audioElements.get(type as AudioType);
      if (existing) {
        existing.pause();
      }

      const audio = new Audio(src);
      audio.loop = true;
      audio.volume = this.volume;
      this.audioElements.set(type as AudioType, audio);
      this.isPlaying.set(type as AudioType, false);
    });
  }

  /**
   * Reproducir audio de un tipo específico.
   * Si ya está sonando el mismo tipo, no reinicia.
   * Respeta duración configurada (0 = loop continuo).
   */
  reproducir(tipo: AudioType): void {
    if (!this._audioDesbloqueado || !this._habilitado) return;

    // Si ya está sonando este tipo, no reiniciar
    if (this.currentType === tipo && this.isPlaying.get(tipo)) {
      return;
    }

    // Detener otros audios primero
    this.detenerTodos();

    const audio = this.audioElements.get(tipo);
    if (audio) {
      const duracion = this.duraciones[tipo] || 0;
      audio.loop = duracion === 0;
      audio.currentTime = 0;
      audio.play().catch(err => {
        console.warn('Error reproduciendo audio:', err);
      });
      this.isPlaying.set(tipo, true);
      this.currentType = tipo;

      // Si hay duración configurada, detener después de N segundos
      if (duracion > 0) {
        const timer = setTimeout(() => {
          this.detener(tipo);
        }, duracion * 1000);
        this.duracionTimers.set(tipo, timer);
      }
    }
  }

  detener(tipo: AudioType): void {
    const audio = this.audioElements.get(tipo);
    if (audio) {
      audio.pause();
      audio.currentTime = 0;
      this.isPlaying.set(tipo, false);
      if (this.currentType === tipo) {
        this.currentType = null;
      }
    }
    // Limpiar timer de duración
    const timer = this.duracionTimers.get(tipo);
    if (timer) {
      clearTimeout(timer);
      this.duracionTimers.delete(tipo);
    }
  }

  detenerTodos(): void {
    this.audioElements.forEach((audio, tipo) => {
      audio.pause();
      audio.currentTime = 0;
      this.isPlaying.set(tipo, false);
    });
    this.currentType = null;
    // Limpiar todos los timers
    this.duracionTimers.forEach(timer => clearTimeout(timer));
    this.duracionTimers.clear();
  }

  setVolumen(nivel: number): void {
    this.volume = Math.max(0, Math.min(1, nivel));
    this.audioElements.forEach(audio => {
      audio.volume = this.volume;
    });
  }

  getVolumen(): number {
    return this.volume;
  }

  estaReproduciendo(tipo: AudioType): boolean {
    return this.isPlaying.get(tipo) || false;
  }

  hayAudioActivo(): boolean {
    return Array.from(this.isPlaying.values()).some(playing => playing);
  }

  destroy(): void {
    this.detenerTodos();
    this.audioElements.clear();
    this.isPlaying.clear();
  }
}
