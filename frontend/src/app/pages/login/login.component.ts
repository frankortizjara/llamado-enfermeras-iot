import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormGroup, FormsModule, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { Router } from '@angular/router';
import { Subject, takeUntil } from 'rxjs';
import { ToastrService } from 'ngx-toastr';

import { FooterComponent } from '../../shared/footer/footer.component';
import { AuthService } from '../../../services/auth.service';
import { LoadingComponent } from '../../shared/components/loading/loading.component';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    FooterComponent,
    MatButtonModule,
    MatFormFieldModule,
    MatIconModule,
    ReactiveFormsModule,
    LoadingComponent
  ],
  templateUrl: './login.component.html',
  styleUrl: './login.component.scss'
})
export class LoginComponent implements OnInit, OnDestroy {
  private destroy$ = new Subject<void>();

  public loginForm!: FormGroup;
  public auxClave = false;
  public loading = false;

  constructor(
    private fb: FormBuilder,
    private authService: AuthService,
    private router: Router,
    private toastr: ToastrService
  ) {}

  ngOnInit(): void {
    this.loginForm = this.fb.group({
      usuario: ['', [Validators.required]],
      clave: ['', [Validators.required]]
    });

    // Si ya está autenticado, redirigir
    if (this.authService.isAuthenticated()) {
      this.router.navigateByUrl('/main/menu');
    }
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }

  login(): void {
    if (!this.loginForm.valid || this.loading) return;

    this.loading = true;
    const { usuario, clave } = this.loginForm.value;

    this.authService.login(usuario, clave)
      .pipe(takeUntil(this.destroy$))
      .subscribe({
        next: (response) => {
          this.loading = false;
          if (!response.error) {
            this.router.navigateByUrl('/main/menu');
          } else {
            const errorMsg = typeof response.body === 'string'
              ? response.body
              : 'Error de autenticación';
            this.toastr.error(errorMsg, 'Error', {
              timeOut: 3000,
              progressBar: true,
              closeButton: true,
              positionClass: 'toast-top-right'
            });
          }
        },
        error: (error) => {
          this.loading = false;
          const mensaje = error.error?.body || 'Error de conexión';
          this.toastr.error(mensaje, 'Error', {
            timeOut: 3000,
            progressBar: true,
            closeButton: true,
            positionClass: 'toast-top-right'
          });
        }
      });
  }

  verClave(): void {
    this.auxClave = !this.auxClave;
  }

  onFocus(): void {
    const container = document.querySelector('.input-password');
    container?.classList.add('focused');
  }

  onBlur(): void {
    const container = document.querySelector('.input-password');
    container?.classList.remove('focused');
  }

  loginKey(event: KeyboardEvent): void {
    if (event.key === 'Enter' && this.loginForm.valid) {
      this.login();
    }
  }
}
