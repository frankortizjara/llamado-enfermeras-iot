import { ComponentFixture, TestBed } from '@angular/core/testing';

import { AddNotaComponent } from './add-nota.component';

describe('AddNotaComponent', () => {
  let component: AddNotaComponent;
  let fixture: ComponentFixture<AddNotaComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [AddNotaComponent]
    })
    .compileComponents();
    
    fixture = TestBed.createComponent(AddNotaComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
