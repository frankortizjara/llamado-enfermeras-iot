import exp from "constants";

export class ApiModelo {
    error?: boolean;
    status?: number;
    body?: any
}


export class HabitacionModelo {
    id?: number;
    nombre?: string;
    camas?: any;
    estado? : any;
}

export class CamaModelo {
    id?: number;
    nombre?: string;
    paciente?: PacienteModelo;
}

export class PacienteModelo {
    id?: number;
    nombre?: string;
    paciente?: string;
}

export class NotaModelo{
    id?: number;
    nota?: string;
    nombre?: string;
    paciente?: string;
    fecha_nota?: string;
  }