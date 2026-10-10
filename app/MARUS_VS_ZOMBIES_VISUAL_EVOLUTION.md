# Evolución visual de Marus vs Zombies

Continuación implementada: [evolución visual V3](MARUS_VS_ZOMBIES_VISUAL_EVOLUTION_V3.md).
Esta revisión conserva las mediciones y decisiones de la etapa anterior.

Implementación y revisión del 10 de octubre de 2026. El módulo sigue integrado
en los juegos del Patio y conserva Dart, Flutter, Canvas y CustomPainter.
Las imágenes de este documento son capturas de Flutter; no se usan como sprites.

## Auditoría y dirección artística

Las referencias adjuntas orientan profundidad, expresividad y efectos. La
comparación de implementación se hizo contra capturas reales del proyecto.

| Prioridad | Diagnóstico inicial | Intervención | Riesgo / esfuerzo |
| --- | --- | --- | --- |
| Alta | Rostros y poses similares; volumen dependiente de gradientes | Capas de sombra y luz, mejillas, expresiones, movimiento de cabeza y accesorios | Medio: comprobar cartas pequeñas y anclajes |
| Alta | Disparos e impactos con poca respuesta | Anticipación condicionada por objetivos, retroceso, estelas y efectos por familia | Medio: observar acciones sin alterar combate |
| Media | Césped repetitivo y transiciones abruptas | Parches orgánicos, tréboles, piedras, luz direccional y vegetación por capas | Bajo: escenario estático cacheado |
| Media | Colocación inválida poco explícita | Borde luminoso y cruz de error; selección con transición breve | Bajo: conservar geometría y controles |

Se probaron primero Lanzador de Lady, Maru Wuatón y Zombimaru, en tamaños de
tablero y carta. Quince pruebas de pantalla pasaron antes de extender el
tratamiento compartido al catálogo. Maru mantiene sus rayas y pecho crema;
Lady mantiene corona caramelo, máscara bilateral y franja blanca.
Lady Robatún sigue siendo la ladrona; Maru Locotrón es el mecha-gato.
Gran León · Maru sigue siendo un aliado invocable.

## Cambios implementados

### Personajes

- Sombreado cel por capas: sombra principal fría, contacto y luz cálida superior.
- Contornos exteriores/interiores conservados en el espacio local 100 × 110.
- Sistema de expresiones neutral, contenta, concentrada, ataque, daño y desorientación.
- Mejillas, sombras del rostro y mirada que acompaña preparación/disparo.
- Cabeza, cola, patas y accesorios con transformaciones independientes.
- Squash & stretch moderado, con menor amplitud en unidades pesadas.
- Girasol más redondo y acogedor; Wuatón con párpados relajados y postura baja;
  Lady Gordota con cuerpo más robusto.
- Bufanda móvil, catapulta que se tensa, resorte que se comprime y bandera deformable.
- Engranajes animados del jefe y melena expresiva del León durante su invocación real.

### Escenario e interacción

- Césped con zonas orgánicas, motivos menos repetitivos y pequeñas variaciones.
- Sombras ambientales coherentes en los cinco mundos y transición de piedras al suelo.
- Tejas con sombra de solape, fachada con volumen y setos con luces y sombras internas.
- Vegetación situada detrás de unidades entrantes para que no oculte al jefe.
- Colocación resaltada con borde claro y cruz en destinos inválidos, además del color.
- Validación visual de costo y recarga con la misma referencia temporal del motor.
- Selección de cartas con una transición corta que respeta movimiento reducido.

### Combate

- Anticipación de hasta 180 ms para ataques temporizados con objetivo real.
  Se cancela si desaparece el objetivo. No retrasa ni adelanta el disparo.
- Las unidades de acción inmediata, como el láser, conservan su respuesta inmediata.
- Estelas de posiciones ya recorridas: fibras/motas, hielo y destellos del bumerán.
- Impactos distintos para daño corporal, armadura e hielo.
- Láser con halo y núcleo, descarga eléctrica por capas y explosión con onda y pelusa.
- Reacciones al daño de 200 ms y al ataque de 240 ms, gobernadas por tiempo de juego.
- Cutouts derrotados que se inclinan y se disipan en 360 ms, ordenados por profundidad.
  Retirar un gato con la pala no genera una derrota visual.
- Congelación y lentitud se representan únicamente mientras existen en la simulación.
- El modo de movimiento reducido omite estelas, partículas añadidas y cutouts de
  derrota, y conserva indicadores estáticos de ataques/estados importantes.

## Archivos de implementación

