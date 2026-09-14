import { Routes } from '@angular/router';
import { LoginComponent } from './pages/login/login.component';
import { authGuard, noAuthGuard } from './core/guards/auth.guard';

export const routes: Routes = [
  {
    path: 'main',
    loadChildren: () => import('./pages/main/main.module').then(m => m.MainModule),
    canActivate: [authGuard]
  },
  {
    path: 'tv/:token',
    loadComponent: () => import('./pages/tv/tv.component').then(c => c.TvComponent),
  },
  {
    path: 'login',
    component: LoginComponent,
    canActivate: [noAuthGuard]
  },
  {
    path: '',
    redirectTo: '/login',
    pathMatch: 'full'
  },
  {
    path: '**',
    redirectTo: '/login'
  },
];
