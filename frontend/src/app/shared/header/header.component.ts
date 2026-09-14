import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { Router } from '@angular/router';
import { AuthService } from '../../../services/auth.service';

@Component({
  selector: 'app-header',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    MatIconModule,
    MatButtonModule
  ],
  templateUrl: './header.component.html',
  styleUrl: './header.component.scss'
})
export class HeaderComponent implements OnInit {
  public nombreSesion = '';
  public areaNombre = '';
  public rolUsuario = '';

  // Permisos por perfil
  public verDispositivos = false;
  public verAnalytics = false;
  public verContenidoTv = false;
  public verUsuarios = false;

  // Permisos por defecto segun rol (fallback si no hay permisos guardados)
  private readonly PERMISOS_POR_ROL: Record<string, Record<string, boolean>> = {
    'admin':      { dispositivos: true,  analytics: true,  contenido_tv: true,  usuarios: true },
    'supervisor': { dispositivos: true,  analytics: true,  contenido_tv: true,  usuarios: false },
    'jefe_area':  { dispositivos: true,  analytics: true,  contenido_tv: true,  usuarios: false },
    'doctor':     { dispositivos: false, analytics: false, contenido_tv: true,  usuarios: false },
    'enfermera':  { dispositivos: false, analytics: false, contenido_tv: true,  usuarios: false },
  };

  constructor(
    private router: Router,
    private authService: AuthService
  ) {}

  ngOnInit(): void {
    if (!this.authService.isAuthenticated()) {
      this.router.navigateByUrl('/login');
      return;
    }

    const usuario = this.authService.getUsuario();
    if (usuario) {
      this.nombreSesion = usuario.nombre || '';
      this.areaNombre = usuario.area_nombre || '';
      this.rolUsuario = usuario.rol || '';

      // Si el usuario tiene permisos guardados, usarlos; sino, fallback por rol
      const permisos = usuario.permisos;
      const tienePermisos = permisos && Object.keys(permisos).length > 0;

      if (tienePermisos) {
        this.verDispositivos = !!permisos.dispositivos;
        this.verAnalytics = !!permisos.analytics;
        this.verContenidoTv = !!permisos.contenido_tv;
        this.verUsuarios = !!permisos.usuarios;
      } else {
        const def = this.PERMISOS_POR_ROL[this.rolUsuario] || { dispositivos: false, analytics: false, contenido_tv: true, usuarios: false };
        this.verDispositivos = def['dispositivos'];
        this.verAnalytics = def['analytics'];
        this.verContenidoTv = def['contenido_tv'];
        this.verUsuarios = def['usuarios'];
      }
    }
  }

  cerrarSesion(): void {
    this.authService.logout();
    this.router.navigateByUrl('/login');
  }

  irADispositivos(): void {
    this.router.navigateByUrl('/main/dispositivos');
  }

  irAAnalytics(): void {
    this.router.navigateByUrl('/main/analytics');
  }

  irAPrincipal(): void {
    this.router.navigateByUrl('/main/principal');
  }

  irAContenidoTv(): void {
    this.router.navigateByUrl('/main/contenido-tv');
  }

  irAAdminUsuarios(): void {
    this.router.navigateByUrl('/main/admin-usuarios');
  }

  irAAuditoria(): void {
    this.router.navigateByUrl('/main/auditoria');
  }

  verMiConfig(): void {
    const usuario = this.authService.getUsuario();
    const config = {
      id: usuario?.id,
      nombre: usuario?.nombre,
      usuario: usuario?.usuario,
      area_id: usuario?.area_id,
      area_nombre: usuario?.area_nombre,
      rol: usuario?.rol,
      permisos: usuario?.permisos
    };
    console.log('[MiConfig]', JSON.stringify(config, null, 2));
    const configEssi = config.permisos?.config_essi;
    alert(
      `Mi Configuracion:\n\n` +
      `Nombre: ${config.nombre}\n` +
      `Usuario: ${config.usuario}\n` +
      `Rol: ${config.rol || 'Sin asignar'}\n` +
      `Area: ${config.area_nombre || 'Sin area'}\n` +
      `Area ID: ${config.area_id || 'N/A'}\n` +
      `Servicio: ${configEssi?.servicio || 'N/A'}\n` +
      `Estacion: ${configEssi?.estacion || 'N/A'}\n` +
      `Sub-area (codHabCama): ${configEssi?.codHabCama || 'N/A'}\n\n` +
      `Config EsSi:\n${JSON.stringify(configEssi?.body, null, 2) || 'N/A'}\n\n` +
      `Permisos:\n${JSON.stringify(config.permisos, null, 2)}`
    );
  }

  irACambiarMiClave(): void {
    this.router.navigateByUrl('/main/admin-usuarios?vista=mi-clave');
  }

  inicio(ruta: string): void {
    this.router.navigateByUrl(ruta);
  }
}
