import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, ActivatedRoute } from '@angular/router';
import { Subject, takeUntil } from 'rxjs';
import { ToastrService } from 'ngx-toastr';

import { AuthService, UserSession } from '../../../../services/auth.service';
import { DataService } from '../../../../services/data.service';

export interface UsuarioPermisos {
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

export interface SubArea {
  codHabCama: string;
  desEstCama: string;
  desSerCama: string;
  totalCamas: number;
}

export interface UsuarioAdmin {
  id: number;
  nombre: string;
  usuario: string;
  estado: boolean;
  asignacion_id: number | null;
  area_id: number | null;
  area_nombre: string | null;
  rol: string | null;
  permisos: UsuarioPermisos;
  fecha_registro: string;
}

// Servicio hospitalario que viene de la BD
export interface ServicioHospitalario {
  id: number;
  servicio: string;
  serv_hos_cod: string;
  estacion: string;
  est_enf_cod: string;
  ori_cen_asi_cod: string;
  cen_asi_cod: string;
  are_hos_cod: string;
}

type ViewMode = 'usuarios' | 'crear' | 'cambiar-clave' | 'mi-clave';

@Component({
  selector: 'app-admin-usuarios',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './admin-usuarios.component.html',
  styleUrl: './admin-usuarios.component.scss'
})
export class AdminUsuariosComponent implements OnInit, OnDestroy {
  private destroy$ = new Subject<void>();

  public loading = true;
  public usuarios: UsuarioAdmin[] = [];
  public currentUser: UserSession | null = null;
  public viewMode: ViewMode = 'usuarios';

  // Crear/Editar usuario
  public editMode = false;
  public editUserId = 0;
  public formNombre = '';
  public formUsuario = '';
  public formClave = '';
  public formRol = 'enfermera';
  public formServicio = '';
  public formEstacion = '';
  public formEstado = true;
  public guardando = false;

  // Permisos del formulario
  public formPermisos: UsuarioPermisos = {};

  // Permisos por defecto segun rol
  public readonly PERMISOS_DEFAULT: Record<string, UsuarioPermisos> = {
    'admin': {
      dispositivos: true, analytics: true, contenido_tv: true,
      contenido_tv_efemerides: true, contenido_tv_cumpleanos: true, contenido_tv_avisos: true,
      contenido_tv_audio: true, contenido_tv_config: true, usuarios: true
    },
    'supervisor': {
      dispositivos: true, analytics: true, contenido_tv: true,
      contenido_tv_efemerides: true, contenido_tv_cumpleanos: true, contenido_tv_avisos: true,
      contenido_tv_audio: true, contenido_tv_config: true, usuarios: false
    },
    'jefe_area': {
      dispositivos: true, analytics: true, contenido_tv: true,
      contenido_tv_efemerides: true, contenido_tv_cumpleanos: true, contenido_tv_avisos: true,
      contenido_tv_audio: true, contenido_tv_config: true, usuarios: false
    },
    'doctor': {
      dispositivos: false, analytics: false, contenido_tv: true,
      contenido_tv_efemerides: true, contenido_tv_cumpleanos: true, contenido_tv_avisos: true,
      contenido_tv_audio: false, contenido_tv_config: false, usuarios: false
    },
    'enfermera': {
      dispositivos: false, analytics: false, contenido_tv: true,
      contenido_tv_efemerides: true, contenido_tv_cumpleanos: true, contenido_tv_avisos: true,
      contenido_tv_audio: false, contenido_tv_config: false, usuarios: false
    }
  };

  // Cambiar clave (admin cambia a otro)
  public selectedUserId = 0;
  public selectedUserName = '';
  public nuevaClave = '';
  public confirmarClave = '';
  public cambiandoClave = false;

  // Cambiar mi clave
  public miClaveActual = '';
  public miClaveNueva = '';
  public miClaveConfirmar = '';
  public cambiandoMiClave = false;

  // Servicios hospitalarios (cargados desde BD)
  public serviciosHospitalarios: ServicioHospitalario[] = [];
  public serviciosUnicos: string[] = [];
  public estacionesFiltradas: ServicioHospitalario[] = [];

