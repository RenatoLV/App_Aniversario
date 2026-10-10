# Marus vs Zombies — evolución visual V3

10 de octubre de 2026. Primera fase implementada y validada sobre V2. Se conserva
Flutter/Dart, Canvas, CustomPainter, integración con Patio y simulación a paso fijo.
Este documento registra cambios reales; no declara terminado el alcance completo
del prompt V3. No se añadieron paquetes, assets raster ni sistemas de partículas.

## Estado de partida y auditoría

Se leyeron ART_REVIEW, VISUAL_EVOLUTION, UI y PLAN y se inspeccionaron los archivos
del módulo, incluidos los observadores y efectos. Se revisaron las capturas reales
de mapa, catálogo, combate y Egipto y se regeneraron las pantallas del proyecto.
V2 ya tiene volumen cel, expresiones, anticipación, accesorios articulados,
reacciones, estelas acotadas y escenarios cacheados. Esas funciones se conservan.
La corrección anterior del pasillo de Roombas y las nubes forma parte del punto
de partida de V3; no se contabiliza como una mejora nueva de esta fase.

| Elemento | Problema / evidencia | Mejora | Archivo | Dificultad | Impacto | Riesgo de rendimiento | Prioridad | Estado |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Lanzador | `_face` compartía el contorno de otros atacantes; confirmado en lámina | Rostro estrecho y cabeza adelantada; ojos se estrechan durante preparación real | mz_character_art.dart | Media | Alto | Bajo | 1 | Implementado |
| Wuatón | Cabeza aplastada pero contorno y cejas similares al resto | Mejillas más amplias, proporción baja y expresión relajada | mz_character_art.dart | Media | Alto | Bajo | 1 | Implementado |
| Zombimaru | Se reconocía sobre todo por camiseta y dientes | Pose torcida en reposo, cabeza inclinada, ojos desnivelados y párpado caído | mz_character_art.dart | Media | Alto | Bajo | 1 | Implementado |
| Miniaturas | Mismos detalles de pelaje, bigotes y volumen que retratos grandes | Reducir detalle secundario según escala efectiva | mz_character_art.dart | Media | Medio | Bajo | 1 | Implementado |
| Portada/mapa | Fondo plano, chips lilas y nivel presentado como tarjeta Material | Marco de HUD, escena con protagonistas, temática verde/madera, niveles con relieve | mz_screen.dart / mz_menu_art.dart | Media | Alto | Bajo: decoración estática | 2 | Implementado |
| Preparación | FilterChip con retrato de 28 px; amenazas precedían al equipo | Cartas existentes ampliadas, equipo primero, objetivos con iconos y botones coherentes | mz_screen.dart | Media | Alto | Bajo | 2 | Implementado |
| Egipto | Arena con motas y líneas cortas repetidas; confirmado por dibujo y PNG | Dunas bajas discontinuas de contraste tenue | mz_scene_layers.dart | Baja | Medio | Bajo: Picture existente | 3 | Implementado |
| Otros invasores | Varios conservan rostro compartido aunque tienen equipo propio | Revisar perfiles específicos de Gordota, Momia, Pianotrón y Locotrón | mz_character_art.dart | Media | Alto | Por medir | 4 | Pendiente |
| Almanaque | Enemigos listados sin retrato; confirmado por código | Retratos amplios y paneles por facción | mz_screen.dart | Media | Alto | Bajo | 4 | Pendiente |
| Resultados | No se modificó su presentación en esta fase | Auditar celebración y jerarquía de recompensas | mz_game_screen.dart | Media | Medio | Por medir | 4 | Pendiente de revisión específica |
| Otros mundos | Tienen materiales propios; la casa/valla siguen compartidas | Ambientación periférica propia, sin alterar terrenos ni obstáculos | mz_scene_layers.dart | Media | Alto | Bajo si se mantiene caché | 4 | Pendiente |

Se priorizaron personajes piloto y pantallas de selección porque sus diferencias
se aprecian sin aumentar partículas ni intervenir en el motor. No se aplicó un
rediseño anatómico general a los once defensores y quince invasores.

## Cambios implementados y decisiones

### Personajes piloto y detalle por escala

`_FacePersona` es una variación pequeña del dibujo existente, no un sistema nuevo
de expresiones. Sus contornos quedan cacheados en `_faceShapes`. Lanzador usa un
perfil más estrecho y desplazado hacia delante. Wuatón utiliza un contorno de
mejillas amplias y una transformación de cabeza 1,10 × 0,75. Zombimaru incorpora
una inclinación corporal permanente, balanceo de marcha y rostro asimétrico.
Mantiene pelaje gris, rayas, pecho crema y mirada verdosa; Lady conserva la corona
caramelo, máscara bilateral, franja blanca y ojos ámbar.

El alto de los ojos interpola con `prepare`, que sigue procediendo del observador
de acciones reales. No se cambiaron temporizadores ni se retrasan ataques.
Marcha y cabeza usan el tiempo visual existente y su desfase por identificador;
no se consume aleatoriedad. Pausa, velocidad x2 y movimiento reducido continúan
gobernados por el reloj y los controles ya implementados.

Cuerpo y rostro consultan la escala efectiva de Canvas. Por debajo de 0,45 del
espacio local se omiten capas secundarias de volumen, mejillas y líneas de brillo;
se reduce el número de bigotes y marcas pequeñas. Permanecen las siluetas,
marcas principales, ojos, hocico y equipamiento. Esto también beneficia al dibujo
compartido del resto del catálogo en miniatura; no cambia sus proporciones.
No se afirma haber simplificado todas las piezas: patas y accesorios todavía
conservan buena parte de sus detalles originales.

### Portada, mapa y preparación

La portada usa `mzHudDecoration(badge: true)`. Su escena reúne cuatro gatos sobre
la superficie del mundo seleccionado, usando el mismo renderizador que batalla.
Los mundos tienen iconos y colores propios y conservan el bloqueo existente.
Los niveles reutilizan el marco, gradiente y sombra del HUD; muestran candados y
estrellas mediante MaterialIcons en lugar de caracteres dependientes de fuentes.

`MzWorldPostcard` comparte `mzPaintLawn`/`mzPaintWorldGround`, permanece dentro de
RepaintBoundary y solo repinta por mundo o presencia de protagonistas. Es una
ilustración decorativa: no representa un tablero interactivo ni sus obstáculos.

Preparación reutiliza `MzSeedCard` con selección y coste visibles, en lugar de
chips. Cada carta tiene Semantics e InkWell, preservando toque y activación por
teclado. El equipo aparece antes de las reglas y objetivos. En pantallas de menos
de 500 puntos de altura se reducen postal y cartas; el resto del contenido sigue
disponible mediante scroll. El botón de inicio sigue deshabilitado con equipo
vacío y la capacidad sigue siendo seis. No cambian catálogo permitido, desbloqueo,
navegación, compras ni recompensas.

Durante la revisión se corrigieron tres defectos: fuente de chips sin familia
explícita en capturas, estrellas que no se dibujaban con la fuente de revisión y
cartas inicialmente fuera de la vista en preparación horizontal. También se
ajustó el test de navegación para esperar a que el scroll terminara antes de tocar.

### Egipto

Se añadieron curvas de dunas bajas en una parte determinista de las casillas.
Usan transparencias leves, sin contorno cerrado oscuro ni símbolos de tumba.
El fondo sigue dentro del Picture cacheado: no se recalcula esta decoración por
frame. Las tumbas destructibles y las coordenadas jugables permanecen iguales.
Piratas, Oeste y Futuro se renderizaron como regresión; no reciben nuevos fondos
ni animaciones en esta primera fase.

## Archivos modificados en V3

- `lib/marus_zombies/mz_character_art.dart`: perfiles piloto y detalle adaptativo.
- `lib/marus_zombies/mz_menu_art.dart`: nueva postal vectorial estática y símbolos de mundos.
- `lib/marus_zombies/mz_screen.dart`: portada, mapa y preparación.
- `lib/marus_zombies/mz_scene_layers.dart`: dunas discretas de Egipto.
- `test/marus_zombies/screen_test.dart`: mapa/preparación en siete tamaños, capturas
  y comprobación de selección vacía y posterior inicio.
