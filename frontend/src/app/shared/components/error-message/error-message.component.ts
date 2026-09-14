import { Component, Input, Output, EventEmitter } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-error-message',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="flex flex-col items-center justify-center p-8 text-center" [ngClass]="containerClass">
      <div class="bg-red-50 border border-red-200 rounded-xl p-6 max-w-md">
        <!-- Icono de error -->
        <div class="flex justify-center mb-4">
          <div class="bg-red-100 rounded-full p-3">
            <i class="bi bi-exclamation-triangle-fill text-danger text-3xl"></i>
          </div>
        </div>

        <!-- Título -->
        <h3 class="text-lg font-semibold text-gray-800 mb-2">
          {{ title || 'Error' }}
        </h3>

        <!-- Mensaje -->
        <p class="text-gray-600 mb-4">
          {{ message || 'Ha ocurrido un error. Por favor, intente nuevamente.' }}
        </p>

        <!-- Botón de reintentar -->
        @if (showRetry) {
          <button
            (click)="onRetry()"
            class="px-6 py-2 bg-primary text-white rounded-lg hover:bg-primary-dark transition-colors duration-200 flex items-center gap-2 mx-auto"
          >
            <i class="bi bi-arrow-clockwise"></i>
            {{ retryText || 'Reintentar' }}
          </button>
        }
      </div>
    </div>
  `,
  styles: [`
    :host {
      display: block;
    }
  `]
})
export class ErrorMessageComponent {
  @Input() title?: string;
  @Input() message?: string;
  @Input() showRetry = true;
  @Input() retryText?: string;
  @Input() fullScreen = false;

  @Output() retry = new EventEmitter<void>();

  get containerClass(): string {
    if (this.fullScreen) {
      return 'min-h-screen';
    }
    return '';
  }

  onRetry(): void {
    this.retry.emit();
  }
}