  // Sub-areas (codHabCama) desde API externa
  public subAreas: SubArea[] = [];
  public formCodHabCama = '';
  public probandoSubAreas = false;

  // Permisos del usuario actual
  public esAdmin = false;

  // Roles disponibles
  public readonly ROLES = [
    { value: 'admin', label: 'Administrador' },
    { value: 'supervisor', label: 'Supervisor' },
    { value: 'jefe_area', label: 'Jefe de Area' },
    { value: 'doctor', label: 'Doctor' },
    { value: 'enfermera', label: 'Enfermera' }
  ];

  constructor(
    private router: Router,
    private route: ActivatedRoute,
    private authService: AuthService,
    private dataService: DataService,
    private toastr: ToastrService
  ) {}

  ngOnInit(): void {
    if (!this.authService.isAuthenticated()) {
      this.router.navigateByUrl('/login');
      return;
    }
    this.currentUser = this.authService.getUsuario();
    this.esAdmin = this.currentUser?.rol === 'admin';

    // Verificar si viene con query param para vista directa
    const vista = this.route.snapshot.queryParamMap.get('vista');
    if (vista === 'mi-clave') {
      this.viewMode = 'mi-clave';
    }

    // Solo cargar lista de usuarios si es admin
    if (this.esAdmin) {
      this.cargarUsuarios();
      this.cargarServicios();
    } else {
      this.loading = false;
      // Si no es admin, solo puede cambiar su clave
      this.viewMode = 'mi-clave';
    }
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }

  cargarUsuarios(): void {
    this.loading = true;
    this.dataService.listarUsuarios().pipe(
      takeUntil(this.destroy$)
    ).subscribe({
      next: (response) => {
        if (!response.error) {
          this.usuarios = response.body || [];
        } else {
          this.toastr.error('Error al cargar usuarios', 'Error');
        }
        this.loading = false;
      },
      error: () => {
        this.toastr.error('Error de conexion con el servidor', 'Error');
        this.loading = false;
      }
    });
  }

  cargarServicios(): void {
    this.dataService.listarServiciosHospitalarios().pipe(
      takeUntil(this.destroy$)
    ).subscribe({
      next: (response) => {
        if (!response.error) {
          this.serviciosHospitalarios = response.body || [];
          // Extraer nombres únicos de servicios
          this.serviciosUnicos = [...new Set(this.serviciosHospitalarios.map(s => s.servicio))];
        }
      },
      error: () => {
        console.error('Error al cargar servicios hospitalarios');
      }
    });
  }

  setView(mode: ViewMode): void {
    this.viewMode = mode;
    this.limpiarFormulario();
  }

  // ============================================
  // CREAR / EDITAR USUARIO
  // ============================================

  abrirCrear(): void {
    this.editMode = false;
    this.editUserId = 0;
    this.limpiarFormulario();
    this.aplicarPermisosDefault();
    this.viewMode = 'crear';
  }

  abrirEditar(user: UsuarioAdmin): void {
    this.editMode = true;
    this.editUserId = user.id;
    this.formNombre = user.nombre;
    this.formUsuario = user.usuario;
    this.formClave = '';
    this.formRol = user.rol || 'enfermera';
    this.formEstado = user.estado;

    // Cargar permisos existentes o default
    if (user.permisos && Object.keys(user.permisos).length > 0) {
      this.formPermisos = { ...user.permisos };
    } else {
      this.aplicarPermisosDefault();
    }

    // Restaurar servicio/estacion desde config_essi guardado
    this.formServicio = '';
    this.formEstacion = '';
    this.formCodHabCama = '';
    this.subAreas = [];
    const configEssi = (user.permisos as any)?.config_essi;
    if (configEssi?.servicio) {
      this.formServicio = configEssi.servicio;
      this.onServicioChange();
      if (configEssi.body?.estEnfCod) {
        this.formEstacion = configEssi.body.estEnfCod;
      }
      if (configEssi.codHabCama) {
        this.formCodHabCama = configEssi.codHabCama;
      }
    }

    this.viewMode = 'crear';
  }

