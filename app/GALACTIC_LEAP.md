# Maru & Lady: Galactic Leap

Juego de saltos verticales infinitos integrado al menú principal. No requiere
dependencias nuevas: utiliza Flutter, `CustomPainter`, `Ticker` y `dart:math`.
Los personajes, plataformas, monedas, cohetes, planetas y fondos se dibujan con
código; no se utilizan imágenes en este juego.

## Jugar

- Selecciona a Maru o Lady y pulsa **¡A saltar!**.
- El gato salta automáticamente. Mantén pulsada una mitad de la pantalla o una
  flecha inferior para moverte. Arrastrar entre mitades cambia la dirección.
- En ordenador, mantén las flechas izquierda/derecha o A/D. Espacio o Escape
  alternan la pausa.
- Recoge monedas para el monedero de los sobres. Se guardan al recogerlas,
  incluso si la partida termina después.
- Los cohetes desactivan la gravedad y dan impulso durante 2,4 segundos.
- Las nubes eléctricas terminan la partida al aterrizar en ellas.
- El botón de cámara congela la partida y muestra una captura en un diálogo.
  Al cerrar la vista previa, la partida continúa si estaba en marcha.
- La pausa también se activa cuando la app pasa a segundo plano.

## Implementación

- `lib/leap.dart`: simulación independiente del renderizado. Coordenadas de
  mundo con Y hacia arriba y ancho lógico de 360 unidades; pasos de física de
  hasta 1/120 s para detectar el cruce de los pies sobre las plataformas.
- La cámara asciende y nunca retrocede. Se generan plataformas por encima del
  campo visible y se descartan objetos que quedan muy abajo.
- El viaje visual es extenso y está dividido en siete zonas: subsuelo, pradera,
  barrio, ciudad, rascacielos, cielo alto y espacio. Cada cambio muestra el
  nombre de la zona. Los planetas comienzan recién alrededor de los 13.200
  puntos, después de atravesar todos los paisajes.
- La separación vertical máxima permanece por debajo de la altura de salto.
  La ruta principal contiene nubes o rocas; los peligros aparecen a un lado.
  Al ascender aumentan la separación y las plataformas móviles, y disminuye
  el ancho de apoyo.
- Las nubes normales sirven una sola vez: se deshacen con una animación al
  tocarlas y desaparecen después del rebote.
- El subsuelo usa plataformas de roca gris y contiene fósiles. Desde la zona
  de rascacielos la ruta utiliza únicamente nubes y aviones móviles; ya no
  aparecen bloques de tierra flotando en el cielo.
- El OVNI es un poder raro disponible desde la ciudad. Teletransporta al gato
  más de 500 unidades hacia una plataforma segura y, durante unos segundos,
  lo transforma en alienígena verde con ojos negros y un haz luminoso.
- `lib/leap_screen.dart`: controles, interfaz, captura y pintor del mundo.
  El escenario se adapta al ancho disponible y respeta `SafeArea`, con un
  ancho máximo de 480 px en pantallas grandes.
- `lib/cat_character.dart`: base pública `CatPainter` y clases `MaruPainter` y
  `LadyPainter`, que reutilizan la anatomía vectorial de las mascotas existentes.
  Los controladores animan respiración, cola, parpadeo aleatorio, reacción al
  recoger monedas y compresión/estiramiento al aterrizar.
- `lib/store.dart`: añade las monedas recogidas al monedero persistente.
  El récord de altura se guarda en preferencias con la clave `leap.best`.

El récord permanece entre partidas; una partida en curso no se restaura
después de cerrar o recargar la aplicación.