- Este documento y enlaces de continuidad en las revisiones anteriores.

No se editaron `mz_art_style.dart`, `mz_combat_art.dart`, `mz_visual_feedback.dart`,
`mz_widgets.dart`, `mz_game_screen.dart` ni `mz_painter.dart` durante esta fase V3.
Sus mejoras anteriores se reutilizan.

## Evidencia antes/después

Antes de editar se conservaron los PNG existentes en `build/mz-v3-before/`.
Las comparaciones de mapa, catálogo y Egipto usan las mismas pruebas, tamaños,
estado inicial, fase y contenido. Las escenas de combate usan la misma secuencia
determinista de pasos de simulación. Los PNG son evidencias, nunca assets.

| Mapa antes, 800 × 600 | Mapa después, 800 × 600 |
| --- | --- |
| ![Mapa V2](C:/Users/renat/Documents/github/Aniversario/app/build/mz-v3-before/mz-map.png) | ![Mapa V3](C:/Users/renat/Documents/github/Aniversario/app/build/previews/mz-map.png) |

| Catálogo antes, dibujos 120 y 32 px | Catálogo después, mismos dibujos y tamaños |
| --- | --- |
| ![Catálogo V2](C:/Users/renat/Documents/github/Aniversario/app/build/mz-v3-before/mz-units.png) | ![Catálogo V3](C:/Users/renat/Documents/github/Aniversario/app/build/previews/mz-units.png) |

| Egipto antes | Egipto después |
| --- | --- |
| ![Egipto V2](C:/Users/renat/Documents/github/Aniversario/app/build/mz-v3-before/mz-world-egypt.png) | ![Egipto V3](C:/Users/renat/Documents/github/Aniversario/app/build/previews/mz-world-egypt.png) |

Preparación horizontal actual:

![Preparación V3](C:/Users/renat/Documents/github/Aniversario/app/build/previews/mz-preparation-844.png)

No había una captura anterior de preparación: esta imagen es evidencia actual,
no una comparación antes/después. Las capturas bajo `build` están ignoradas por
Git y se regeneran con RENDER_MZ; conservar la carpeta de baseline para revisiones.

## Validación técnica

Comandos ejecutados desde `app`, con el SDK en `C:/src/flutter/bin/`:

```powershell
flutter analyze --no-pub
flutter test --no-pub test/marus_zombies test/patio_screen_test.dart --dart-define=RENDER_MZ=true --reporter expanded
flutter test --no-pub --dart-define=RENDER_MZ=true --reporter expanded
flutter test --no-pub test/marus_zombies/render_profile_test.dart --dart-define=PROFILE_MZ=true --dart-define=ART_PHASE=v3-before
flutter test --no-pub test/marus_zombies/render_profile_test.dart --dart-define=PROFILE_MZ=true --dart-define=ART_PHASE=after
flutter build web --no-pub
flutter devices --device-timeout 5
```

Análisis: sin problemas. Módulo y Patio: 55 aprobadas, una omitida.
Suite completa: 236 aprobadas, una omitida (perfil opt-in).
Perfil CPU: aprobado en ejecución separada. Compilación web release: correcta.
Mapa y preparación se comprobaron a 320×568, 390×844, 844×390, 1280×800,
1366×768, 1920×1080 y 800×600. Batalla conserva las seis resoluciones, arrastre,
pausa, x2, herramientas y capturas de combate real/movimiento reducido. Se
renderizaron los cinco mundos y el catálogo a 120/32 px. No se detectaron
desbordamientos en estas pruebas. La preparación usa scroll en pantallas bajas.

Se verificaron huellas SHA-256 idénticas antes/después para simulación, catálogo,
modelos, niveles y progreso, incluido el guardado. No se modificaron reglas,
economía, estadísticas, oleadas, RNG, colisiones ni sincronización.

## Rendimiento medido

Se repitió la prueba existente sobre el mismo tablero 960×540 con 25 defensores
y 30 invasores, 50 calentamientos y siete lotes de 100 dibujos. Se ejecutó antes
y después de V3, sin otra prueba de Flutter corriendo simultáneamente.

| Registro de comandos Canvas | Mediana CPU |
| --- | ---: |
| Baseline actual, antes de V3 | 5,98374 ms |
| V3, después | 5,99540 ms |
| Diferencia | +0,01166 ms, aproximadamente +0,2 % |

La diferencia es pequeña frente a la dispersión entre lotes. No acredita una
mejora de velocidad ni FPS estables. JSON: `build/previews/mz-render-v3-before.json`
y `mz-render-v3-after.json`. Los 5,366/5,781 ms de V1/V2 quedan como historia de
otra ejecución; no se usan como baseline de esta comparación.

La prueba excluye GPU, HUD, memoria, simulación y oleadas intensas de partículas.
`flutter devices` detectó Windows, Chrome y Edge; ningún Android/iOS conectado.
Quedan pendientes tiempos UI/raster, memoria, picos y temperatura en dispositivo.
No se añadieron filtros, saveLayer ni efectos temporales a batalla. La postal
del menú tiene coste fuera de este benchmark y no se presenta como medido.

## Pendientes de la primera entrega (historial)

1. Dar perfiles propios al resto del catálogo, especialmente Gordota, Pianotrón,
   Locotrón y los dos atacantes con juguetes; validar cada uno en miniatura.
2. Modernizar almanaque y resultados. Los retratos de defensores ya reciben el
   dibujo V3 compartido; la estructura del almanaque y sus enemigos aún no cambió.
3. Mejorar la periferia de cada mundo y sus obstáculos, no solamente el suelo.
4. Revisar en vídeo recuperación, movimiento secundario y legibilidad de oleadas
   intensas. Las capturas de varios instantes no reemplazan una revisión temporal.
5. Afinar detalle adaptativo de patas y accesorios y revisar texto ampliado y
   contraste de estados bloqueados con métricas de accesibilidad específicas.
6. Perfilar en Android físico. No se promete rendimiento móvil a partir del test CPU.

Se conserva la estructura del juego y el historial V1/V2. El avance de esta fase
es verificable en los tres pilotos, mapa/preparación y arena; no se atribuyen a
V3 nuevas partículas, cambios de balance ni una renovación completa del catálogo.


## Continuación V3 — cuatro enemigos (10-10-2026)

Se revisaron este documento, `mz_character_art.dart`, los materiales, el
observador visual, el painter, modelos y acciones especiales reales. Los cuatro
invasores reutilizaban el torso y gran parte del rostro genérico; el piano era
principalmente un accesorio plano. Se priorizaron cambios de masa y postura
antes de detalles. Los tres pilotos anteriores permanecen en su construcción V3.

### Cambios implementados

| Enemigo | Silueta y materiales | Movimiento y expresión |
| --- | --- | --- |
| Lady Gordota | Cabeza ancha y baja, torso robusto, patas grandes, delantal curvo; balde con borde, tapa elíptica, asa y reflejo | Marcha lenta con transferencia de peso y contrabalanceo del balde; párpados caídos y mirada desigual. Conserva máscara y blanco de Lady. El balde desaparece al perder la protección real. |
| Marumomia | Torso estrecho y encorvado, brazo extendido, bandas superpuestas y una venda sobre parte del rostro | Oscilación del extremo de tela y pasos alternados; ojos desiguales, postura torcida. Pelaje, cola y orejas de Maru continúan visibles. |
| Maru Pianotrón | Torso inclinado con chaqueta, sombrero oblicuo y piano con cara frontal, lateral y tapa; teclas blancas/negras reconocibles | Manos y teclas reaccionan a ataques reales y al reinicio del temporizador especial que cambia de carril a la horda. No se inventan interpretaciones musicales en idle. |
| Maru Locotrón | Hombros anchos, peto metálico, botas separadas, articulaciones y actuadores en las orejas | Paso segmentado con apoyo prolongado, alternancia de botas y balanceo mínimo; ojos asimétricos. El rostro y las rayas de Maru se conservan. Las piezas mecánicas son su cuerpo permanente: este tipo tiene protección numérica cero en el catálogo existente. |

