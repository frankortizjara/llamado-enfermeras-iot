import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from '../../../services/auth.service';

/**
 * Guard de autenticación para proteger rutas
 * Redirige al login si el usuario no está autenticado
 */
export const authGuard: CanActivateFn = (route, state) => {
  const authService = inject(AuthService);
  const router = inject(Router);

  if (authService.isAuthenticated()) {
    return true;
  }

  // Guardar la URL intentada para redirigir después del login
  const returnUrl = state.url;
  router.navigate(['/login'], { queryParams: { returnUrl } });
  return false;
};

/**
 * Guard inverso - redirige usuarios autenticados fuera del login
 */
export const noAuthGuard: CanActivateFn = (route, state) => {
  const authService = inject(AuthService);
  const router = inject(Router);

  if (!authService.isAuthenticated()) {
    return true;
  }

  // Usuario ya autenticado, redirigir al dashboard
  router.navigate(['/main/principal']);
  return false;
};
