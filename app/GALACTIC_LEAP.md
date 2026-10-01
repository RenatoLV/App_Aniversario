# Ascenso Maruzon

Actualización: Android incluye inclinación ON/OFF entre flechas, calibrada al activar y combinable con teclado/touch. Cruzar un lateral reaparece por el otro manteniendo velocidad. El viaje incluye ocho zonas, terminando en el Cielo con puerta dorada. Las tormentas dañan también durante el impulso del cohete.

Juego de saltos verticales infinitos integrado al menú principal. No requiere
dependencias nuevas: utiliza Flutter, `CustomPainter`, `Ticker` y `dart:math`.
Los personajes, plataformas, monedas, cohetes, planetas y fondos se dibujan con
código; se incluye además el recurso `assets/gato_cohete.png` para el efecto de recogida del cohete.

## Jugar

- Selecciona a Maru o Lady y pulsa **¡A saltar!**.
- El gato salta automáticamente. Arrastra a izquierda/derecha para modular
  el movimiento desde donde apoyaste el dedo. También puedes mantener una
  mitad de la pantalla o una flecha inferior para moverte.
- En ordenador, mantén las flechas izquierda/derecha o A/D. Espacio o Escape
  alternan la pausa.
- Recoge monedas para el monedero de los sobres. Se guardan al recogerlas,
  incluso si la partida termina después.
- Los cohetes desactivan la gravedad y dan impulso durante 2,4 segundos.
  Cohetes, paraguas y OVNIs alternan en un calendario compartido, con menos
  apariciones totales. Se distinguen con un halo sobre plataformas quietas.
  El indicador inferior muestra el poder activo y su duración.
- Las nubes eléctricas terminan la partida al tocarlas desde cualquier dirección, incluso usando un cohete.
- El botón de cámara congela la partida y muestra una captura en un diálogo.
  Al cerrar la vista previa, la partida continúa si estaba en marcha.
- La pausa también se activa cuando la app pasa a segundo plano.

## Implementación

- `lib/leap.dart`: simulación independiente del renderizado. Coordenadas de
  mundo con Y hacia arriba y ancho lógico de 360 unidades; pasos de física de
  hasta 1/120 s para detectar el cruce de los pies sobre las plataformas.
- La cámara asciende y nunca retrocede. Se generan plataformas por encima del
  campo visible y se descartan objetos que quedan muy abajo.
- El viaje visual es extenso y está dividido en ocho zonas: subsuelo, pradera,
  barrio, ciudad, rascacielos, cielo alto, espacio y Cielo. Cada cambio muestra el
  nombre de la zona. Cada etapa dura un 60% más; el espacio comienza a 21.120
  puntos, después de atravesar todos los paisajes.
- La separación vertical máxima permanece por debajo de la altura de salto.
  Los peldaños varían entre 90 y 116 unidades; el recorrido usa apoyos de
  distintos anchos y más plataformas móviles conforme aumenta la altura.
  La separación horizontal se limita según el tiempo disponible del salto.
  La ruta principal contiene nubes o rocas; los peligros aparecen a un lado.
  Al ascender aumentan la separación y las plataformas móviles, y disminuye
  el ancho de apoyo.
- Las nubes normales sirven una sola vez: se deshacen con una animación al
  tocarlas y desaparecen después del rebote.
- El subsuelo usa plataformas de roca gris y contiene fósiles. Desde la zona
  de rascacielos la ruta utiliza únicamente nubes y aviones móviles; ya no
  aparecen bloques de tierra flotando en el cielo.
- Un calendario compartido alterna cohete, paraguas y OVNI. El primer poder
  aparece desde las 1.040 unidades; la densidad total es aproximadamente la mitad
  de la anterior, contando también el paraguas.
- El OVNI recoge al gato con un haz, lo transporta durante 3,2 segundos y lo
  deposita sobre una plataforma segura, siguiendo su movimiento. La cámara
  recorre la subida sin teletransporte. Durante el transporte no hay colisiones
  ni control manual; al soltarlo recupera el salto normal y la nave se aleja.
- El paraguas dura 8 segundos y limita la caída a 135 unidades/s, sin reducir
  el salto ascendente. Se despliega automáticamente al empezar a descender.
- Algunas plataformas inmóviles llevan un trampolín: elevan el impulso de 480
  a 650 unidades/s y muestran un resorte que reacciona al aterrizar.
- `lib/leap_screen.dart`: controles, interfaz, captura y pintor del mundo.
  El escenario se adapta al ancho disponible y respeta `SafeArea`, con un
  ancho máximo de 480 px en pantallas grandes.
  El dibujo y las mascotas se recortan al rectángulo de juego. Los fondos
  incluyen flores, aves, minerales, nubes y destellos con paralaje; se dibujan
  con una cantidad fija de figuras para mantener acotado el trabajo por cuadro.
- `lib/cat_character.dart`: base pública `CatPainter` y clases `MaruPainter` y
  `LadyPainter`, que reutilizan la anatomía vectorial de las mascotas existentes.
  Los controladores animan respiración, cola, parpadeo aleatorio, reacción al
  recoger monedas y compresión/estiramiento al aterrizar.
- `lib/store.dart`: añade las monedas recogidas al monedero persistente.
  El récord de altura se guarda en preferencias con la clave `leap.best`.

El récord permanece entre partidas; una partida en curso no se restaura
después de cerrar o recargar la aplicación.