Se reutilizan sombras de contacto, paleta y contornos del sistema actual.
Las geometrías principales nuevas se mantienen como Path estáticos. Los detalles
finos se omiten por debajo de la escala .45; las masas, las teclas simplificadas
y las bandas principales siguen presentes a 32 px. No se añadieron blur,
saveLayer ni partículas al renderizado de combate.

El observador lee `special` y crea un pulso visual de 0,55 s para el piano.
Se limpia al caducar, desaparecer la entidad o reiniciar el observador. El reloj
de simulación congela el pulso al pausar; el painter lo desactiva con movimiento
reducido o congelación. No escribe temporizadores ni estados del motor.

### Archivos de esta continuación

- `lib/marus_zombies/mz_character_art.dart`: personas faciales, despacho a los cuatro cutouts y parámetros compartidos.
- `lib/marus_zombies/mz_enemy_art.dart`: parte privada de la misma biblioteca; cuatro construcciones y geometrías propias.
- `lib/marus_zombies/mz_art_style.dart`: límite del caché de geometrías de volumen elevado de 64 a 256 para evitar vaciados reiterados; permanece acotado.
- `lib/marus_zombies/mz_visual_feedback.dart`: observación de la acción especial del piano.
- `lib/marus_zombies/mz_painter.dart`: transmisión del pulso y respeto a congelación/movimiento reducido.
- `test/marus_zombies/enemy_art_test.dart`: capturas reales, miniaturas, siluetas y estados de simulación.
- `test/marus_zombies/visual_feedback_test.dart`: acción especial real, pausa, caducidad y observación sin mutaciones.
- `test/marus_zombies/render_profile_test.dart`: variante concentrada en los cuatro tipos.

### Capturas y revisión temporal

En `build/previews/` están `mz-enemy-before-{pose}.png` y
`mz-enemy-after-{pose}.png`, con poses idle, stride, strike, recovery, music y
armorless. Cada hoja compara 160, 64 y 32 px y una máscara de silueta. Las
capturas antes/después usan las mismas condiciones y los mismos tiempos.
`armorless` es un estado de fixture explícito, no una derrota simulada.

`mz-enemies-v3-comparison.html` permite cambiar entre pares y reproducir los
22 frames `mz-enemy-motion-walk-*` / `mz-enemy-motion-music-*`, separados por
50 ms reales de simulación. La revisión de frames comprobó pasos, extremo de
venda, balde, postura del piano y recuperación de sus teclas. Es un bucle de
revisión de muestras de Flutter, no vídeo ni medición de FPS del dispositivo.
Las máscaras usan saveLayer únicamente dentro del painter de prueba.

### Validación obtenida

- Análisis de `lib/marus_zombies` y `test/marus_zombies`: sin incidencias.
- Suite completa: 238 pruebas aprobadas y una prueba de perfil omitida por defecto.
- Comprobación final del módulo y `patio_screen_test.dart`: 57 aprobadas y una omitida.
- Capturas temporales: prueba aprobada; sin excepciones de pintura ni cambios del JSON al renderizar.
- Build web: aprobado, incluido el dry run de Wasm.
- SHA-256 de simulación, catálogo, modelos, niveles y progreso: idénticos a los anteriores. No cambian reglas, estadísticas, recursos, oleadas ni colisiones.

Una primera invocación de pruebas apuntó por error a un archivo inexistente
`room_scene_test.dart`. Se corrigió a `patio_screen_test.dart`; el resultado
final citado corresponde a la ejecución corregida.

### Rendimiento de esta continuación

Prueba CPU de registro Canvas, 960×540, 25 defensores y 30 invasores;
50 calentamientos y 7 lotes de 100 dibujos, ejecuciones secuenciales.

| Escena | Antes | Después final | Diferencia |
| --- | ---: | ---: | ---: |
| Mezcla habitual | 9,07129 ms | 9,02104 ms | −0,6 %; dentro de la dispersión |
| Solo los cuatro tipos renovados | 8,47027 ms | 9,30724 ms | +9,9 %, +0,837 ms |

El primer resultado concentrado fue 10,76565 ms (+27,1 %). Se detectó presión
sobre el caché de volumen y se amplió su límite; la versión final reduce ese
coste un 13,5 %. Persiste un sobrecoste medible en la concentración extrema de
estos personajes, justificado por las construcciones distintas pero pendiente
de perfilar en hardware móvil. No se afirma ausencia total de sobrecoste.
JSON: `mz-render-enemy-before.json`, `mz-render-enemy-final.json`,
`mz-render-enemy-focus-before.json`, `mz-render-enemy-focus-final.json`.

Estos números no se comparan directamente con los de la primera entrega V3:
son baselines nuevos de esta sesión. Excluyen GPU/raster, audio, HUD, memoria y
simulación. No garantizan 60 FPS ni sustituyen una revisión en Android/iOS.

### Banco SFX solicitado durante la continuación

Se descargaron 89 archivos originales (aproximadamente 6,5 MB), separados del
bundle en `audio_sources/marus/`: 24 WAV de zombis de artisticdude, dos maullidos
WAV de Kerzoven y 63 OGG de Digital Audio de Kenney, incluido Preview.
Las tres páginas publican licencia CC0. `README.md` conserva enlaces y autores;
`manifest.json` registra tamaños, SHA-256 y metadatos de WAV. `audition.html`
permite escuchar los archivos individualmente. Se conserva License.txt de Kenney.

Es un banco obtenido y verificable; todavía no está seleccionado, mezclado ni
conectado a acciones. Las etiquetas de las voces numeradas no se presentan como
ataque/daño/derrota confirmados sin audición. No se agregaron dependencias ni
sonidos extraídos de PvZ. El reproductor permite preparar esa selección.

### Pendientes actuales

Conectar y mezclar la selección SFX tras audición; perfilar raster/memoria en un
móvil; revisar combate con oleadas intensas en dispositivo; continuar los demás
personajes y pantallas del catálogo sin rehacer los pilotos V3 existentes.


## V3.2 — Almanaque, colección y obtención (10-10-2026)

### Auditoría y alcance

El almanaque anterior era un bottom sheet con ListTile: retratos pequeños para
los defensores, texto para los invasores, estadísticas mezcladas y una indicación
«Por desbloquear» sin requisito. Se revisaron catálogo, progreso, niveles,
preparación de equipo, acciones especiales y arte compartido antes de sustituir
esa presentación. Se conservan todos los cutouts V3 y la navegación desde el
icono del libro; cerrar o volver devuelve al mapa.

La nueva pantalla contiene once cartas de defensores, quince fichas de invasores
y una ficha ancestral independiente. No hay rarezas, niveles de carta, compras
nuevas, mejoras de daño ni estrellas de evolución.

### Colección visual implementada

- Cartas ilustradas con marco de madera, reflejo de borde y sombra para defensores;
  marco metálico y fondos nocturnos para invasores; dorado para el ancestral.
- Fondos vectoriales con motivos de valla, pirámides, olas, madera y hologramas
  según el mundo de obtención o primera aparición. Los iconos distinguen roles
  sin modificar el dibujo del personaje.
- Selección mediante toque, teclado y acción semántica accesible. El estado
  seleccionado combina borde, marca y Semantics; no depende solo del color.
- Retrato grande con idle sutil solo para el seleccionado desbloqueado. Las
  miniaturas son estáticas y están aisladas mediante RepaintBoundary. Los cambios
  de ficha usan una transición de 220 ms; los detalles vuelven arriba al cambiar.
- Las cartas bloqueadas muestran la silueta real del cutout, un candado y el nivel
  necesario. Su ficha sigue siendo consultable y no anima la silueta.
- Ficha con nombre, rol, coste de colocación, recarga, resistencia, daño base,
  intervalo cuando existe, habilidad y efecto de atún tomados de mzCats. Los
  invasores muestran vida, protección y velocidad tomadas de sus getters; la
  primera aparición se obtiene de los enemigos permitidos por mzCampaign.
