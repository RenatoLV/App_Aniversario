# Revisión visual de Maruversario

Fecha: 30 de septiembre de 2026.

## Alcance

Recorrido de la web local: Inicio, habitación de mascotas, Bloques & bigotes,
Palabras & bigotes, Dulces & bigotes, Galactic Leap, Sobres, carta revelada,
Colección, giro de cartas y editor de notas.

Tamaños lógicos del navegador revisados: 360×740, 360×780, 393×852 y 852×393.
Se observaron caricias, comida automática, movimiento de nubes, salto y derrota
en Galactic Leap, limpieza de una línea en Bloques, error de vocabulario en
Wordle, combinación de tres y creación de un especial de cuatro en Dulces,
apertura de sobre y giro al reverso de una carta.

Es una revisión en navegador, no una prueba en un Galaxy A55 físico. Quedan
por comprobar el teclado de Android, las zonas del sistema, vibración,
multitáctil y rendimiento/batería. No se midieron FPS ni todas las variantes
aleatorias de animación. Los hallazgos de código se distinguen de lo observado.

Durante el recorrido se abrió un sobre de 20 monedas, se obtuvo una carta
épica y se jugaron movimientos normales. No se modificó código de experiencia
para corregir los hallazgos de este informe. Después se importaron los siete
memes solicitados; el catálogo pasó a 244 memes y 250 entradas en el álbum.

## Correcciones prioritarias

### 1. Carta ampliada desborda en horizontal — alta

**Observado:** en 852×393, el diálogo de inspección de carta muestra la franja
de error `BOTTOM OVERFLOWED BY 174 PIXELS`. El registro del navegador confirma
`A RenderFlex overflowed by 174 pixels on the bottom`. Parte de la carta y los
controles de giro quedan fuera de la pantalla.

**Cambio:** calcular el tamaño de la carta usando tanto el ancho como la altura
disponible. En horizontal, colocar carta y controles en dos columnas o usar
contenido desplazable; mantener siempre visible el botón de cerrar.

Código: `_InspectCardDialogState` en `lib/home.dart`.

### 2. Wordle deja Enviar y Borrar fuera de vista — alta

**Observado:** en 360×740, la tercera fila del teclado queda bajo el borde
inferior. Hay que desplazar el juego para utilizarla y los gatos quedan
recortados en la parte superior. Esto oculta sus reacciones al enviar palabras.

**Cambio:** fijar el teclado abajo, reservar su altura y adaptar las seis filas
del tablero al espacio restante. Compactar instrucciones y mantener visibles
mascotas, mensaje y teclado. Evitar depender de una resta fija de altura.

Código: `WordleScreen`, `tileSize` y `ListView` en `lib/wordle.dart`.

### 3. «A la colección» no lleva a Colección — alta

**Observado:** después de abrir un sobre, el botón cierra el diálogo y deja
seleccionada la pestaña Sobres.

**Cambio:** devolver una acción desde el diálogo y seleccionar Colección en la
pantalla principal. Destacar la carta recién obtenida y, si hace falta,
desplazar el álbum hasta ella.

Código: `_openPack` y `CardRevealDialog` en `lib/home.dart`.

### 4. El álbum incluye seis cartas que los sobres no entregan — alta

**Confirmado en código:** `cardNames` contiene seis cartas de ejemplo más los
memes; `openPack()` genera únicamente IDs desde `sampleCardCount` en adelante.
El contador de colección usa todas las entradas. Con los siete memes nuevos,
hay 250 entradas y 244 resultados posibles en los sobres.

**Cambio:** entregar las seis cartas iniciales como bienvenida o excluirlas
del álbum coleccionable y de su denominador. El progreso debe poder alcanzar
el 100 %.

Código: `cardNames`, `sampleCardCount` y `openPack` en `lib/store.dart`;
contador de colección en `lib/home.dart`.

### 5. Las pestañas comparten el desplazamiento — media/alta

**Observado:** tras situar Inicio arriba, pasar a Colección, desplazarse por el
álbum y regresar a Inicio, la portada aparece desplazada hasta Galactic Leap
y los próximos juegos. La posición de Colección afecta a Inicio.

**Cambio:** asignar una clave y posición de desplazamiento independientes a
cada página. Conservar también sus estados para que la habitación no reinicie
su secuencia cada vez que se cambia de pestaña.

