# Por qué hacía falta

El piloto no salió de una idea. Salió de que varios servicios de la red hospitalaria
llevaban años pidiendo un timbre de llamado y no llegaba.

Lo que sigue resume la documentación institucional que sustentó la solicitud. Son
informes y notas internas con numeración oficial; **no se publican aquí** —son
propiedad de la institución y algunos describen incidentes con personal
identificable— pero se citan por su número y fecha para que la afirmación sea
verificable por quien tenga acceso a ellos.

---

## El problema estaba documentado

**Un timbre inoperativo también lesiona al personal.**
Un informe de accidente de trabajo de febrero de 2026 atribuyó la lesión de una
profesional de enfermería a la inoperatividad de los botones de llamada junto a las
camillas: tuvo que sostener sola a una paciente que se descompensaba porque no pudo
pedir ayuda a tiempo.
*(Informe N.º 000005-2026-USSTYSA-ORH-OA-GRPS, 19/02/2026)*

**La alternativa vigente era el aviso verbal.**
Un servicio de gineco-obstetricia venía reiterando el pedido de timbres en notas
sucesivas. Mientras tanto, la medida acordada fue avisar de viva voz.
*(Notas 000095 y 000127-2026, marzo de 2026)*

**Los pacientes más dependientes eran los que no tenían timbre.**
Un servicio de especialidades médicas reportó 48 camas con pacientes de dependencia
grado III sin un mecanismo accesible y oportuno para solicitar apoyo.
*(Nota 000112-2026-SEEM-DE-GHNASS, 02/03/2026)*

**Cuatro años pidiendo lo mismo.**
Ese mismo servicio ya tenía términos de referencia en 2022 para un sistema tradicional
cableado con VoIP y PoE. En 2026 seguía pidiéndolo.

---

## Por qué no bastaba con comprar un sistema tradicional

Esta es la parte que decidió el diseño.

**El modelo cableado ya se compró, y se perdió.** Una visita técnica de mayo de 2026 a
otro hospital de la red encontró un sistema cableado instalado en **2009 que dejó de
operar a los doce meses**, y un segundo sistema con solo **15 de 30 camas** activas.
El cableado corría junto a tuberías de gas. La recomendación de esa visita fue
evaluar una solución inalámbrica alimentada a 12 V.
*(Anexo 3 — Informe técnico de visita, 05/05/2026)*

**Por la vía tradicional la solución llega en 2027 o después.** Otro hospital reportó
en agosto de 2026 el sistema inoperativo en su totalidad por obsolescencia en siete
áreas, con la recomendación de incluirlo en el cuadro de inversiones multianual de
2027.
*(Informe N.º 000010-2026-EGT-OSI, 11/08/2026)*

---

## Qué cambia eso en el diseño

Tres hospitales de la misma red con el timbre caído, un servicio esperando cuatro
años, y el único sistema cableado documentado duró un año. De ahí salen las tres
decisiones del proyecto:

| Restricción observada | Decisión |
|---|---|
| El cableado nuevo es caro, lento de aprobar y ya falló | **Inalámbrico sobre el Wi-Fi existente**, alimentado a 12 V. Sin cableado de datos, sin switch PoE, sin central VoIP |
| Un sistema propietario que se rompe no se puede reparar | **Hardware y firmware propios**, actualizables por aire. 67 reemplazos gestionados desde el propio sistema |
| La red del hospital se cae | **ESP-NOW** entre el pulsador y la habitación: la llamada no depende de la red |
| Nadie sabía cuántas veces fallaba el timbre | **Cada llamada queda registrada**, con hora, habitación, cama y tiempo de respuesta |

Coste de materiales electrónicos: **unos S/ 163 por habitación**.

---

## Lo que el piloto demostró, y lo que no

**Demostró** que funciona sobre infraestructura antigua, que el punto crítico es el
baño —40 % de los llamados— y que registrar cada llamada produce información de
gestión que antes no existía.

**No demostró** que se sostenga sin acompañamiento. La respuesta se degradó cuando el
equipo dejó de estar encima, y desde finales de julio de 2026 no hay llamados
registrados aunque los dispositivos siguen vivos. Eso apunta a que el problema
siguiente no es técnico, es de administración y seguimiento.

Ver [Resultados medidos](../README.md#resultados-medidos) y las limitaciones
conocidas en el README.