  onRolChange(): void {
    this.aplicarPermisosDefault();
  }

  aplicarPermisosDefault(): void {
    this.formPermisos = { ...(this.PERMISOS_DEFAULT[this.formRol] || this.PERMISOS_DEFAULT['enfermera']) };
  }

  onServicioChange(): void {
    // Filtrar estaciones del servicio seleccionado desde la BD
    this.estacionesFiltradas = this.serviciosHospitalarios.filter(
      s => s.servicio === this.formServicio
    );
    this.formEstacion = '';
    this.subAreas = [];
    this.formCodHabCama = '';
    if (this.estacionesFiltradas.length === 1) {
      this.formEstacion = this.estacionesFiltradas[0].est_enf_cod;
    }
  }

  probarSubAreas(): void {
    const codigoEsSi = this.getCodigoEsSi();
    if (!codigoEsSi.servHosCod) {
      this.toastr.warning('Seleccione servicio y estacion primero', 'Validacion');
      return;
    }

    this.probandoSubAreas = true;
    this.subAreas = [];
    this.formCodHabCama = '';

    this.dataService.previewSubAreas(codigoEsSi).pipe(
      takeUntil(this.destroy$)
    ).subscribe({
      next: (response) => {
        if (!response.error && Array.isArray(response.body)) {
          this.subAreas = response.body;
          if (this.subAreas.length === 0) {
            this.toastr.info('No se encontraron sub-areas para esta estacion', 'Info');
          } else if (this.subAreas.length === 1) {
            this.formCodHabCama = this.subAreas[0].codHabCama;
          }
        } else {
          this.toastr.error('Error al consultar sub-areas', 'Error');
        }
        this.probandoSubAreas = false;
      },
      error: (err) => {
        this.toastr.error('Error de conexion al consultar sub-areas', 'Error');
        this.probandoSubAreas = false;
      }
    });
  }

  guardarUsuario(): void {
    if (!this.formNombre.trim() || !this.formUsuario.trim()) {
      this.toastr.warning('Nombre y usuario son requeridos', 'Validacion');
      return;
    }

    if (!this.editMode && !this.formClave.trim()) {
      this.toastr.warning('La clave es requerida para nuevos usuarios', 'Validacion');
      return;
    }

    if (this.formClave && this.formClave.length < 6) {
      this.toastr.warning('La clave debe tener al menos 6 caracteres', 'Validacion');
      return;
    }

    this.guardando = true;

    // Si es edicion sin clave nueva, solo asignar area/permisos (no tocar usuario)
    if (this.editMode && !this.formClave.trim()) {
      this.asignarAreaUsuario(this.editUserId);
      return;
    }

    const userData: any = {
      id: this.editMode ? this.editUserId : 0,
      nombre: this.formNombre.trim(),
      usuario: this.formUsuario.trim(),
      clave: this.formClave.trim(),
      estado: this.formEstado
    };

    this.dataService.registrarUsuario(userData).pipe(
      takeUntil(this.destroy$)
    ).subscribe({
      next: (response) => {
        if (!response.error) {
          // El body puede ser string ("Usuario actualizado") u objeto ({mensaje, id})
          const body = response.body;
          const userId = this.editMode
            ? this.editUserId
            : (typeof body === 'object' ? body?.id : null);

          console.log('[AdminUsuarios] Registrar respuesta:', JSON.stringify(response), '| userId:', userId);

          if (userId) {
            this.asignarAreaUsuario(userId);
          } else {
            console.error('[AdminUsuarios] No se pudo obtener userId de la respuesta');
            this.toastr.warning('Usuario creado pero no se pudo asignar area (sin ID)', 'Aviso');
            this.viewMode = 'usuarios';
            this.cargarUsuarios();
            this.guardando = false;
          }
        } else {
          this.toastr.error(response.body || 'Error al guardar usuario', 'Error');
          this.guardando = false;
        }
      },
      error: (err) => {
        this.toastr.error(err.error?.body || 'Error al guardar usuario', 'Error');
        this.guardando = false;
      }
    });
  }