- En escritorio/horizontal amplia, colección y ficha se desplazan por separado.
  En vertical o con texto grande, la ficha compacta precede a la colección y las
  estadísticas se despliegan al tocarlas. No se pierde contenido por ocultarlo.
- Se respetan SafeArea, texto ampliado, movimiento reducido del progreso,
  disableAnimations y accessibleNavigation. Botones principales de 48 dp.

### Progreso y requisitos reales

El contador y la barra usan `mzUnlockedCats(progress.highest)`: once gatos
normales en total. El equipo muestra las cartas del deck guardado que ya están
desbloqueadas. Se conserva el máximo de seis en la preparación existente;
el almanaque permite inspeccionar, no equipar ni comprar.

`mzAlmanacRequirement` busca el primer valor de campaña para el que la función
original desbloquea la carta. No mantiene una segunda tabla de requisitos.
`highest` representa niveles de campaña consecutivos completados, no estrellas.
El texto diferencia el número global de campaña y el número local del mundo.

| Carta | Requisito global | Mundo donde se obtiene |
| --- | ---: | --- |
| Lanzador | Disponible desde el inicio | Patio |
| Girasol | Completar nivel 1 | Patio |
| Maru Wuatón | Completar nivel 2 | Patio |
| Siberiano | Completar nivel 3 | Patio |
| Caja sorpresa | Completar nivel 4 | Patio |
| Gatitos bomba | Completar nivel 5 | Patio |
| Catapulta | Completar nivel 6 | Patio |
| Bumerán | Completar nivel 10 | Final del Patio |
| Resorte | Completar nivel 20 | Final de Egipto |
| Relámpago | Completar nivel 30 | Final de Piratas |
| Láser | Completar nivel 40 | Final del Oeste |

Los filtros agrupan por obtención, no por el mundo donde una unidad parece
encajar temáticamente. Por ejemplo, Bumerán se recibe al terminar Patio; no
requiere ganar un nivel de Egipto. Actualmente no se obtiene una carta normal
nueva al terminar Futuro, por lo que ese filtro informa que no hay cartas.
Las pendientes siguen visibles dentro de su mundo.

«Cómo conseguir» señala el nivel y mundo exactos, y la ficha bloqueada muestra
niveles completados/requeridos con una barra. Solo se representa progreso parcial
cuando existe una cantidad real. La ficha explica explícitamente:

1. Desbloquear es permanente y depende de campaña.
2. Equipar es elegir hasta seis cartas antes de jugar.
3. La hierba se paga por cada colocación durante el combate.
4. La recarga es la espera entre colocaciones; no compra ni desbloquea la carta.

Los invasores siguen siendo un bestiario de consulta libre, como antes. No se
inventan capturas, compras ni un historial de avistamientos que el guardado no
contiene.

### Novedades sin celebraciones repetidas

La preferencia visual independiente `marusZombies.almanacSeen.v1` guarda IDs ya
presentados. En la primera visita se establece una base con las cartas actuales,
sin afirmar que una colección antigua acaba de obtenerse. En visitas posteriores,
las nuevas cartas muestran distintivo, pequeña celebración y transición de barra;
la primera novedad se selecciona automáticamente.

Tras presentar el almanaque, los IDs se reconocen en SharedPreferences; reabrir
no vuelve a celebrar esos desbloqueos. Esta preferencia es local, no se añade a
la lista de sincronización y no altera `marusZombies.v1`. El guardado existente
no necesita migración. No se incorporó una alerta nueva en la pantalla de victoria:
las novedades se presentan en la siguiente visita al almanaque.

### Gran León · Maru

Usa `mzPaintAncestral`, sin diseñar otro gato ni ocupar una de las once cartas.
La ficha muestra los requisitos existentes de `unlockLion`: completar 30 niveles
(el mundo pirata) y gastar 100 mentitas. Indica dónde hacerlo: «Más aventuras» →
«Invocar» en Gran León Mítico. El almanaque no ejecuta esa compra.

Se muestran por separado campaña y saldo de mentitas, con marcas de requisitos
cumplidos. Si ya está desbloqueado, se consulta `progress.lion`; gastar mentitas
después no lo vuelve a bloquear. Se explican las fuentes existentes: 10 mentitas
por terminar un mundo por primera vez, 5 por un desafío diario nuevo ganado y
5 por cada hito nuevo de cinco oleadas de supervivencia. Se conserva su poder:
rugido de 200 de daño, daño triple para Lanzadores y Bumeranes durante 15 segundos
y una invocación por partida.

### Archivos y preservación

- `lib/marus_zombies/mz_almanac.dart`: colección, presentación vectorial, ficha,
  requisitos derivados, filtros, estados y reconocimiento visual de novedades.
- `lib/marus_zombies/mz_screen.dart`: el libro abre la nueva ruta del almanaque.
- `test/marus_zombies/almanac_test.dart`: interacción, progresión, accesibilidad,
  capturas y prueba CPU optativa.
- Este documento: registro de alcance, requisitos, pruebas y límites.

No se modificaron mz_character_art.dart, mz_enemy_art.dart, mz_catalog.dart,
mz_levels.dart, mz_progress.dart, mz_simulation.dart ni mz_models.dart. Las huellas
SHA-256 del motor, catálogo, niveles y progreso siguen coincidiendo con V3.
No hay dependencias ni assets bitmap nuevos para el juego. Los PNG de esta fase
son capturas de validación dentro de build/previews, no assets de personajes.

### Validación final

- Diez pruebas específicas del almanaque aprobadas, con y sin generación de imágenes.
- Selección y consulta de los once defensores y los quince invasores verificadas.
- Comprobación de los once umbrales: bloqueada inmediatamente antes y disponible
  en el valor exacto del desbloqueo; estados equipada/disponible/bloqueada y filtro
  por mundo de obtención verificados.
- Celebración presente en la primera visita tras una novedad y ausente al reabrir.
  El valor del progreso de campaña permanece idéntico al abrir, consultar y cerrar.
- Acción de toque semántica verificada. En un avance de idle, el delegado de la
  miniatura es el mismo y el retrato activo cambia; no se animan todas las cartas.
- Sin desbordamientos en 390×844, 960×540 y 1440×900; revisión adicional en 320×640
  y 844×390 con texto al 180 % y movimiento reducido. Se cargan las fuentes reales
  también para esas pruebas de disposición.
- Suite completa final: **248 aprobadas, una prueba de perfil omitida**.
- Análisis del módulo y sus pruebas: **sin incidencias**.
- Build web final: **aprobado**, incluido el dry run de Wasm.

### Capturas comparativas

`build/previews/mz-almanac-v32-comparison.html` reúne pares antes/después a
390, 960 y 1440 px y estados available, locked, locked-how, ancestral, invaders,
new-card y accessible-320 / accessible-844. Se revisaron los retratos, las siluetas,
los textos de requisitos, la selección, la tipografía y los marcos.

Las primeras imágenes de prueba usaban la fuente de test para algunos textos;
los pares se regeneraron con las fuentes reales y sin la banda de debug. Para
el «antes» se repuso temporalmente el mismo método original del bottom sheet y
se restauró la implementación V3.2 antes de la validación final.

### Coste medido y límites

Prueba optativa a 960×540: 20 calentamientos y cinco lotes de 50 pumps de 16 ms.
Es tiempo CPU de `WidgetTester.pump`, no frame timing en dispositivo ni GPU.
Se comparan una lista sin animación y una pantalla que sí dibuja idle:

| Estado | Mediana CPU por pump |
| --- | ---: |
| Almanaque anterior, en reposo | 0,05820 ms |
| V3.2, retrato seleccionado animado | 1,42664 ms |
| V3.2, movimiento reducido | 0,04834 ms |

