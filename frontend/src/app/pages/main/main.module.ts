import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MainComponent } from './main.component';
import { RoutersModule } from './routes';
import { RouterModule } from '@angular/router';
import { HeaderComponent } from '../../shared/header/header.component';
import { FooterComponent } from '../../shared/footer/footer.component';



@NgModule({
  declarations: [
    MainComponent
  ],
  imports: [
    CommonModule,
    RoutersModule,
    RouterModule,
    HeaderComponent,
    FooterComponent
  ]
})
export class MainModule { }