| Archivo | Responsabilidad |
| --- | --- |
| `lib/marus_zombies/mz_art_style.dart` | Paleta, expresiones, parámetros de animación y sombreado reutilizable |
| `lib/marus_zombies/mz_character_art.dart` | Anatomía, expresiones, piezas, materiales y poses por función |
| `lib/marus_zombies/mz_visual_feedback.dart` | Observación de acciones, anticipación, eventos transitorios y estelas |
| `lib/marus_zombies/mz_combat_art.dart` | Nueva capa de efectos, impactos, rayos y cutouts derrotados |
| `lib/marus_zombies/mz_scene_layers.dart` | Terreno, iluminación, casa, vegetación y caché del escenario |
| `lib/marus_zombies/mz_painter.dart` | Orden de dibujo, colocación, estados y conexión de efectos |
| `lib/marus_zombies/mz_widgets.dart` | Transición de selección de cartas |
| `lib/marus_zombies/mz_game_screen.dart` | Conexión del ajuste de movimiento reducido con las cartas |

No se añadieron dependencias. Se verificó por SHA-256 que `mz_simulation.dart`,
`mz_catalog.dart`, `mz_models.dart` y `mz_levels.dart` no cambiaron en esta evolución.
Los efectos de presentación no se guardan en el progreso ni escriben daño,
temporizadores, posiciones, recursos o números aleatorios del motor.

## Rendimiento y límites

El escenario mantiene sus dos Pictures cacheados por tamaño, tablero y mundo.
Se reutilizan tres geometrías corporales, las geometrías básicas del rostro,
las capas de sombreado y hasta 512 materiales opacos. Patas y proyectiles se
dibujan en coordenadas locales para evitar crear shaders distintos por posición.

La capa añadida limita sus eventos a 32, las estelas a 48 proyectiles con cinco
muestras cada uno y las figuras en desaparición a seis. Los impactos sostenidos
se agrupan visualmente en ventanas de 80 ms. Los rayos continuos se dibujan una
vez por carril. Los efectos existentes conservan el límite del motor.

No se añadieron desenfoques a personajes o efectos. `saveLayer` se reserva para
desapariciones breves e invocación; se conserva el usado por la previsualización.
`shouldRepaint` del tablero continúa siendo verdadero: la simulación es mutable
y comparar la identidad del delegado omitiría acciones reales realizadas en el
mismo instante de juego. El tablero y los retratos tienen RepaintBoundary;
los retratos estáticos y el escenario aprovechan sus cachés.

Se midió el registro de comandos de Canvas en el mismo entorno de `flutter test`,
con un tablero de 960 × 540, 25 defensores y 30 invasores. Cada ejecución hizo
50 calentamientos y siete lotes de 100 dibujos, reutilizando el escenario.

| Versión | Mediana CPU por dibujo |
| --- | ---: |
| Anterior | 5,366 ms |
| Con las mejoras y cachés | 5,781 ms |
| Diferencia | +0,415 ms, aproximadamente +7,7 % |

La primera implementación de capas costó 6,726 ms; la reutilización redujo ese
sobrecosto. Los JSON están en `build/previews/mz-render-before.json` y
`build/previews/mz-render-v2-after.json`. Esta prueba corresponde a una escena fija
con unidades: excluye rasterización GPU, HUD, simulación y oleadas de efectos.
No representa FPS ni asegura rendimiento en un teléfono. Queda pendiente medir
GPU, memoria, temperatura y respuesta háptica en Android/iOS físicos.

## Validación

- `flutter analyze`: sin problemas.
- Suite completa: 230 pruebas aprobadas; el perfil de rendimiento queda omitido
  por defecto y se ejecuta por separado con `PROFILE_MZ=true`.
- Módulo y acceso desde Patio: 49 pruebas aprobadas.
- Compilación web release: completada.
- Capturas y controles revisados en 320 × 568, 390 × 844, 844 × 390,
  1280 × 800, 1366 × 768 y 1920 × 1080; superficies de los cinco mundos.
- Pruebas añadidas de anticipación cancelable, observación sin mutaciones,
  estelas acotadas, pausa, desaparición, pala y presupuesto de eventos.
- Capturas del combate proceden de avance real de la simulación y comprueban
  que pintar no modifica su snapshot.

Para regenerar capturas desde `app`:

```powershell
flutter test test/marus_zombies test/patio_screen_test.dart --dart-define=RENDER_MZ=true
flutter test test/marus_zombies/render_profile_test.dart --dart-define=PROFILE_MZ=true --dart-define=ART_PHASE=after
```

## Comparación visual

Antes:

![Patio anterior](C:/Users/renat/Documents/github/Aniversario/app/build/mz-evolution-before/mz-battle-844.png)

Después:

![Patio actualizado](C:/Users/renat/Documents/github/Aniversario/app/build/previews/mz-battle-844.png)

Disparo y respuesta del combate:

![Combate actualizado](C:/Users/renat/Documents/github/Aniversario/app/build/previews/mz-combat-fire.png)

Catálogo a tamaños de tablero y carta:

![Catálogo actualizado](C:/Users/renat/Documents/github/Aniversario/app/build/previews/mz-units.png)