  getCodigoEsSi(): any {
    // Buscar el servicio seleccionado en los datos de la BD
    const servicio = this.serviciosHospitalarios.find(
      s => s.servicio === this.formServicio && s.est_enf_cod === this.formEstacion
    );
    if (!servicio) return {};
    return {
      oriCenAsiCod: servicio.ori_cen_asi_cod,
      cenAsiCod: servicio.cen_asi_cod,
      areHosCod: servicio.are_hos_cod,
      servHosCod: servicio.serv_hos_cod,
      estEnfCod: servicio.est_enf_cod
    };
  }

  private getEstacionNombre(): string {
    const est = this.estacionesFiltradas.find(e => e.est_enf_cod === this.formEstacion);
    return est ? est.estacion : this.formEstacion;
  }

  private asignarAreaUsuario(userId: number): void {
    const permisos: any = { ...this.formPermisos };

    // Si hay servicio/estacion, agregar config_essi
    if (this.formServicio && this.formEstacion) {
      const codigoEsSi = this.getCodigoEsSi();
      const areaNombre = this.getEstacionNombre();
      permisos.config_essi = {
        servicio: this.formServicio,
        estacion: areaNombre,
        codHabCama: this.formCodHabCama || '',
        body: codigoEsSi
      };
    }

    const areaNombre = this.formServicio && this.formEstacion
      ? this.getEstacionNombre()
      : (this.formServicio || 'Sin area');

    const payload = {
      id: 0,
      usuario_id: userId,
      area_nombre: areaNombre,
      rol: this.formRol,
      estado: true,
      permisos
    };

    console.log('[AdminUsuarios] Asignando usuario:', JSON.stringify(payload));

    // El SP hace UPSERT por usuario_id
    this.dataService.asignarUsuario(payload).pipe(
      takeUntil(this.destroy$)
    ).subscribe({
      next: (response) => {
        console.log('[AdminUsuarios] Respuesta asignar:', JSON.stringify(response));
        if (!response.error) {
          this.toastr.success(this.editMode ? 'Usuario actualizado' : 'Usuario creado y configurado', 'Exito');
        } else {
          console.error('[AdminUsuarios] Error al asignar:', response);
          this.toastr.warning('Usuario guardado pero error al asignar: ' + response.body, 'Aviso');
        }
        this.viewMode = 'usuarios';
        this.cargarUsuarios();
        this.guardando = false;
      },
      error: (err) => {
        console.error('[AdminUsuarios] Error HTTP al asignar:', err);
        this.toastr.warning('Usuario guardado pero error al asignar area', 'Aviso');
        this.viewMode = 'usuarios';
        this.cargarUsuarios();
        this.guardando = false;
      }
    });
  }

  // ============================================
  // CAMBIAR CLAVE (ADMIN)
  // ============================================

  abrirCambiarClave(user: UsuarioAdmin): void {
    this.selectedUserId = user.id;
    this.selectedUserName = user.nombre;
    this.nuevaClave = '';
    this.confirmarClave = '';
    this.viewMode = 'cambiar-clave';
  }

  cambiarClave(): void {
    if (!this.nuevaClave.trim()) {
      this.toastr.warning('Ingrese la nueva clave', 'Validacion');
      return;
    }
    if (this.nuevaClave.length < 6) {
      this.toastr.warning('La clave debe tener al menos 6 caracteres', 'Validacion');
      return;
    }
    if (this.nuevaClave !== this.confirmarClave) {
      this.toastr.warning('Las claves no coinciden', 'Validacion');
      return;
    }

    this.cambiandoClave = true;
    this.dataService.cambiarClave(this.selectedUserId, this.nuevaClave).pipe(
      takeUntil(this.destroy$)
    ).subscribe({
      next: (response) => {
        if (!response.error) {
          this.toastr.success('Clave cambiada correctamente', 'Exito');
          this.viewMode = 'usuarios';
        } else {
          this.toastr.error(response.body || 'Error al cambiar clave', 'Error');
        }
        this.cambiandoClave = false;
      },
      error: (err) => {
        this.toastr.error(err.error?.body || 'Error al cambiar clave', 'Error');
        this.cambiandoClave = false;
      }
    });
  }