El idle añade aproximadamente 1,37 ms en esta prueba; no es una aceleración frente
al almanaque anterior, que no tenía esa función. La dispersión del estado animado
fue 1,25–1,93 ms entre lotes. Al reducir movimiento no queda una animación continua.
JSON: `mz-almanac-profile-before.json`, `mz-almanac-profile-after.json` y
`mz-almanac-profile-reduced.json`.

La colección es lazy y los fondos/miniaturas tienen límites de repintado propios.
La silueta usa composición de color solamente al pintar las vistas bloqueadas,
que no animan. Se mantiene la composición existente del ancestral. Quedan por
medir raster/GPU, memoria y comportamiento táctil físico en Android/iOS; no se
prometen 60 FPS. Esta fase no cambia ni vuelve a perfilar el combate.

## V3.3 — Victoria, derrota y progreso obtenido (2026-10-10)

### Implementación

- Nuevo `lib/marus_zombies/mz_result.dart`: panel de resultados sobre el tablero,
  marco de madera, papel cálido, cabecera verde/dorada para victoria y azul para
  derrota, botones con relieve y retratos vectoriales de Maru y Lady. Se reutilizan
  Girasol/Maru y Lanzador/Lady en victoria, y Barrera/Maru y Lanzador/Lady con el
  estado visual de daño en derrota. No se redibujó el catálogo ni se añadieron assets.
- Presentación inicial de 1,6 segundos: pequeños saltos, estrellas escalonadas,
  iluminación y hasta doce partículas de celebración. Las estrellas y los retratos
  repintan directamente con `CustomPainter(repaint: ...)`; no reconstruyen el HUD
  por frame. La animación termina y no mantiene un idle continuo.
- Se respeta movimiento reducido del progreso, `disableAnimations` y
  `accessibleNavigation`: composición final estática, sin salto ni partículas.
- El contenido se desplaza cuando hace falta. El pie de acciones permanece fijo,
  incluso en vertical y con texto aumentado. Los botones tienen una altura mínima
  de 48 puntos; título con anuncio semántico y estrellas con descripción accesible.
- La pausa mantiene su presentación anterior. Solo los resultados finales utilizan
  el nuevo panel.

### Recompensas y nuevas cartas reales

`MzResultReceipt` toma una instantánea exclusivamente en memoria inmediatamente
antes de la llamada existente a `progress.complete(sim)`. Después de completarse
el guardado calcula diferencias de galletitas, mentitas, estrellas de campaña,
niveles completados y conjuntos de `mzUnlockedCats(highest)`.

No duplica fórmulas de premios ni umbrales de desbloqueo. Solo anuncia cantidades
positivas realmente añadidas. Una repetición sin mejoras muestra que no hay
recompensas nuevas. Las estrellas grandes representan la evaluación de esa partida;
la ficha «Estrellas nuevas» representa únicamente el incremento guardado.
Supervivencia puede presentar premios al terminar en derrota, conforme al sistema
existente. También se conserva la recompensa real del desafío diario.

Cada nueva carta muestra retrato, nombre y «¡Nueva carta desbloqueada!». La acción
«Ver en el almanaque» abre V3.2 con esa carta seleccionada mediante el parámetro
opcional `initialCat`. Se conserva el único registro visual `almanacSeen.v1`:
el resultado no lo escribe ni lo duplica. El almanaque mantiene su celebración y
su reconocimiento de novedades anteriores. El ancestral no se anuncia como una
carta automática por superar un nivel: su obtención sigue siendo la existente.

`mz_game_screen.dart` conserva los reintentos de guardado, el siguiente nivel,
reintentar/jugar otra vez y volver al mapa. El recibo se limpia al iniciar otra
partida. No se añade progreso persistente ni se cambia el formato de guardado.

### Validación

- Seis pruebas funcionales nuevas aprobadas: victoria con carta y enlace al
  almanaque, siguiente nivel, derrota/reintento, premios de cierre de mundo,
  repetición sin premios ni desbloqueos duplicados, supervivencia en derrota y
  desafío. Los escenarios monetarios se contrastan contra `MzProgress.complete`.
- Navegación al retrato correcto y regreso verificados; no existe registro de
  novedades del almanaque antes de abrirlo y no se añaden IDs duplicados.
- Sin desbordamientos en 320×640, 844×390 y 1440×900 con texto al 180 % y movimiento
  reducido. «Volver al mapa» se verifica tocable sin desplazar el contenido.
- Capturas antes/después revisadas a 960×540 y 390×844 para victoria y derrota.
  Son fixtures de WidgetTester, no partidas jugadas manualmente. Para el antes se
  habilitó temporalmente el método original del panel y se restauró V3.3 después.
- Suite del módulo: **68 pruebas aprobadas, dos perfiles optativos omitidos**.
  La prueba de perfil de resultados también pasó al habilitarla explícitamente.
- Análisis del módulo y sus pruebas: **sin incidencias**.
- SHA-256 de `mz_simulation.dart`, `mz_catalog.dart`, `mz_progress.dart` y
  `mz_levels.dart` coincide con la versión anterior: reglas y recompensas intactas.

### Comparación visual y rendimiento

`build/previews/mz-result-v33-comparison.html` reúne los cuatro pares de capturas
con selector horizontal/vertical. Los PNG de validación no son assets del juego.

Medición CPU de `WidgetTester.pump`, mismo resultado y viewport de 960×540,
cinco lotes de 50 avances de 16 ms, tras cinco avances de calentamiento. Se mide
la transición y después el mismo panel en reposo:

| Presentación | Durante la entrada | Después de la entrada |
| --- | ---: | ---: |
| Panel anterior, estático | 0,46080 ms | 0,28446 ms |
| V3.3 final | 1,25544 ms | 0,23258 ms |

La transición añade aproximadamente 0,795 ms CPU por avance en esta prueba y
termina a los 1,6 segundos. El reposo es comparable al anterior. El prototipo de
la animación reconstruía widgets y se sustituyó por repintados directos de Canvas.
JSON: `mz-result-profile-before.json` y `mz-result-profile-after.json`.

No son mediciones GPU/raster ni FPS reales. Falta verificar rendimiento y tacto
físico en Android/iOS; no se promete una tasa de cuadros. No se midió de nuevo el
combate, porque esta fase modifica su presentación una vez terminada la partida.

Build web final aprobado, incluido el dry run de Wasm. Flutter compila la presentación nueva sin dependencias adicionales.


## V3.4 — Arquitectura propia por mundo y Cementerio nocturno

El patio mantiene su casa y añade jardín y árbol. Egipto tiene templo, pirámides y palmeras; Piratas muestra océano, cabina, velas, cuerdas y barandillas; Oeste incorpora saloon, mesas, torre de agua, barriles y cactus; Futuro tiene hangar, skyline tecnológico, cables y luces. El Cementerio incorpora luna, estrellas, cipreses, verja, capilla y faroles. Todo es Canvas vectorial estático, grabado por las cachés existentes.

`mz_world_art.dart` concentra arquitectura y materiales. `mz_scene_layers.dart` selecciona el escenario; `mz_painter.dart` evita dibujar los arbustos y hojas del Patio sobre los demás mundos. El recorte protege tanto las 45 casillas como el corredor de las cinco Roombas. No cambian sus coordenadas, nodos, agua ni carros.

Por petición posterior del usuario, se trasladaron las tres lápidas de Egipto al nuevo Cementerio, **un mundo de diez niveles después del Patio**, y la campaña pasa a 60 misiones:

| Mundo | Misiones del recorrido | IDs conservados / nuevos |
| --- | --- | --- |
| Patio | 1–10 | 0–9 |
| Cementerio | 11–20 | 50–59, nuevos |
| Egipto | 21–30 | 10–19 |
| Piratas | 31–40 | 20–29 |
| Oeste | 41–50 | 30–39 |
| Futuro | 51–60 | 40–49 |