Código: selección `[home(), packs(), collection(), notes()][page]` y los
`ListView` sin claves independientes en `lib/home.dart`.

## Diseño y animaciones por pantalla

### Inicio y habitación

- La habitación ocupa aproximadamente la mitad de la primera pantalla móvil.
  La tarjeta destacada de Bloques es grande y los otros tres juegos requieren
  desplazamiento. Propuesta: habitación compacta/expandible y accesos a juegos
  con una jerarquía más uniforme.
- En la comida automática a 360×780, Lady se acerca al centro y se superpone
  visualmente con Maru; «ñam ñam ñam» queda junto a la oreja de Maru. Separar al
  espectador, reducir su tamaño o situarlo al fondo, y anclar el texto a la
  mascota que come. La comida y el arenero comparten posiciones centrales en
  el código; revisar ambos con esta misma regla.
- La respiración se ve más asentada y la reacción de corazón al tocar se
  reconoce. Mantener esas cualidades y mejorar las transiciones de caminar,
  acercarse, apoyar patas y volver al sitio, en lugar de deslizar todo el cuerpo.
- Hay diferencias visuales entre gatos vectoriales y accesorios como planta
  y ovillo hechos con emoji. Dibujar esos accesorios con la misma paleta y
  línea de las mascotas haría la escena más coherente entre dispositivos.
- El texto auxiliar de la habitación usa 10 px y es tenue. Aumentar tamaño y
  contraste de instrucciones y pensamientos sin agrandar toda la escena.

### Bloques & bigotes

- El tablero es claro, las piezas se distinguen y la limpieza de una línea
  tiene mascota, partículas y mensaje reconocible.
- En 360×740, el tablero y bandeja caben, pero «Nueva partida» queda fuera de
  la primera vista. Compactar panel de mascotas e instrucciones para reservar
  espacio estable a bandeja y acciones.
- La bandeja no presenta sus piezas como botones descriptivos en la lectura
  de accesibilidad, aunque el tablero sí etiqueta sus casillas. Añadir nombre
  de forma, selección y estado de cada pieza.
- Mantener celebraciones breves que permitan ver dónde se limpió la línea;
  graduar el tamaño y la duración según el número de líneas.

### Palabras & bigotes

- Resolver primero el teclado fuera de vista. Las letras y colores se leen
  bien cuando el tablero y teclado están visibles.
- Separar feedback de palabra inexistente, intento válido sin coincidencias,
  coincidencia parcial y victoria. Actualmente dos errores distintos utilizan
  la misma reacción de llorar; una inclinación curiosa encaja mejor con un
  error de vocabulario.
- El código elige respuestas al azar entre todas las entradas del diccionario.
  Mantenerlo amplio para validar intentos y usar un conjunto curado para las
  respuestas. Podrían existir modos «chileno», «general» y «difícil», con una
  breve explicación de la palabra al terminar.
- Corregir plurales como «1 victorias» y hacer explícito «+100 monedas» en la
  recompensa visual, además de actualizar el saldo.

### Dulces & bigotes

- El tablero completo cabe en las vistas verticales revisadas y las seis
  piezas tienen símbolos diferentes. La creación del rayado se reconoce por
  las líneas y su halo.
- Los potenciadores muestran principalmente icono y cantidad. Añadir nombres,
  explicación al seleccionar y estado activo claro. Etiquetar también ayuda
  y reinicio, que aparecen sin nombre en la accesibilidad.
- Hacer más explícitas las casillas con gelatina y las capas restantes.
  Los nombres de casilla accesibles no indican gelatina ni tipo de especial.
- La ayuda es un bloque largo de texto. Sustituirla por ejemplos visuales de
  3, 4, 5 y L/T; dejar fusiones avanzadas en una sección expandible.
- La creación y activación de especiales deberían tener gestos distintos de
  las mascotas y una pausa visual breve que muestre dónde nace el especial.
- El flujo revisado muestra puntos y movimientos. En `sweet_screen.dart` no
  hay entrega de monedas al monedero compartido al ganar. Definir una
  recompensa de nivel y comunicarla, para conectar este juego con los sobres.

### Galactic Leap

- Selección de mascota, salto automático, estela, derrota y saldo se entienden.
  Los gatos mantienen sus patrones originales.
