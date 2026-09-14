import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-loading',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="flex items-center justify-center p-8" [ngClass]="containerClass">
      <div class="flex flex-col items-center gap-4">
        <div
          class="animate-spin rounded-full border-4 border-primary border-t-transparent"
          [ngClass]="spinnerSizeClass"
        ></div>
        @if (message) {
          <p class="text-gray-600 text-sm">{{ message }}</p>
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
export class LoadingComponent {
  @Input() message?: string;
  @Input() size: 'sm' | 'md' | 'lg' = 'md';
  @Input() fullScreen = false;

  get spinnerSizeClass(): string {
    const sizes = {
      sm: 'h-6 w-6',
      md: 'h-12 w-12',
      lg: 'h-16 w-16'
    };
    return sizes[this.size];
  }

  get containerClass(): string {
    if (this.fullScreen) {
      return 'fixed inset-0 bg-white bg-opacity-80 z-50';
    }
    return '';
  }
}
