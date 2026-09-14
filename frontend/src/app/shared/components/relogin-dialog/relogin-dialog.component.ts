import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatDialogRef, MatDialogModule } from '@angular/material/dialog';
import { AuthService } from '../../../../services/auth.service';

@Component({
  selector: 'app-relogin-dialog',
  standalone: true,
  imports: [CommonModule, FormsModule, MatDialogModule],
  template: `
    <div class="dialog-wrapper">
      <div class="dialog-header">
        <i class="bi bi-shield-lock"></i>
        <h2>Sesion Expirada</h2>
      </div>

      <div class="dialog-body">
        <p class="session-message">
          Su sesion ha expirado. Ingrese sus credenciales para continuar
          sin perder su trabajo actual.
        </p>

        <div class="form-group">
          <label>Usuario</label>
          <input type="text" [(ngModel)]="usuario" placeholder="Usuario"
                 (keypress)="onKeyPress($event)">
        </div>

        <div class="form-group password-group">
          <label>Contrasena</label>
          <input [type]="showPassword ? 'text' : 'password'"
                 [(ngModel)]="clave" placeholder="Contrasena"
                 (keypress)="onKeyPress($event)">
          <span class="toggle-password" (click)="showPassword = !showPassword">
            <i [class]="showPassword ? 'bi bi-eye-slash' : 'bi bi-eye'"></i>
          </span>
        </div>

        @if (errorMessage) {
          <div class="error-message">
            <i class="bi bi-exclamation-triangle"></i>
            {{ errorMessage }}
          </div>
        }
      </div>

      <div class="dialog-footer">
        <button class="btn-cancel" (click)="cerrar()">Cerrar Sesion</button>
        <button class="btn-save" (click)="relogin()"
                [disabled]="!usuario || !clave || loading">
          @if (loading) {
            <div class="spinner"></div>
            Ingresando...
          } @else {
            <i class="bi bi-box-arrow-in-right"></i>
            Ingresar
          }
        </button>
      </div>
    </div>
  `,
  styleUrl: '../../../pages/main/contenido-tv/dialog-efemeride/dialog-efemeride.component.scss',
  styles: [`
    .session-message {
      color: #64748B;
      font-size: 14px;
      margin: 0;
      line-height: 1.5;
    }
    .error-message {
      color: #DC2626;
      font-size: 13px;
      display: flex;
      align-items: center;
      gap: 6px;
      padding: 8px 12px;
      background: #FEF2F2;
      border-radius: 6px;
    }
    .password-group {
      position: relative;
    }
    .toggle-password {
      position: absolute;
      right: 12px;
      bottom: 10px;
      cursor: pointer;
      color: #64748B;
      font-size: 16px;
    }
    .spinner {
      width: 16px;
      height: 16px;
      border: 2px solid white;
      border-top-color: transparent;
      border-radius: 50%;
      animation: spin 0.6s linear infinite;
      display: inline-block;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
  `]
})
export class ReloginDialogComponent {
  usuario = '';
  clave = '';
  loading = false;
  showPassword = false;
  errorMessage = '';

  constructor(
    public dialogRef: MatDialogRef<ReloginDialogComponent>,
    private authService: AuthService
  ) {
    // Pre-llenar usuario desde la sesión actual
    const session = this.authService.getSession();
    if (session) {
      this.usuario = session.usuario;
    }

    // Evitar cierre accidental
    this.dialogRef.disableClose = true;
  }

  relogin(): void {
    if (!this.usuario || !this.clave || this.loading) return;

    this.loading = true;
    this.errorMessage = '';

    this.authService.login(this.usuario, this.clave).subscribe({
      next: (response) => {
        this.loading = false;
        if (!response.error) {
          this.dialogRef.close(true);
        } else {
          const msg = typeof response.body === 'string'
            ? response.body
            : 'Error de autenticacion';
          this.errorMessage = msg;
        }
      },
      error: (error) => {
        this.loading = false;
        this.errorMessage = error.error?.body || 'Error de conexion';
      }
    });
  }

  cerrar(): void {
    this.dialogRef.close(false);
  }

  onKeyPress(event: KeyboardEvent): void {
    if (event.key === 'Enter') {
      this.relogin();
    }
  }
}