Los IDs guardados y los umbrales originales de cartas se conservan: el Cementerio no añade cartas ni consume el contador original de desbloqueo. Los jugadores nuevos recorren sus diez niveles antes de Egipto. Los jugadores que ya avanzaron más allá del Patio conservan acceso a su avance anterior. Los checkpoints de Egipto eliminan las lápidas antiguas al reanudarse; los del Cementerio conservan su resistencia. El nuevo mundo utiliza enemigos, recompensas y fórmulas existentes. Este cambio de contenido sí modifica niveles y obstáculos, expresamente solicitado; no forma parte de la restricción exclusivamente visual de V3.4 original.

Pruebas: seis mundos con diez IDs únicos, conexiones entre mundos, acceso nuevo y heredado, recompensas sin repetir, checkpoints y umbrales conservados. Arquitectura comprobada a 320×640, 844×390, 960×540 y 1440×900 sin pintar sobre tablero/corredor. Comparación de render cached/uncached equivalente y snapshots de simulación intactos durante el pintado. La suite de campaña recorre las 60 misiones.

Capturas: `build/previews/mz-v34-before-{mundo}.png`, `mz-v34-after-{mundo}.png` y `mz-v34-worlds.png`. El Cementerio es nuevo y no tiene captura anterior. Son fixtures de pruebas, no assets del juego.

Perfil CPU de grabación inicial / reproducción cached (medianas, 960×540, siete lotes de 100 reproducciones):

| Mundo | Antes inicial / cached (ms) | Después inicial / cached (ms) |
| --- | --- | --- |
| Patio | 5,210 / 0,13566 | 6,142 / 0,21065 |
| Egipto | 2,439 / 0,11446 | 1,280 / 0,05806 |
| Piratas | 3,044 / 0,11200 | 1,060 / 0,04920 |
| Oeste | 1,779 / 0,10195 | 1,138 / 0,04700 |
| Futuro | 2,072 / 0,08756 | 1,653 / 0,04313 |
| Cementerio | — | 1,158 / 0,05242 |

El Patio añade unos 0,075 ms CPU de composición cached en esta muestra; los otros mundos sustituyen la decoración anterior. La grabación inicial sucede al invalidar la caché, no cada cuadro. Estos datos no miden GPU/raster ni garantizan FPS en móvil.

## V3.3.1 — Revelación de cartas coleccionables

`mz_card_reveal.dart` presenta los desbloqueos efectivos de `MzResultReceipt` sobre el tablero terminado, con velo oscuro. El reverso de madera verde y huella aparece pequeño; gira durante 1.150 ms con perspectiva, rotación Y y rebote. La cara frontal compensa la rotación para evitar texto reflejado. Tocar durante el giro lo termina; tocar el frente amplía la ficha. «Continuar» está disponible siempre y vuelve al resultado normal. Las victorias sin novedades conservan el panel habitual.

`MzCollectibleCard` en `mz_almanac.dart` comparte retrato vectorial, fondo por mundo, rol y especificaciones con el almanaque. Añade una breve personalidad editorial, habilidad real, coste, recarga y atún. El cuerpo puede desplazarse en pantallas pequeñas; los botones permanecen fuera del scroll. La transición de ampliación tarda 320 ms. Movimiento reducido muestra directamente el frente y elimina las transiciones.

El descubrimiento se reconoce después de presentar el frente completado o al abrir su ficha. Se escribe únicamente `marusZombies.almanacSeen.v1`, conservando sus IDs. Omitir antes del descubrimiento establece solamente la colección anterior como baseline, de modo que la carta siga pendiente en el almanaque, incluso en la primera visita. No hay un segundo registro, nuevas recompensas ni cambios de economía. Abrir el almanaque selecciona el personaje; volver conduce al resumen, sin repetir el giro ni la celebración de esa carta.

### Sonido solicitado

Se incluyó el MP3 aportado por el usuario como `assets/audio/marus_card_victory.mp3` (107.181 bytes), con SHA-256 `2332DBC2E31D3A1D722C7E7945E4E8B49E35A0D55124F28FA934264DE2D82128`, idéntico al original. `GameSfx.marusCardVictory` reutiliza audioplayers y el mezclador existente: una reproducción independiente al iniciar la revelación, ganancia 0,7 multiplicada por volumen de efectos, superpuesta a la música. Se detiene al continuar, abrir el almanaque o destruir la presentación. Respeta silencio, pausa y ciclo de vida existentes; no reemplaza la playlist ni crea dependencias. No se toca el efecto genérico de otras victorias; se evita duplicarlo durante esta revelación.

### Validación y coste

Pruebas de los diez umbrales actuales y repetición de niveles; Girasol obtenido al completar Patio · 1. Reverso no reconocido, carta descubierta, omisión, movimiento reducido, ampliación, conservación del progreso guardado y navegación al personaje correcto. Capturas de reverso/giro/frente/ficha a 960×540, 844×390 y 320×640: `build/previews/mz-reveal-{back,flip,front,detail}-{ancho}.png`; resumen `mz-reveal-stages.png`.

Se detectó inicialmente una mediana de 3,49030 ms CPU por pump durante el giro. Reutilizar ambas caras y aislarlas con RepaintBoundary la redujo a **1,31690 ms**, con **0,24934 ms** una vez terminado. El perfil previo V3.3, mismo protocolo de cinco lotes de 50 pumps de 16 ms a 960×540, registraba 1,25544 / 0,23258 ms. Diferencia observada frente a V3.3: aproximadamente 0,061 ms durante la entrada. El giro es finito y no introduce trabajo continuo sobre el combate. Las muestras son WidgetTester CPU y no incluyen reproducción física del MP3 ni GPU; falta comprobar audio y fluidez en dispositivos Android/iOS reales.

No se añaden motores, paquetes, sprites ni imágenes de producción. El build web compila con dry run de Wasm; analizar el módulo y las pruebas no informa incidencias. Las pruebas y capturas se generan automáticamente; no se afirma una tasa de FPS ni validación auditiva en hardware.

Resultado de validación final: **81 pruebas aprobadas, tres perfiles optativos omitidos**; los perfiles de escenarios y revelación también pasaron en ejecuciones separadas. Análisis sin incidencias. Compilación web aprobada y MP3 presente en el bundle. Comparadores locales: `build/previews/mz-card-reveal-v331.html` y `mz-worlds-v34-comparison.html`. La validación física del sonido en dispositivos permanece pendiente.


## V3.5 — Sonidos y feedback del combate: primera selección del Patio

### Alcance y revisión real

Se encontraron y decodificaron correctamente **89 archivos** de `audio_sources/marus/`, y los 89 SHA-256 coinciden con el manifiesto original. Se midieron duración, pico, RMS, centroide espectral, silencio inicial/final y muestras fuera del rango PCM. El informe es `audio_sources/marus/technical_audit_v35.json`.

**No se escucharon los archivos:** el entorno rechazó el audio con «audio content omitted because you do not support audio input». Se informó esta limitación y el usuario autorizó buscar y seleccionar entre los audios existentes. La selección implementada es **técnica y provisional**; no se afirma haber validado su carácter adorable, su timbre ni la mezcla a oído. No hizo falta descargar sonidos. El banco original y sus licencias permanecen intactos.

### Cinco eventos, cinco fuentes

| Evento | Fuente existente | Asset central | Duración preparada | Ganancia de efecto |
| --- | --- | --- | ---: | ---: |
| Disparo del Lanzador | Kenney · `digital/pepSound3.ogg` | `marus_launcher.wav` | 293 ms | 0,26 |
| Recogida de hierba | Kenney · `digital/highUp.ogg` | `marus_harvest.wav` | 351 ms | 0,50 |
| Mordida zombi | artisticdude · `zombies/zombie-24.wav` | `marus_bite.wav` | 273 ms | 0,22 |
| Impacto en armadura | Kenney · `digital/powerUp5.ogg` | `marus_armor.wav` | 243 ms | 0,38 |
| Derrota de invasor | artisticdude · `zombies/zombie-8.wav` | `marus_defeat.wav` | 779 ms | 0,30 |

Las fuentes están registradas como CC0-1.0 en el manifiesto anterior. Se priorizó un disparo corto con centroide bajo, un acento ascendente de recurso, dos fragmentos breves del banco zombi y un transitorio más agudo para armadura. Estas características técnicas no sustituyen la escucha. Los maullidos originales duran aproximadamente 1,1 y 2,5 segundos; no se usaron enteros como disparos frecuentes.

