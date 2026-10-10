# Revisión visual de Marus vs Zombies — 10 de octubre de 2026

Continuación: [primera fase V3](MARUS_VS_ZOMBIES_VISUAL_EVOLUTION_V3.md)
documenta los perfiles piloto y la evolución posterior del mapa y preparación.
El diagnóstico de esta revisión se conserva como historial.

El rediseño está integrado en el juego de Patio. Mantiene Flutter, Canvas y
CustomPainter: los PNG de revisión son capturas de Flutter, no recursos del juego.

La evolución posterior de sombreado, expresiones, anticipación, terreno y efectos
está documentada en [MARUS_VS_ZOMBIES_VISUAL_EVOLUTION.md](C:/Users/renat/Documents/github/Aniversario/app/MARUS_VS_ZOMBIES_VISUAL_EVOLUTION.md),
con comparación visual, límites de efectos y mediciones del costo de dibujo.

## Auditoría y alcance

La versión inicial repetía anatomía y expresiones entre unidades, trataba a Maru
como un gato naranja y no reproducía la máscara bilateral de Lady. También
repetía nubes y setos, mostraba un ajedrezado demasiado contrastado y usaba una
puerta estrecha redondeada en ambos extremos. Las cartas y herramientas ya
funcionaban; se conservaron sus interacciones y se revisó su presentación.

Se trabajó por etapas: personajes, escenario, HUD y respuestas de animación.
Después se corrigieron específicamente la casa y las instrucciones de uso, y
se añadieron los apodos solicitados. Los cambios previos del proyecto siguen
presentes. No se añadieron dependencias ni se reescribió la simulación.

## Identidad y decisiones de arte

Maru conserva pelaje gris atigrado, pecho crema, rayas oscuras y ojos verdosos.
Lady conserva pelaje blanco, corona caramelo, dos máscaras oscuras separadas
por una franja blanca y ojos ámbar. La referencia es `lib/cat_character.dart`.
Los acentos verdes, azules, rojos, dorados y cian se aplican a cada función sin
ocultar esos rasgos. Los invasores llevan una versión apagada de la misma familia.

Los dibujos comparten coordenadas locales 100×110, luz superior izquierda y
contornos con tres jerarquías: exterior 3, interior 1,8 y detalle 1,2. Las telas
y marcas tienen relleno plano; pelaje, hielo, madera y metal reciben tratamientos
distintos. Las sombras de contacto quedan fijas cuando las piezas se animan.

| Unidad | Construcción aplicada |
| --- | --- |
| Lanzador | Lady agachada, gorro de hoja y ovillo verde sostenido con la pata |
| Girasol | Maru sentado y ancho, expresión tranquila y collar de pétalos |
| Maru Wuatón | Barrera baja y ancha; armadura visible únicamente cuando la tiene |
| Siberiano | Lady esponjosa, acento helado y bufanda azul |
| Caja sorpresa | Maru asomado, caja con tapa y señal de armado |
| Gatitos bomba | Maru y Lady juntos con collares rojos y mecha |
| Catapulta | Maru en rascador con cuerda y brazo de lanzamiento articulado |
| Bumerán | Lady con juguete de pez y gorro dorado |
| Resorte | Lady sobre un muelle y base metálica |
| Relámpago | Lady con cresta de electricidad y emblema de rayo |
| Láser | Maru con coraza, visor y emisor cian |
| Gran León | Forma mítica de Maru con melena; aparece durante el efecto real de invocación |

Los quince invasores conservan sus arquetipos: ropa rota, cono veterinario,
balde oxidado, bandera de pez, vendas, sarcófago, saco, sombrero pirata, alas,
cañón, piano, pico, placas robóticas, escudo y robot bulldog con científico.
Los apodos están en el catálogo; el almanaque muestra también el rol original.

| Apodo | Arquetipo |
| --- | --- |
| Zombimaru | Gato zombi |
| Cono Wuatón | Cono veterinario |
| Lady Gordota | Balde oxidado |
| Maru Banderón | Abanderado |
| Marumomia | Momia |
| Faraón Wuatón | Faraón |
| Lady Robatún | Ladrón de tumbas |
| Lady Piratona | Corsario |
| Lady Aladota | Loro zombi |
| Maru Cañontrón | Cañón de huesos |
| Maru Pianotrón | Pianista |
| Lady Topota | Minero |
| Maru Locotrón | Mecha-gato |
| Wuatón Blindado | Perro escudo |
| Dr. Maru Cat-trófico | Jefe bulldog mecánico |

## Escenario, interfaz y animación

- Césped con variación suave, casillas sin contorno, pequeños grupos de hierba,
  profundidad en el borde de tierra y sombra ambiental de la valla.
- Valla inclinada, nubes de distintas formas, tejado con tejas en perspectiva,
  follaje, fachada con dos planos y sombra sobre el terreno.
- Puerta con arco superior y base recta, ancho y alto proporcionados, paneles,
  bisagras, picaporte, medallón de huella y escalón. La fachada termina al nivel
  del umbral; la puerta no queda flotando a mitad de una pared. No invade la
  posición de las Roombas ni ninguna casilla del jardín.
- Arena, tablones, tierra del Oeste y paneles del futuro tienen superficies
  propias. Agua, puentes, vías, tumbas y nodos mantienen su dibujo dinámico.
  Los símbolos de nodos se trazan como formas vectoriales, sin glifos faltantes.
- Cartas con ilustración, etiqueta de coste, selección marcada y recarga con
  oscurecimiento proporcional. Contador, monedas recogibles y vuelo de hierba
  comparten el mismo emblema. Herramientas y botones usan relieve físico.
