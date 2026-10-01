# Dulces & bigotes

Juego Flutter local de combinar tres piezas, con arte vectorial original y los
actores de Maru y Lady usados en el resto de la aplicación.

## Arquitectura

- `SweetCell`: pieza, especial, hueco, gelatina de una/dos capas, glaseado,
  chocolate y lazo. Las capas permanecen en su casilla al intercambiar piezas.
- `SweetGame`: rejilla 9×9 y generador pseudoaleatorio reproducible. `detect`
  encuentra líneas y une las que se intersectan: 5 rectos tienen prioridad
  sobre L/T, luego 4 y 3. El destino del intercambio es el pivote preferido.
- `_fusion` y `_clear`: resuelven las seis fusiones, propagan explosiones,
  consumen una capa de obstáculos por oleada y puntúan según la cascada.
- `_fall`: gravedad vertical y deslizamiento diagonal bajo obstáculos;
  `_resolve` alterna caída, generación, segunda explosión y cascadas.
- `SweetFrame`: instantáneas inmutables para reproducir la máquina de estados.
  `SweetScreen` bloquea la entrada hasta terminar la reproducción; el motor
  termina y guarda el turno completo antes de las animaciones.
- `ensureMoves`: baraja sin gastar movimientos ni modificar las gelatinas.
  Si no encuentra un tablero estable tras 100 intentos, crea uno estable
  con un ovillo especial para asegurar una interacción.

## Reglas y niveles

26 movimientos por nivel. Objetivo: quitar toda la gelatina. Un intercambio
inválido revierte; los especiales pueden combinarse sin formar una línea.
Al ganar, los movimientos restantes crean rayados y los especiales explotan.
Al perder se puede usar el +5 disponible o reiniciar.

El primer nivel introduce gelatina; el segundo añade glaseado y lazos; el
tercero añade doble gelatina y chocolate; desde el cuarto aparecen huecos.
Cada nivel ofrece 3 martillos, 2 intercambios libres y un +5, sin compras.

La gravedad admite generación en la parte superior de las cámaras jugables
aisladas por obstáculos. Esta decisión evita huecos imposibles de rellenar.
La resolución tiene límites de seguridad para cascadas patológicas. El juego
es una adaptación propia; los niveles son generados, no los de Candy Crush.

`sweet.v1` conserva tablero, obstáculos, puntos, movimientos, nivel,
potenciadores y estado aleatorio. Reiniciar renueva el tablero del mismo nivel;
avanzar abre el siguiente nivel. No incluye un sistema de vidas o tienda.

## Comprobaciones

Los gestos del tablero se miden desde el primer contacto, con un umbral
táctil local adaptado a las fichas pequeñas. Un arrastre intercambia una sola
vecina en el eje dominante; también funciona con el cambio libre. Los gestos
diagonales ambiguos y los que salen del borde no consumen movimientos.
El aviso de intercambio sin combinación permanece visible; las animaciones
de vuelta, caída y aparición terminan antes de avanzar al siguiente estado.

`test/match3_test.dart` comprueba patrones, fusiones, bloqueadores, intercambios,
potenciadores, estabilidad inicial y persistencia. `test/sweet_screen_test.dart`
comprueba el tablero y los controles en pantallas lógicas 393×852 y 360×740.
