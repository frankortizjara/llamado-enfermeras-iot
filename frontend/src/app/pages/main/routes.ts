import { Route, RouterModule, Routes } from '@angular/router';
import { PrincipalComponent } from './principal/principal.component';
import { AnalyticsComponent } from './analytics/analytics.component';
import { DispositivosComponent } from './dispositivos/dispositivos.component';
import { EstadisticasDispositivosComponent } from './dispositivos/estadisticas/estadisticas-dispositivos.component';
import { ContenidoTvComponent } from './contenido-tv/contenido-tv.component';
import { AdminUsuariosComponent } from './admin-usuarios/admin-usuarios.component';
import { AuditoriaComponent } from './auditoria/auditoria.component';
import { Component, NgModule } from '@angular/core';
import { MainComponent } from './main.component';
import { CommonModule } from '@angular/common';

const routers:Routes = [
    {path:'',component:MainComponent,children:[
        {path: 'principal', component: PrincipalComponent},
        {path: 'analytics', component: AnalyticsComponent},
        {path: 'dispositivos/estadisticas', component: EstadisticasDispositivosComponent},
        {path: 'dispositivos', component: DispositivosComponent},
        {path: 'contenido-tv', component: ContenidoTvComponent},
        {path: 'admin-usuarios', component: AdminUsuariosComponent},
        {path: 'auditoria', component: AuditoriaComponent},
        {path: '**', redirectTo: '/main/principal', pathMatch: 'full'},
    ]}

]

@NgModule({
    imports:[
        CommonModule,
        RouterModule.forChild(routers)
    ],
    exports:[RouterModule]
})

export class RoutersModule{}