Se recortaron silencios con 5 ms de margen inicial y 10 ms final, se aplicaron fades de unos 5 ms y se ajustaron picos entre 0,62 y 0,72. Los fragmentos zombi decodificados contenían picos superiores a 1; las copias preparadas evitan sobrepasar el rango PCM. Formato final: WAV PCM16, mono, 22.050 Hz. No se sobrescribieron originales.

Cada fuente tiene tres variantes: tono central, −3 % y +3 %, preparadas por resampling. Las variantes `_low.wav` y `_high.wav` evitan depender del comportamiento de preservePitch del navegador. El reproductor mantiene velocidad 1; el tono viene en el archivo. Se alternan mediante RNG **exclusivamente del audio**, y la ganancia varía ±8 %. Son quince assets para cinco eventos, **257.630 bytes** en total. `patio_selection_v35.json` contiene recortes, hashes y variantes; `tool/prepare_marus_combat_audio.py --prepare` permite preparar de nuevo las fuentes locales usando el ffmpeg existente, sin dependencia de ejecución en Flutter.

### Conexión con eventos reales

`mz_combat_audio.dart` toma una instantánea inmediatamente antes de `sim.advance()` y observa su resultado una vez. No consulta poses, cuadros de animación ni el reloj del renderizado para inventar ataques.

- Lanzador: reset real del temporizador de ataque o consumo real de la ráfaga de atún; ningún otro defensor recibe este sonido.
- Recogida: éxito de `sim.collect()` para el toque manual; para recogida automática, nuevos efectos `collect` descontando el aumento real de latas de atún. La generación de hierba y la caducidad de un recurso permanecen silenciosas.
- Mordida: nuevo efecto `bite` emitido por el motor al hacer daño; caminar, congelación y animación idle no la reproducen.
- Armadura: contacto real `hit`/`ice` asociado a un invasor previamente protegido y reducción real de armadura, o eliminación en ese contacto. Un golpe que atraviesa sin consumir armadura queda silencioso. Esta primera fase cubre contactos de proyectiles; no añade una voz a cada poder especial.
- Derrota: incremento real del contador de bajas; eliminar un defensor con pala o retirar un invasor de una lista no basta.

Esta conexión se activa **solo en el Patio**. Las reglas, estadísticas, temporizadores, RNG de simulación, progreso y oleadas no se editaron. Sus cuatro hashes (`mz_simulation.dart`, `mz_progress.dart`, `mz_catalog.dart`, `mz_levels.dart`) coinciden con los tomados al inicio de V3.5.

`mz_game_screen.dart` integra la observación y cambia la moneda genérica por la recogida de hierba del Patio. El atún conserva su feedback anterior. El sonido genérico `clear` deja de duplicar la baja del Patio; permanece en otros mundos. La Roomba y el MP3 `marus_card_victory.mp3` mantienen sus canales anteriores. No se cambió la música ni se amplió la sonorización al resto del catálogo.

### Mezclador y límites

`GameSfx` añade los cinco eventos, y `GameAudio.playCombat()` reutiliza audioplayers. La selección es previa a crear/reproducir voces:

- Hasta **cuatro voces de combate**, reutilizadas; música y revelación usan sus canales propios.
- Hasta **dos inicios por lote** y **diez por segundo** en una ventana móvil.
- Una entrada por familia en cada lote, aunque haya muchos ataques simultáneos.
- Intervalos mínimos: disparo 120 ms, hierba 100 ms, mordida 260 ms, armadura 100 ms, derrota 220 ms.
- Prioridad: recurso > derrota > armadura > mordida > disparo. Un evento de prioridad superior puede interrumpir una voz de prioridad inferior; lo que se descarta no se reproduce después.
- Las operaciones async por voz se serializan y verifican una revisión para cancelar trabajo obsoleto antes de reproducirlo.
- Volumen final = volumen global de efectos × ganancia de familia × variación pequeña. Volumen cero y silencio no crean nuevas voces. El control existente ajusta también las voces activas.
- Pausa, cambio de escena, ciclo de vida y salida de partida detienen las voces de combate y cancelan pendientes. Al reanudar no se recuperan sonidos atrasados. No se corta el MP3 de revelación con `stopCombat()`.

### Pruebas, comparación y rendimiento

`combat_audio_test.dart` valida los disparos reales y idle, separación del Siberiano, ráfaga de atún, recogida automática frente a atún/caducidad, mordida/congelación, absorción/piercing, bajas frente a retirada, pausa, otros mundos, variantes empaquetadas y límites. Comparar 180 pasos con una simulación clonada demuestra igualdad de checkpoints y RNG con/sin observación y selección de audio.

`combat_mixer_test.dart` emula canales nativos de audioplayers: volumen cero, silencio, pausa, ciclo de vida, ganancias, reproducción y aislamiento del canal de la carta. **No reproduce sonido físico**; la preparación y las llamadas nativas son simuladas.

Suite del módulo: **93 pruebas aprobadas, cinco pruebas optativas omitidas**. Análisis de código y pruebas: sin incidencias. Perfiles y referencia de audio también pasan al habilitarlos por separado. Build web aprobado, con las quince variantes WAV y el MP3 anterior presentes en el bundle. No se añadieron paquetes.

Perfil CPU de cinco lotes de 120 pasos con 100 invasores y cinco barreras, mismo fixture, RNG del audio independiente:

| Variante | Mediana por paso |
| --- | ---: |
| Simulación existente | 0,04670 ms |
| Simulación + observación + selección | 0,05255 ms |

Sobrecoste observado: aproximadamente **0,00585 ms CPU por paso**. JSON: `build/previews/mz-combat-audio-profile.json`. Excluye decodificación del reproductor, latencia de audio, GPU y altavoces; no representa FPS ni rendimiento de Android/iOS reales.

Se generó un ledger de eventos de un combate equivalente de 20 segundos (`mz-combat-audio-ledger.json`) y dos referencias WAV con la misma música de Patio: **3 efectos aceptados antes / 20 después**, incluidas variantes, volúmenes y cortes por reutilización de voz. No son grabaciones del dispositivo; son mezclas offline de eventos reales de la simulación, destinadas a revisión auditiva. Los archivos de prueba son `mz-combat-audio-before.wav` y `mz-combat-audio-after.wav`. `tool/prepare_marus_combat_audio.py --comparison` vuelve a renderizarlos desde el ledger.

`build/previews/mz-combat-audio-v35.html` reúne la comparación, las cinco copias preparadas y sus originales. `audio_sources/marus/audition.html` conserva los 89 controles de audición. **Pendiente:** escuchar y aprobar/sustituir la selección provisional y comprobar la mezcla, respuesta y latencia en un dispositivo real. La implementación funcional está lista; la calidad acústica subjetiva no se declara verificada.

## OST proporcionada por el usuario · Patio de Maru (2026-10-10)

El usuario considera adecuados los sonidos actuales y entregó `Laura Shigihara - Zombies On Your Lawn (Audio).mp3` para los primeros niveles. Se interpreta ese alcance como las diez misiones del Patio; las demás regiones y el menú del módulo conservan `garden-patrol.wav` hasta recibir sus temas.

- Copia íntegra en `assets/audio/music/marus/zombies-on-your-lawn.mp3`: 3.843.898 bytes; SHA-256 `F702A272F07096B7F2053721BF33A1525EF345BEC083A5B91D799B17DF7AAB99`, idéntico al archivo local entregado.
- `tracks.json` añade la escena `marus-zombies-patio`. `MzGameScreen` la selecciona al iniciar o reintentar/avanzar dentro del Patio, y selecciona la escena existente para otros mundos. Al volver a la selección se restaura la música del módulo.
- Las escenas con una sola canción usan `ReleaseMode.loop`; las listas con varias conservan su rotación. No se cambia el MP3 de revelación ni los efectos de V3.5.
- Se conservan controles independientes de música/efectos, pausa, ciclo de vida y transiciones del mezclador existente. Sin cambios en combate, progreso, recompensas ni dependencias.