- Añadir una entrada guiada breve y controles pulsados más visibles; el salto
  empieza inmediatamente. Mostrar una cuenta atrás corta al reanudar si ayuda
  a recuperar la orientación.
- En la derrota, permitir elegir otra mascota y volver a Inicio junto a
  «Otra aventura», sin tener que salir y reabrir para cambiar de personaje.
- Reservar una franja visual superior para el HUD: plataformas y monedas
  pueden pasar detrás de puntos, cámara y pausa. Mejorar contraste de monedas
  contra el cielo y distinguir mejor la nube eléctrica de una plataforma segura.
- La cámara ofrece vista previa. Si se busca guardar un recuerdo, añadir una
  acción de descargar/compartir en esa vista, adecuada a web y Android.
- Corregir «1 monedas». Explicar que el récord y las monedas persisten, pero
  una partida en curso se pierde al cerrar o recargar.

### Sobres y Colección

- El sobre, la rareza épica y el reverso de carta tienen una identidad visual
  clara. El meme mantiene su proporción en la carta inspeccionada.
- Durante la apertura, la mascota entra parcialmente recortada por encima del
  sobre. Dar espacio a su silueta y coordinar patas y desgarro del borde para
  que se vea el contacto físico.
- Tras obtener la primera carta, Inicio sigue diciendo «Abre tu primer sobre
  con las monedas de bienvenida». Actualizar ese texto según el progreso.
- La colección muestra muchos filtros, una fila de gatos y un álbum de
  cientos de interrogantes. Compactar filtros y ofrecer una vista de cartas
  obtenidas, con álbum completo como opción. Mostrar la carta nueva primero.
- Explicar los distintivos `+1`, `+6`, `+9` y ofrecer zoom de la imagen para
  memes cuyo texto sea pequeño.
- Riesgo de rendimiento confirmado por la estructura, no por medición:
  `GridView.builder(shrinkWrap: true)` dentro de `ListView` expone las 250
  entradas de una vez a la accesibilidad. Evaluar `CustomScrollView` y
  `SliverGrid` para construir lo visible y reducir trabajo.

### Nuestro bloc

- En vertical, editor y botón de crear nota se leen bien.
- En 852×393, la cabecera, las mascotas y el botón consumen casi toda la
  altura y dejan el mural en una franja mínima. Compactar cabecera o usar dos
  columnas en horizontal.
- Las notas tienen tamaño fijo 170×160 y vista de cinco líneas, pero admiten
  300 caracteres. Propuesta: abrir primero una lectura completa y ofrecer
  edición y borrado como acciones claras. Comprobar notas superpuestas.
- Añadir estado «Guardado en este dispositivo» y acceso a «Conectar» en el
  propio bloc, para que la explicación de compartir tenga una acción cercana.
- El editor abre con foco; comprobar su espacio con el teclado real de Android.

## Reglas comunes recomendadas

1. Mantener tamaños coherentes de botones principales, títulos, saldos y ayudas.
   Subir textos auxiliares de 10–11 px a un tamaño que se lea sin acercarse.
2. Unificar la forma de mostrar monedas obtenidas y el progreso hacia un sobre.
3. Añadir preferencias para reducir movimiento y controlar vibración. No hay
   una comprobación explícita de `MediaQuery.disableAnimations` en los pintores
   y controladores revisados.
4. Completar etiquetas de accesibilidad de piezas, especiales y botones con
   iconos; evitar nombres duplicados como «A A» en el teclado de Wordle.
5. Unificar el idioma de controles del sistema: aparecieron «Back» y
   «300 characters remaining» pese a la interfaz española.
6. Probar en un A55 real fuentes ampliadas, teclado abierto, barras del sistema,
   cambio de orientación y partidas con muchas partículas antes de considerar
   cerrado el ajuste móvil.

## Orden sugerido de trabajo

1. Desborde de carta, teclado de Wordle, destino de «A la colección» y álbum
   completables.
2. Estados y desplazamientos independientes por pestaña; distribución móvil
   de Inicio, Bloques y bloc; separación de mascotas al comer/usar arenero.
3. Legibilidad, tutoriales visuales, potenciadores y recompensas consistentes.
4. Coreografía de mascotas, ajustes de movimiento y medición en teléfono real.
