import { Injectable, OnDestroy } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Subject, takeUntil, catchError, of } from 'rxjs';
import { environment } from '../../../environments/environment';
import { AuthService, LoginResponse } from '../../../services/auth.service';

@Injectable({
  providedIn: 'root'
})
export class TokenRefreshService implements OnDestroy {
  private destroy$ = new Subject<void>();
  private checkInterval: ReturnType<typeof setInterval> | null = null;
  private isRefreshing = false;

  // Verificar cada 5 minutos
  private readonly CHECK_INTERVAL_MS = 5 * 60 * 1000;
  // Renovar cuando quede menos de 1 hora (token dura 24h)
  private readonly REFRESH_THRESHOLD_MS = 60 * 60 * 1000;

  constructor(
    private http: HttpClient,
    private authService: AuthService
  ) {}

  /**
   * Iniciar monitoreo periódico de expiración del token
   */
  startMonitoring(): void {
    this.stopMonitoring();

    // Verificar inmediatamente al iniciar
    this.checkAndRefresh();

    // Luego verificar periódicamente
    this.checkInterval = setInterval(() => {
      this.checkAndRefresh();
    }, this.CHECK_INTERVAL_MS);
  }

  /**
   * Detener monitoreo
   */
  stopMonitoring(): void {
    if (this.checkInterval) {
      clearInterval(this.checkInterval);
      this.checkInterval = null;
    }
  }

  private checkAndRefresh(): void {
    if (!this.authService.isAuthenticated()) return;
    if (this.isRefreshing) return;

    if (this.authService.isTokenExpiringSoon(this.REFRESH_THRESHOLD_MS)) {
      this.refreshToken();
    }
  }

  private refreshToken(): void {
    this.isRefreshing = true;

    this.http.post<LoginResponse>(
      `${environment.apiUrl}/usuarios/refresh-token`, {}
    ).pipe(
      takeUntil(this.destroy$),
      catchError(err => {
        console.warn('Error renovando token:', err.status);
        return of(null);
      })
    ).subscribe(response => {
      this.isRefreshing = false;

      if (response && !response.error && response.body && typeof response.body !== 'string') {
        this.authService.refreshSession(response.body);
        console.log('Token renovado exitosamente');
      }
    });
  }

  ngOnDestroy(): void {
    this.stopMonitoring();
    this.destroy$.next();
    this.destroy$.complete();
  }
}