- La instrucción cambia según selección, arrastre, atún, pala y poder humano;
  los avisos y errores temporales de la partida mantienen prioridad.
- Respiración, cola y movimiento por piezas conservan la animación del juego.
  Retroceso y reacción de daño responden a cambios reales de ataque, ráfaga,
  vida o armadura. La marcha se detiene cuando no hay desplazamiento.
  Las explosiones usan el efecto existente, con seis bocanadas de pelusa.
- Las reacciones usan el reloj de simulación: pausa las congela y movimiento
  reducido elimina las respuestas adicionales. No alteran daño ni posiciones.

## Archivos de esta revisión

| Archivo | Responsabilidad |
| --- | --- |
| `lib/marus_zombies/mz_art_style.dart` | Paleta de Maru/Lady, materiales, contornos y emblema de hierba |
| `lib/marus_zombies/mz_character_art.dart` | Once defensores, quince invasores y Maru ancestral |
| `lib/marus_zombies/mz_scene_layers.dart` | Escenarios, casa, superficies y caché de fondo/frente |
| `lib/marus_zombies/mz_scenery.dart` | Exportación compatible de las funciones del escenario |
| `lib/marus_zombies/mz_painter.dart` | Integración de arte, profundidad, nodos, proyectiles y efectos |
| `lib/marus_zombies/mz_visual_feedback.dart` | Reacciones transitorias que sólo leen el combate |
| `lib/marus_zombies/mz_widgets.dart` | Cartas, insignia, botones e ilustraciones de herramientas |
| `lib/marus_zombies/mz_game_screen.dart` | Caché, reloj de animación e instrucciones contextuales |
| `lib/marus_zombies/mz_catalog.dart` | Apodos y nombres de rol; estadísticas conservadas |
| `lib/marus_zombies/mz_screen.dart` | Rol original junto al apodo en el almanaque |
| `test/marus_zombies/screen_test.dart` | Tamaños, herramientas, cinco mundos y lámina de personajes |
| `test/marus_zombies/visual_feedback_test.dart` | Reacciones a combate real, pausa y ausencia de mutación |
| `MARUS_VS_ZOMBIES_UI.md` | Referencia actualizada de widgets y dibujo |
| `MARUS_VS_ZOMBIES_ART_REVIEW.md` | Auditoría, decisiones, apodos y evidencias |

## Rendimiento y compatibilidad

El escenario estático se registra en dos `ui.Picture`: fondo y primer plano.
Se reutilizan entre fotogramas y se regeneran cuando cambia tamaño, rectángulo
de tablero o mundo. Se liberan al invalidar o cerrar la partida. Los elementos
que cambian durante el combate se pintan después, conservando el orden por fila.
Esto evita reconstruir las formas estáticas; no constituye una medición de FPS.

El estado de animación se depura al desaparecer las entidades y no se guarda.
La geometría 5×9, costes, daño, oleadas y guardado permanecen iguales. Se
comprobaron las huellas SHA-256 sin cambios de simulación, modelos, niveles y
progreso. El catálogo recibió solamente los cambios de texto solicitados.

## Validación y comparación

Comandos ejecutados desde `app`:

```powershell
flutter analyze --no-pub
flutter test --no-pub --dart-define=RENDER_MZ=true --reporter expanded
flutter test --no-pub test/marus_zombies test/patio_screen_test.dart --dart-define=RENDER_MZ=true --reporter expanded
flutter build web --no-pub
```

La suite completa pasó 224 pruebas. Tras los ajustes de casa y apodos, la suite
del módulo y Patio pasó 43 pruebas. El análisis final no reportó problemas y
la compilación web terminó correctamente. Las pruebas incluyen campaña,
persistencia, arrastre, imantación, pausa, x2, atún, pala, compra y botones
deshabilitados. Las capturas se generan mediante RenderRepaintBoundary de Flutter.

Se verificaron pantallas 320×568, 390×844, 844×390, 1280×800, 1366×768 y
1920×1080. También se renderizaron los cinco mundos y las casillas de los bordes.
La lámina muestra los once gatos y quince invasores en tamaños 120 y 32, además
de Maru ancestral. Fue inspeccionada visualmente.

Las capturas iniciales conservadas están en `build/previews/mz-before/` y las
actuales en `build/previews/mz-battle-*.png`, `mz-world-*.png` y `mz-units.png`.
La comparación de batalla usa el mismo nivel 8, mismo equipo, posiciones,
recursos y secuencia de interacción. La lámina inicial tenía armadura activada
en todos los gatos; la nueva muestra gatos normales y miniaturas con armadura,
por lo que no se presenta como una comparación de estados idénticos.

Estos archivos de revisión viven en `build`, están ignorados por Git y no se
incluyen como assets del juego. Los tests regeneran las capturas actuales.

| Antes, 844×390 | Después, 844×390 |
| --- | --- |
| ![Versión de partida](C:/Users/renat/Documents/github/Aniversario/app/build/previews/mz-before/battle-844.png) | ![Personajes, casa y HUD revisados](C:/Users/renat/Documents/github/Aniversario/app/build/previews/mz-battle-844.png) |

![Personajes y apodos actuales](C:/Users/renat/Documents/github/Aniversario/app/build/previews/mz-units.png)

## Límites de la revisión

No se midieron FPS, temperatura ni respuesta háptica en teléfonos físicos, ni
se realizó una prueba manual de campaña en dispositivo. El mapa y la preparación
conservan su estructura visual anterior; esta revisión priorizó personajes,
escenario y HUD de batalla. La adaptación vertical funciona, aunque landscape
sigue ofreciendo el tamaño más legible para una cuadrícula de nueve columnas.
