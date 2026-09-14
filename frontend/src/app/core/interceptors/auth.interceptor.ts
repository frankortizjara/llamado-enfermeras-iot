import { HttpInterceptorFn, HttpErrorResponse } from '@angular/common/http';
import { inject } from '@angular/core';
import { MatDialog } from '@angular/material/dialog';
import { catchError, throwError, switchMap, EMPTY, Subject, filter, take } from 'rxjs';
import { AuthService } from '../../../services/auth.service';
import { ReloginDialogComponent } from '../../shared/components/relogin-dialog/relogin-dialog.component';

// Estado a nivel de módulo compartido entre todas las invocaciones del interceptor
let isShowingReloginDialog = false;
let reloginResult$ = new Subject<boolean>();

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const dialog = inject(MatDialog);
  const authService = inject(AuthService);

  // Agregar token a la solicitud
  const token = localStorage.getItem('token');
  const headers: Record<string, string> = {};
  // No forzar Content-Type en FormData (el navegador lo setea con el boundary)
  if (!(req.body instanceof FormData)) {
    headers['Content-Type'] = 'application/json';
  }
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }
  req = req.clone({ setHeaders: headers });

  return next(req).pipe(
    catchError((error: HttpErrorResponse) => {
      if (error.status === 401) {
        // No mostrar dialog para el endpoint de login (evita loop infinito)
        if (req.url.includes('/usuarios/login')) {
          return throwError(() => error);
        }

        // Si ya hay un dialog abierto, esperar su resultado
        if (isShowingReloginDialog) {
          return reloginResult$.pipe(
            filter(result => result !== undefined),
            take(1),
            switchMap(success => {
              if (success) {
                // Reintentar con el nuevo token
                const newToken = localStorage.getItem('token');
                const retryHeaders: Record<string, string> = { Authorization: `Bearer ${newToken}` };
                if (!(req.body instanceof FormData)) {
                  retryHeaders['Content-Type'] = 'application/json';
                }
                const retryReq = req.clone({ setHeaders: retryHeaders });
                return next(retryReq);
              }
              return throwError(() => error);
            })
          );
        }

        // Abrir dialog de re-login
        isShowingReloginDialog = true;
        reloginResult$ = new Subject<boolean>();

        const dialogRef = dialog.open(ReloginDialogComponent, {
          width: '400px',
          maxWidth: '95vw',
          disableClose: true,
        });

        return dialogRef.afterClosed().pipe(
          switchMap((result: boolean) => {
            isShowingReloginDialog = false;
            reloginResult$.next(result);
            reloginResult$.complete();

            if (result === true) {
              // Re-login exitoso: reintentar request original con nuevo token
              const newToken = localStorage.getItem('token');
              const retryHeaders: Record<string, string> = { Authorization: `Bearer ${newToken}` };
              if (!(req.body instanceof FormData)) {
                retryHeaders['Content-Type'] = 'application/json';
              }
              const retryReq = req.clone({ setHeaders: retryHeaders });
              return next(retryReq);
            } else {
              // Usuario eligió cerrar sesión
              authService.logout();
              return EMPTY;
            }
          })
        );
      }

      // Manejar error 403 - Acceso denegado
      if (error.status === 403) {
        console.error('Acceso denegado:', error.message);
      }

      // Manejar error 500+ - Error del servidor
      if (error.status >= 500) {
        console.error('Error del servidor:', error.message);
      }

      return throwError(() => error);
    })
  );
};
