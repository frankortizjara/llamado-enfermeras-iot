export class UsuarioModelo{
    usuario?:string;
    clave?:string;
    nombre?:string
}

export class SesionModelo {
    id?: number;
    nombre?: string;
    usuario?: string;
    area_id?: number;
    area_nombre?: string;
    token?: string
}