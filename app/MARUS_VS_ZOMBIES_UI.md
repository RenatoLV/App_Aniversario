# UI de Marus vs Zombies

Implementación integrada en Patio → Marus vs Zombies. El juego actual dibuja
arte vectorial original mediante Canvas/CustomPainter de Flutter. No requiere
assets raster ni añadir Flame para ejecutar esta versión.

## Carta, insignia y herramientas

Código reutilizable: `lib/marus_zombies/mz_widgets.dart`.

```dart
import 'package:flutter/material.dart';
import 'package:nuestro_rincon/marus_zombies/mz_catalog.dart';
import 'package:nuestro_rincon/marus_zombies/mz_widgets.dart';

// Carta 60 × 80, marco grueso y oscurecimiento proporcional a la recarga.
MzSeedCard(
  cat: MzCat.launcher,
  remaining: 4.2, // segundos restantes, calculados desde el reloj de simulación
  selected: true,
  affordable: true,
);

MzResourceBadge(value: 150);

Container(
  decoration: mzHudDecoration(),
  child: seedTray,
);

MzActionButton(
  label: 'Atún',
  active: tunaSelected,
  onTap: selectTuna, // null mantiene el aspecto de juego, pero desactiva el toque
  child: const Column(
    mainAxisSize: MainAxisSize.min,
    children: [Icon(Icons.set_meal), Text('Atún')],
  ),
);
```

`mzHudDecoration(badge: true)` aporta verde oscuro, borde de madera dorada de 3 puntos
y sombra hacia abajo. `MzOutlinedText` combina texto con Paint.stroke negro
y relleno. `MzCooldownPainter` oscurece de abajo hacia arriba y drena con el
tiempo: el número blanco de 28 puntos tiene contorno y sombra negros.

`mzActionDecoration` expone el gradiente, contorno y sombra de las herramientas.
El widget anima 4 puntos de desplazamiento y reduce la sombra de 4 a 1 al
presionar; restablece el relieve al soltar o cancelar. El bisel interior crema
usa un borde uniforme para que Flutter pueda pintarlo con esquinas redondeadas.

El panel de cartas ocupa el lateral izquierdo con scroll vertical en landscape;
en vertical vuelve a la barra superior con scroll horizontal. La integración de Draggable,
fantasma, celda imantada y recogida animada vive en `mz_game_screen.dart`.
SafeArea conserva 44 puntos laterales; herramientas 64 puntos y controles
de sistema 48. En landscape pequeño las casillas se adaptan al espacio
disponible: 80 × 100 por cada una de 45 casillas no cabe en todos los móviles.

## Césped y sombra de base

Código en `lib/marus_zombies/mz_painter.dart`:

```dart
void paintGround(Canvas canvas, Rect board, Rect footprint) {
  mzDrawGrass(canvas, board); // 5 × 9 rectángulos alternados, sin bordes
  mzDrawGroundShadow(canvas, footprint); // elipse negra al 33 %
  // Después se dibuja la entidad. Su movimiento vertical no mueve la sombra.
}
```

La función se aplica al patio; los demás mundos alternan sus tonos de arena,
madera o suelo holográfico. Los personajes tienen contornos oscuros gruesos,
colores saturados, partes animadas y herramientas específicas de su unidad.

## Equivalente opcional en Flame

Este fragmento sirve para una futura integración de sprites en un proyecto
que tenga Flame instalado; no forma parte de los imports del juego actual.
El origen local de los hijos sigue siendo la esquina superior izquierda del
padre, aunque su ancla sea inferior central, según la
[documentación de PositionComponent](https://docs.flame-engine.org/latest/flame/components/position_component.html).

```dart
import 'dart:ui';
import 'package:flame/components.dart';

class GroundedCat extends PositionComponent {
  GroundedCat({required Sprite sprite, required Vector2 dimensions,
    required Vector2 groundPosition})
    : super(position: groundPosition, size: dimensions,
        anchor: Anchor.bottomCenter, children: [
          SpriteComponent(sprite: sprite, size: dimensions.clone(),
            position: Vector2(dimensions.x / 2, dimensions.y),
            anchor: Anchor.bottomCenter),
        ]);

  final Paint shadow = Paint()..color = const Color(0x55000000);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawOval(Rect.fromCenter(
      center: Offset(size.x / 2, size.y - size.y * .04),
      width: size.x * .78, height: size.y * .12), shadow);
    // Los hijos se renderizan encima. Anima el hijo, manteniendo fija esta base.
  }
}
```

## Verificación

Las pruebas de pantalla ejercitan colocación por toque y arrastre, pausa,
velocidad x2 y navegación desde Patio; generan previews con RENDER_MZ=true.
Las pruebas de campaña completan las 50 misiones sin poderes comprados.
Las mediciones de FPS y respuesta háptica en teléfonos físicos siguen pendientes.


## Revisión del escenario y composición

`mz_scene_layers.dart` pinta casa y tejado de terracota a la izquierda, camino de
piedra, valla irregular, cielo y árboles distantes, y setos en el extremo de
entrada de la horda. Todo el escenario está recortado a su área para no
invadir las cartas. El césped incorpora pequeños grupos de hierba y flores,
con colores verdes saturados y sin líneas de cuadrícula.

La insignia horizontal reduce la altura del HUD. Las herramientas iniciales
son Atún, Pala y Poderes; este último despliega los poderes y sus costes.
Los avisos de juego siguen visibles en el HUD. Los retratos reciben luz
suave desde arriba a la izquierda; las unidades de campo aumentan de tamaño.

Gatos e invasores se dibujan en una lista conjunta ordenada por fila y
posición X. Como las filas determinan la posición Y de sus pies, la fila
inferior se dibuja después y oculta correctamente los objetos de la superior.
La sombra permanece fija mientras las piezas de la entidad se mueven.


## Identidad de Maru y Lady y revisión de arte

La paleta y las reglas de contorno viven en `mz_art_style.dart`; los personajes
por piezas se construyen en `mz_character_art.dart`. Todos los retratos y
unidades de batalla usan el mismo dibujo. Maru conserva rayas y ojos verdosos;
Lady conserva máscara bilateral, corona caramelo y ojos ámbar. Los apodos del
catálogo se muestran con su rol original en el almanaque.

`MzSceneryCache` registra fondo y frente en dos Picture y los invalida por
tamaño, tablero o mundo. La geometría jugable no cambia. La puerta tiene arco
superior, base recta y umbral unido al suelo de la fachada.

`MzVisualFeedback` observa daño, ataque y desplazamiento reales; usa el tiempo
de simulación y no modifica snapshots. Sus respuestas respetan pausa y
movimiento reducido. Las instrucciones del HUD se adaptan a la herramienta
y a la carta seleccionada, preservando los avisos temporales.

La auditoría, archivos modificados, apodos y pruebas están documentados en
`MARUS_VS_ZOMBIES_ART_REVIEW.md`.