Validación: análisis sin incidencias; suite del módulo con 93 pruebas aprobadas y cinco optativas omitidas. La prueba de canales nativos verifica la fuente MP3, modo bucle, pausa/reanudación y que mover el volumen no vuelve a cargar la canción. Los canales se emulan: no certifican escucha física, latencia o mezcla en un dispositivo real. El entorno sigue sin entrada auditiva; el usuario revisó los efectos actuales, mientras que la mezcla con esta nueva OST deberá escucharse durante la partida.

Build web aprobado; MP3 de Patio verificado en el bundle generado. Los hashes de simulación, progreso, catálogo y niveles permanecen intactos.

## Selección sonora confirmada y preparación de GitHub

Se conservan las voces zombis de V3.5 por decisión del usuario: los dos maullidos locales y las dos alternativas externas se rechazaron. No se descargaron ni integraron estas últimas. V3.6 (cuatro habilidades con sonidos propios) sigue pendiente; esta entrega no afirma haberla implementado.

Se actualizan la presentación del Patio y el README para reflejar seis mundos y 60 misiones, y los créditos de audio distinguen los efectos CC0 de los MP3 entregados por el usuario. Las previsualizaciones y compilaciones en `build/` permanecen excluidas de Git.

## V3.6 · Identidad sonora de cuatro defensores (2026-10-10)

### Integración real

Se extiende `MzCombatAudio` como observador antes/después del avance y de `feed()`, sin escribir en la simulación. La selección de V3.5 y los MP3 del Patio y de revelación permanecen intactos.

- Girasol: evento `sun` para producción; `tuna` de ese defensor para la habilidad de 15 recursos. Producir no reproduce recogida. La recogida real conserva el efecto anterior.
- Siberiano: incremento real de temporizador tras lanzar; evento `ice` para contacto; congelación solo al aumentar `frozenUntil` tras atún de Siberiano. Su disparo normal **ralentiza**, no congela. La inmunidad existente impide repetir la señal de congelación.
- Catapulta: temporizador real o nuevos proyectiles de arco para lanzamiento; proyectil dirigido consumido y contacto `hit` con su objetivo para impacto. La tensión y liberación son un único clip iniciado en el lanzamiento real; no se anticipa un ataque ficticio ni se cambia su momento. Atún agrupa la ráfaga en una voz breve.
- Láser: nuevos efectos `laser` indican actividad real. Un canal compartido reproduce el haz en bucle, con activación y cierre como transitorios. Se reserva la cuarta voz del mezclador mientras el haz está activo; quedan tres para transitorios. El estado invariable no recarga ni reinicia el audio. Atún reproduce activación al potenciar el defensor. Pausa, volumen cero, salida y ciclo de vida detienen/cancelan las voces.

Las cuatro familias funcionan en todos los mundos donde se usan; los cinco efectos V3.5 conservan su alcance Patio. Se reutilizan las poses, estelas, impactos y efectos de atún vectoriales existentes. No se añadieron cambios de arte ni dependencias. El sonido genérico de activación de atún se omite cuando la transacción ya emite un efecto específico.

### Selección y corrección solicitada

Se revisó el banco original de 89 archivos y se preparó una primera selección Digital Audio, con originales y variantes. **El usuario la rechazó por sonar a 8 bits**. Se reemplazaron esos candidatos por fuentes nuevas de campanillas, magia de hielo, arco y foley de impactos, junto con texturas Sci-Fi distintas del banco Digital Audio. No se sustituyeron las voces zombis aprobadas.

Fuentes y licencias:

- Shimmer glitter magic: The Berklee College of Music / qubodup, CC BY 3.0.
- Ice & Electricity Magic: Iwan qubodup Gabovitch, CC BY 3.0.
- Bow & Arrow Shot: dorkster (muestras originales qubodup), CC BY-SA 3.0; los derivados de Catapulta mantienen esa licencia.
- Impact Sounds y Sci-Fi Sounds: Kenney, CC0.

Diez originales seleccionados fuera del bundle en `audio_sources/marus/v36/`; autores, enlaces y hashes en su `manifest.json`. Créditos y modificaciones en `assets/audio/LICENSES.md`. Diez clips preparados: nueve transitorios con variantes ±3 % y un bucle base, **28 WAV / 537.986 bytes**. Las ganancias son deliberadamente contenidas; el haz usa 0,12 antes del volumen global. `defender_selection_v36.json` registra asignación, presupuesto temporal, fuentes y hashes. `tool/prepare_marus_defender_audio.py` reproduce preparación y comparaciones con Python estándar y el ffmpeg existente, sin requerirlos para ejecutar el juego.

**No hubo escucha por el agente**: el entorno no admite audio de entrada. El usuario escuchó la nueva selección y la aprobó el 10-10-2026, solicitando aplicarla y subirla a GitHub. Se considera aprobada por el responsable del proyecto; no se atribuye escucha al agente ni mediciones de latencia, costuras o mezcla en altavoces reales. La selección aprobada ya está conectada a los eventos de combate.

### Validación obtenida

- 123 pruebas aprobadas, seis optativas omitidas, incluyendo las regresiones del módulo, acceso desde Patio, sincronización y funciones generales.
- Prueba optativa de transacciones/perfil: siete pruebas aprobadas al habilitar `RENDER_DEFENDER_AUDIO=true`.
- Análisis sin incidencias y compilación web aprobada.
- Producción frente a recogida, atún, ralentización frente a congelación, inmunidad, lanzamiento/contacto/caducidad, bordes del haz, reserva de voces y volumen cero verificados. El canal nativo emulado comprueba que 100 actualizaciones de haz activo no recargan la fuente y que pausa y silencio bloquean reproducción. No son pruebas de altavoces o decodificación real.
- Comparación de checkpoints durante 180 transacciones a x2 para los cuatro defensores: simulación observada y control idénticos. Código de simulación, catálogo, niveles y progreso sin cambios; quince WAV de V3.5 y ambos MP3 sin cambios de bytes.
- Cinco rondas de 120 pasos con 100 invasores: mediana CPU por paso 0,03481 ms sin observador y 0,04602 ms con observador/selección; sobrecoste ~0,01121 ms. `mz-defender-audio-profile.json`. Excluye reproductores, decodificación, altavoces y GPU; no permite afirmar FPS o latencia en móviles.

`build/previews/mz-defender-audio-v36.html` reúne originales, variantes y candidatos digitales rechazados. Incluye ocho pares de mezclas offline de cinco segundos, normal/atún para cada defensor, derivados de eventos reales del test y con la misma ganancia. Sin música para escuchar los efectos; no son grabaciones del dispositivo. Ledger: `mz-defender-audio-ledger.json`. Los archivos de `build/` continúan ignorados por Git y se regeneran con la prueba optativa y el script.

### GitHub

Rama de entrega: `codex/marus-zombies-audio`, remoto `origin` (`RenatoLV/App_Aniversario`). Base del módulo: `a1cd0df`; integración V3.6: `e0471e5`. La aprobación del usuario y los hashes exactos de los diez clips base quedan registrados en `audio_sources/marus/v36/approval.json`. El script conserva esa aprobación únicamente si el hash del archivo regenerado coincide, evitando aprobar futuras sustituciones automáticamente.


### Entrega aprobada · resumen V3.6

Selección nueva aplicada a Girasol, Siberiano, Catapulta y Láser; audición aceptada por el usuario. Se conservan las voces zombis V3.5, la OST de los diez niveles del Patio y el MP3 de revelación. Sin modificaciones de simulación, economía, progresión, estadísticas ni dependencias. Resultados funcionales y perfil CPU son los descritos arriba: 123 pruebas aprobadas, seis optativas omitidas; perfil optativo aprobado, análisis limpio y build web aprobado. No se repiten pruebas por un cambio exclusivo de estado de aprobación y documentación. Los resultados no certifican latencia, mezcla física ni FPS en móviles.
