import { Injectable, PLATFORM_ID, Inject } from '@angular/core';
import { isPlatformBrowser } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';
import { Observable, tap, catchError, throwError, BehaviorSubject } from 'rxjs';
import { environment } from '../environments/environment';

export interface UserPermisos {
  dispositivos?: boolean;
  analytics?: boolean;
  contenido_tv?: boolean;
  contenido_tv_efemerides?: boolean;
  contenido_tv_cumpleanos?: boolean;
  contenido_tv_avisos?: boolean;
  contenido_tv_audio?: boolean;
  contenido_tv_config?: boolean;
  usuarios?: boolean;
  config_essi?: {
    servicio: string;
    estacion: string;
    codHabCama: string;
    body: {
      oriCenAsiCod: string;
      cenAsiCod: string;
      areHosCod: string;
      servHosCod: string;
      estEnfCod: string;
    };
  };
}

export interface UserData {
  id: number;
  nombre: string;
  usuario: string;
  area_id: number;
  area_nombre: string;
  rol: string;
  permisos: UserPermisos;
  token: string;
}

export interface LoginResponse {
  error: boolean;
  status: number;
  body: UserData | string; // UserData cuando éxito, string cuando error
}

export interface UserSession {
  id: number;
  nombre: string;
  usuario: string;
  area_id: number;
  area_nombre: string;
  rol: string;
  permisos: UserPermisos;
}

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private apiUrl = environment.apiUrl;
  private currentUser$ = new BehaviorSubject<UserSession | null>(null);
  private isBrowser: boolean;

  constructor(
    private http: HttpClient,
    private router: Router,
    @Inject(PLATFORM_ID) platformId: Object
  ) {
    this.isBrowser = isPlatformBrowser(platformId);
    // Restaurar sesión desde localStorage al iniciar (solo en browser)
    if (this.isBrowser) {
      this.restoreSession();
    }
  }

  /**
   * Iniciar sesión con usuario y contraseña
   */
  login(usuario: string, clave: string): Observable<LoginResponse> {
    return this.http.post<LoginResponse>(`${this.apiUrl}/usuarios/login`, {
      usuario,
      clave
    }).pipe(
      tap(response => {
        if (!response.error && response.body && typeof response.body !== 'string') {
          this.setSession(response.body as UserData);
        }
      }),
      catchError(error => {
        console.error('Error en login:', error);
        return throwError(() => error);
      })
    );
  }

  /**
   * Cerrar sesión
   */
  logout(): void {
    this.clearSession();
    this.router.navigate(['/login']);
  }

  /**
   * Verificar si el usuario está autenticado
   */
  isAuthenticated(): boolean {
    if (!this.isBrowser) return false;

    const token = localStorage.getItem('token');
    const sesion = localStorage.getItem('sesion');

    if (!token || !sesion) {
      return false;
    }

    // Verificar que el token no esté vacío
    return token.length > 0;
  }

  /**
   * Obtener el usuario actual
   */
  getCurrentUser(): UserSession | null {
    return this.currentUser$.value;
  }

  /**
   * Observable del usuario actual
   */
  getCurrentUser$(): Observable<UserSession | null> {
    return this.currentUser$.asObservable();
  }

  /**
   * Obtener token JWT
   */
  getToken(): string | null {
    if (!this.isBrowser) return null;
    return localStorage.getItem('token');
  }

  /**
   * Obtener datos de sesión
   */
  getSession(): UserSession | null {
    if (!this.isBrowser) return null;

    const sesion = localStorage.getItem('sesion');
    if (sesion) {
      try {
        return JSON.parse(sesion);
      } catch {
        return null;
      }
    }
    return null;
  }

  /**
   * Validar sesión (compatibilidad con código existente)
   */
  validarSesion(): boolean {
    return this.isAuthenticated();
  }

  /**
   * Obtener usuario (alias de getSession para compatibilidad)
   */
  getUsuario(): UserSession | null {
    return this.getSession();
  }

  /**
   * Obtener rol del usuario actual
   */
  getRol(): string | null {
    return this.getSession()?.rol || null;
  }

  /**
   * Decodificar payload del JWT sin verificar (solo lectura del exp)
   */
  private decodeToken(token: string): any {
    try {
      const payload = token.split('.')[1];
      const decoded = atob(payload.replace(/-/g, '+').replace(/_/g, '/'));
      return JSON.parse(decoded);
    } catch {
      return null;
    }
  }

  /**
   * Obtener tiempo restante del token en milisegundos (0 si expirado)
   */
  getTokenTimeRemaining(): number {
    const token = this.getToken();
    if (!token) return 0;

    const decoded = this.decodeToken(token);
    if (!decoded?.exp) return 0;

    const expiresAt = decoded.exp * 1000;
    const remaining = expiresAt - Date.now();
    return remaining > 0 ? remaining : 0;
  }

  /**
   * Verificar si el token está próximo a expirar
   */
  isTokenExpiringSoon(thresholdMs: number = 30 * 60 * 1000): boolean {
    const remaining = this.getTokenTimeRemaining();
    return remaining < thresholdMs && remaining > 0;
  }

  /**
   * Actualizar token y sesión desde datos de refresh/re-login
   */
  refreshSession(userData: UserData): void {
    this.setSession(userData);
  }

  /**
   * Guardar sesión en localStorage
   */
  private setSession(userData: UserData): void {
    if (!this.isBrowser) return;

    const { token, ...userSession } = userData;

    localStorage.setItem('token', token);
    localStorage.setItem('sesion', JSON.stringify(userSession));

    // Compatibilidad con código existente
    localStorage.setItem('Usuario', JSON.stringify(userSession));

    this.currentUser$.next(userSession);
  }

  /**
   * Limpiar sesión
   */
  private clearSession(): void {
    if (!this.isBrowser) return;

    localStorage.removeItem('token');
    localStorage.removeItem('sesion');
    localStorage.removeItem('Usuario');
    this.currentUser$.next(null);
  }

  /**
   * Restaurar sesión desde localStorage
   */
  private restoreSession(): void {
    const sesion = this.getSession();
    if (sesion && this.isAuthenticated()) {
      this.currentUser$.next(sesion);
    }
  }
}
