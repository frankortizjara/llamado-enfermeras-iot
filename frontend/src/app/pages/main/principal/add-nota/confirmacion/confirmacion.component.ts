import { Component, Inject, OnInit } from '@angular/core';
import { MatDialogRef, MAT_DIALOG_DATA, MatDialogModule } from '@angular/material/dialog';
import { AnimationOptions, LottieComponent } from 'ngx-lottie';
import { AnimationItem } from 'ngx-lottie/lib/symbols';

@Component({
  selector: 'app-confirmacion',
  standalone: true,
  imports: [
    MatDialogModule,
    LottieComponent
  ],
  templateUrl: './confirmacion.component.html',
  styleUrls: ['./confirmacion.component.scss']
})
export class ConfirmacionComponent implements OnInit{

  constructor(
    public dialogo: MatDialogRef<ConfirmacionComponent>,
    @Inject(MAT_DIALOG_DATA) public mensaje: string
  ) {

  }

  cerrarDialogo(): void {
    this.dialogo.close(false);
  }
  confirmado(): void {
    this.dialogo.close(true);
  }

  ngOnInit(): void {

  }

  options: AnimationOptions = {
    path: '/assets/json/admiration.json', // Ruta relativa correcta
  };
  

  styles: Partial<CSSStyleDeclaration> = {
    maxWidth: '200px',
    margin: '0 auto',
  };

  animationCreated(animationItem: AnimationItem): void {
    console.log(animationItem);
  }
}