  // ============================================
  // CAMBIAR MI CLAVE
  // ============================================

  abrirCambiarMiClave(): void {
    this.miClaveActual = '';
    this.miClaveNueva = '';
    this.miClaveConfirmar = '';
    this.viewMode = 'mi-clave';
  }

  cambiarMiClave(): void {
    if (!this.miClaveActual.trim()) {
      this.toastr.warning('Ingrese su clave actual', 'Validacion');
      return;
    }
    if (!this.miClaveNueva.trim()) {
      this.toastr.warning('Ingrese la nueva clave', 'Validacion');
      return;
    }
    if (this.miClaveNueva.length < 6) {
      this.toastr.warning('La nueva clave debe tener al menos 6 caracteres', 'Validacion');
      return;
    }
    if (this.miClaveNueva !== this.miClaveConfirmar) {
      this.toastr.warning('Las claves no coinciden', 'Validacion');
      return;
    }

    this.cambiandoMiClave = true;
    this.dataService.cambiarMiClave(this.miClaveActual, this.miClaveNueva).pipe(
      takeUntil(this.destroy$)
    ).subscribe({
      next: (response) => {
        if (!response.error) {
          this.toastr.success('Tu clave ha sido actualizada', 'Exito');
          this.viewMode = 'usuarios';
        } else {
          this.toastr.error(response.body || 'Error al cambiar clave', 'Error');
        }
        this.cambiandoMiClave = false;
      },
      error: (err) => {
        this.toastr.error(err.error?.body || 'Error al cambiar clave', 'Error');
        this.cambiandoMiClave = false;
      }
    });
  }

  // ============================================
  // ELIMINAR USUARIO
  // ============================================

  confirmarEliminar(user: UsuarioAdmin): void {
    if (user.id === this.currentUser?.id) {
      this.toastr.warning('No puedes eliminar tu propio usuario', 'Aviso');
      return;
    }
    if (!confirm(`Eliminar al usuario "${user.nombre}" (${user.usuario})?`)) return;

    this.dataService.eliminarUsuario(user.id).pipe(
      takeUntil(this.destroy$)
    ).subscribe({
      next: (response) => {
        if (!response.error) {
          this.toastr.success('Usuario eliminado', 'Exito');
          this.cargarUsuarios();
        } else {
          this.toastr.error(response.body || 'Error al eliminar', 'Error');
        }
      },
      error: (err) => {
        this.toastr.error(err.error?.body || 'Error al eliminar', 'Error');
      }
    });
  }

  // ============================================
  // HELPERS
  // ============================================

  irAPrincipal(): void {
    this.router.navigateByUrl('/main/principal');
  }

  getRolLabel(rol: string | null): string {
    if (!rol) return 'Sin asignar';
    const found = this.ROLES.find(r => r.value === rol);
    return found ? found.label : rol;
  }

  getRolClass(rol: string | null): string {
    switch (rol) {
      case 'admin': return 'rol-admin';
      case 'supervisor': return 'rol-supervisor';
      case 'jefe_area': return 'rol-jefe';
      case 'doctor': return 'rol-doctor';
      case 'enfermera': return 'rol-enfermera';
      default: return 'rol-default';
    }
  }

  private limpiarFormulario(): void {
    this.formNombre = '';
    this.formUsuario = '';
    this.formClave = '';
    this.formRol = 'enfermera';
    this.formServicio = '';
    this.formEstacion = '';
    this.formCodHabCama = '';
    this.formEstado = true;
    this.formPermisos = {};
    this.estacionesFiltradas = [];
    this.subAreas = [];
    this.editMode = false;
    this.editUserId = 0;
    this.nuevaClave = '';
    this.confirmarClave = '';
    this.miClaveActual = '';
    this.miClaveNueva = '';
    this.miClaveConfirmar = '';
  }
}
