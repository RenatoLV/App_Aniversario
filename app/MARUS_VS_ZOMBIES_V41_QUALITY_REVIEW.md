# Marus vs Zombies V4.1 · Revisión de calidad

Fecha: 2026-10-10. Flutter/Dart/Canvas/CustomPainter y simulación fija conservados. Se trabajó sobre V4.0; **no se compiló una aplicación, no se generó APK ni se configuró distribución**.

## Evaluación y correcciones

El prototipo ya tiene un sistema artístico y audiovisual consistente. La prioridad de esta entrega fue comprobar guardado, intención táctil y dificultad, no añadir decoración. La [auditoría](MARUS_VS_ZOMBIES_V41_AUDIT.md) documenta reproducción, evidencia, prioridad, riesgo y resolución de cada hallazgo.

- P0: un guardado rechazado dejaba en caché una partida/débito no confirmados. Se recarga el backend al fallar antes de permitir que un nuevo MzProgress vea esa caché; el error se conserva y la cola sigue admitiendo reintentos.
- P0: la recogida de recursos interceptaba pala/atún/carrito/poder humano seleccionados. La herramienta explícita ahora tiene prioridad; el jugador la desactiva para recoger.
- P1: confirmación de atún en pantallas estrechas; «Potenciar» y cancelación sin gasto. No hay confirmación adicional en landscape amplio.
- P1: toques sin selección ya no ofrecen «Colocar»; bomba/objetivo vacío tienen explicación al intentar atún.
- P1: requisito corto de Gran León expresado como completar Piratas, coherente con la ficha larga y el progreso real.
- P1: ayuda plegable reutilizada en preparación y pausa: selección, recursos, coste, recarga, pala, atún, protección, Roombas, victoria/derrota y mecánica del mundo. Sin ventanas extra ni preferencias nuevas.
- P2: smoke test y diagnóstico escogen Catapulta/Láser por mundo, evitando confundir Cementerio con Futuro por sus IDs históricos.
- P1: contraste de fila/casilla y Cancelar sobre fondo oscuro; confirmación cálida y botones de 48×48, coherentes con las herramientas.

No se tocaron `mz_simulation.dart`, `mz_catalog.dart` ni `mz_levels.dart`. Economía, estadísticas, calendario, desbloqueos, seis cartas y formato de progreso permanecen iguales. V3.5/V3.6, música de Patio, revelación de cartas y arte de personajes no se reemplazaron.

## Gameplay y progresión

[Informe de las 60 misiones](docs/mz-v41-gameplay.md) y [CSV de 540 partidas](docs/mz-v41-gameplay.csv). Nueve políticas legales, semilla real, acciones cada 0,5 s y recogida automatizada manual. Sin inyección de recursos ni modificación de la simulación. Incluye duración, victoria/derrota, generación/recogida/gasto, colocaciones/pérdidas, saldo, kills, Roombas, daño conservador, proximidad, atún, estrellas y pico de presión.

| Política | Victorias / 60 |
| --- | ---: |
| Referencia | 60 |
| Primeras cartas disponibles | 36 |
| Defensiva | 58 |
| Ofensiva | 55 |
| Recursos moderados | 48 |
| Sin atún | 31 |
| Atún ante amenaza | 57 |
| Respuesta tardía | 34 |
| Defensor del mundo | 60 |

No se ajustó balance. Las diferencias indican sensibilidad a estrategia, no diversión ni dificultad humana. Pendientes: novedad de Cementerio, tramo Bumerán→Resorte de veinte misiones, aprendizaje de Minero/Oeste y duración del jefe. Las pruebas anteriores de recompensa repetida, datos antiguos, Cementerio insertado, registros de cartas vistas y cambios de mundo continúan cubiertas por la suite.

`highest` cuenta 50 IDs históricos; `cemeteryHighest` diez misiones añadidas; `campaignCompleted` suma 60. Gran León requiere 100 mentitas y `highest>=30`, es decir Piratas terminado para un jugador nuevo (misión 40). Sólo las seis primeras victorias finales aportan 60 mentitas; desafíos e hitos de supervivencia aportan el resto sin farmear una victoria repetida.

## UX y evidencia visual

Gestos reales Flutter a 320×568, 360×800, 390×844, 640×360, 844×390 y 1280×800, texto ×1,5 y movimiento reducido. Se comprueban selección/colocación, casilla ocupada, recursos cercanos y superpuestos a gato, prioridad de herramientas, atún sobre bomba, confirmación/cancelación, pala, arrastre cancelado/fuera, pausa, x2 y cambio de orientación. Los controles de pausa se miden con 48×48; no se atribuye ese tamaño a todas las celdas del tablero.

En pausa con texto aumentado se puede desplazar el contenido para alcanzar botones; la prueba utiliza desplazamiento real/ensureVisible, no toques fuera de pantalla. La ayuda puede cerrarse o ignorarse iniciando la misión. No hay tutorial que detenga la simulación mientras se combate.

Capturas optativas locales en `build/previews/`: `mz-v41-before-interaction.png` / `mz-v41-after-interaction.png`, `mz-v41-tuna-confirm.png`, `mz-v41-help.png` y seis HUD tras rotación. El antes se obtuvo restaurando temporalmente únicamente `mz_game_screen.dart` desde HEAD V4.0, usando el mismo fixture; después se repuso V4.1. Fuente de verdad: tests y código, no imágenes generadas artificialmente. Fuentes reales cargadas para evitar glifos de prueba en las capturas. Previews y logs no se suben a Git.

## Rendimiento y límites

Sondeos CPU secuenciales a 960×540; cinco rondas de treinta dibujos tras calentamiento. Carga B legal: misión 60, política reference, máximo seis cartas, calendario real hasta 295 s, jefe ya aparecido. Carga A: fixture sintético con once defensores, 80 invasores y jefe. Esta carga excede el equipo legal y no se utiliza para declarar rendimiento normal.

| Carga | Sondeo previo ms/dibujo | Sondeo posterior ms/dibujo | Observador mediana / p95 posterior ms |
| --- | ---: | ---: | --- |
| Legal B | 3,891 | 3,891 | 0,013 / 0,030 |
| Extrema A | 10,252 | 10,974 | 0,040 / 0,070 |

El sondeo previo se hizo antes del cierre de validación y el posterior repite el mismo pintor preservado. **No es una comparación de dos motores ni un A/B de una optimización nueva**: V4.1 no cambia geometría ni algoritmos de pintura. Rango legal previo 3,357–5,768 y posterior 3,756–5,523 ms; extremo 10,144–11,338 y 10,866–11,562. Rangos solapados. La diferencia extrema de +0,722 ms (~7 %) debe interpretarse como variación observada, sin atribuirla causalmente a la UI ni prometer mejora de FPS.

Observadores de visuales/amenazas/audio: 600 pasos por carga, cronómetro excluye `advance`; resultado/checkpoint/RNG idénticos al control. Máximos observados: 16/32 eventos, 6/4 estelas y 28/93 actores para legal/extrema. Presupuestos existentes: 32 eventos, 48 estelas, cinco muestras por estela y ocho entradas de amenaza. Los IDs retenidos corresponden a actores presentes. Tras reset/dispose, actores/estelas/eventos/caché quedan en cero. Seis partidas consecutivas alternan cargas y tamaños; escenario retiene dos Pictures como máximo. Brazo del jefe sigue usando el único Picture estático V4.

JSON completos: `build/previews/mz-v41-profile-before.json` y `...after.json`. La prueba mide grabación Canvas/Picture, no raster GPU, widgets completos, altavoces ni memoria nativa. La creación de pantalla se sondea por separado con cinco montajes a 844×390 (`mz-v41-ui-before/after.json`); incluye tiempos wall-clock de WidgetTester debug y separa el primer arranque frío. No se interpreta como latencia/FPS de Android. No se afirmó ausencia universal de fugas ni consumo estable en celular.

No se introdujo una optimización de render innecesaria. Las mejoras reales son correcciones de guardado/UX y diagnóstico read-only de cachés/observadores; se conserva la optimización V4.

Creación de pantalla en pruebas separadas con el mismo comando/fixture: primer montaje frío V4.0 **504,510 ms**, V4.1 **497,535 ms**. Cuatro montajes siguientes: antes 58,258/55,487/52,044/49,551 ms; después 60,916/51,109/55,763/48,612 ms. Medianas calientes 53,766 y 53,436 ms, rangos solapados. Se documentan muestras, no una mejora significativa ni tiempo de inicio de un teléfono.

## Pruebas y audio

Base V4.0 reejecutada: **322 aprobadas, 11 optativas omitidas, cero fallidas**. Regresiones específicas pasan: guardado false/excepción/reintento, restauración de jefe/poder temporal, ocho ciclos de pérdida/reapertura, recompensa idempotente, gestos y observadores deterministas. La matriz de 540 partidas finalizó sin timeout; conserva derrotas reales. El cierre indica el resultado de la última suite y análisis, después del pulido de contraste.

Mezclador: cinco ejecuciones separadas y secuenciales del test existente, además de la suite completa. Verifica voces limitadas, volumen cero, efectos/música desactivados, pausa larga, reanudación, segundo plano simulado, fuente musical conservada, Láser sin reinicio por frame, salida de efecto y reproductor de revelación separado. No hubo sustitución de archivos ni escucha nueva. No se atribuye una causa al fallo intermitente histórico más allá del problema V4 ya reproducido y corregido.

Reproducción desde `app/`, una orden termina antes de la siguiente:

```powershell
flutter test --no-pub
flutter analyze --no-pub
flutter test test/marus_zombies/gameplay_diagnostic_test.dart --no-pub --dart-define=DIAGNOSE_V41=true
python tool/report_mz_v41.py
flutter test test/marus_zombies/v41_touch_test.dart --no-pub --dart-define=RENDER_V41=true
flutter test test/marus_zombies/v41_performance_test.dart --no-pub --dart-define=PROFILE_V41=true --dart-define=PROFILE_PHASE=after
flutter test test/marus_zombies/combat_mixer_test.dart --no-pub
```

## Licencias: distribución todavía bloqueada

Revisados `assets/audio/LICENSES.md`, bancos/manifiestos V3.5/V3.6 y licencias locales de Fredoka/Nunito/Monocraft. El repo declara efectos CC0, CC BY 3.0 y CC BY-SA 3.0 con autores, fuentes y adaptaciones; conserva atribuciones. Las fuentes incluyen sus textos OFL. No se descargaron recursos ni se alteraron créditos. Esa metadata local no certifica por sí sola toda la cadena de derechos ni sus condiciones de distribución.

**No consta permiso de distribución pública/comercial para `music/marus/zombies-on-your-lawn.mp3` ni `marus_card_victory.mp3`. Constituyen un bloqueo de publicación pública pendiente de autorización o sustitución aprobada.** Tampoco se interpreta «música aportada por el propietario» como licencia de otras pistas de la app. La revisión de recursos de otros módulos y licencias de todo el paquete de distribución sigue siendo una tarea previa a publicar, fuera de la certificación funcional de Marus.

## Matriz de validación manual Android (no realizada)

| Caso | Procedimiento y evidencia a registrar | Estado |
| --- | --- | --- |
| Guardado | Colocar/recoger/atún, pausar y salir; reabrir. Segundo plano y cierre forzado antes/después de checkpoint. Comparar saldo, equipo, HP, jefe y poder restante. | Pendiente físico; kill puede regresar al checkpoint de hasta diez segundos simulados. |
| Tutorial | Persona nueva juega Patio 1 sin ayuda externa; registrar dudas sobre selección, hierba, recarga, Roombas y resultado; luego repetir primeras misiones de mundos. | Pendiente observación humana. |
| Tacto | Equipo de seis; dedo sobre gato con recursos superpuestos, cancelar y confirmar atún/pala, arrastrar fuera, pausa durante gesto, rotar y usar notch real. | Pendiente teléfono. |
| Curva | Misiones 1/10/11/20/21/30/31/40/41/50/51/60; anotar reintentos, duración y cambios de equipo. Comparar sin/atún estratégico; no ajustar antes de recoger resultados. | Diagnóstico bot disponible; experiencia pendiente. |
| Legibilidad | Oleada final, hielo, armadura, empuje, cuatro poderes simultáneos y jefe; brillo bajo/alto, movimiento reducido y texto ampliado. | Capturas/eventos cubiertos; lectura humana pendiente. |
| Audio largo | 45–60 minutos; volumen 0 y normal, silencio, pausa >30 s, segundo plano >1 min, retry, victoria, revelar carta y menú, auriculares si se usarán. Grabar errores/latencia sin cambiar sonidos aprobados. | Canales simulados pasan; sesión física pendiente. |
| UI/raster | En una futura versión profile ejecutada en teléfono por el propietario, abrir DevTools Performance, capturar 60 s por escena legal/extrema, exportar timeline con tiempos UI/raster p50/p95/p99 y frames fuera del presupuesto real del refresco. Anotar modelo, SO, resolución, refresco, temperatura y revisión Git. | No se ejecutó ni preparó build aquí. |
| Memoria | En la misma futura sesión profile, Memory antes, después de diez partidas/navegaciones y tras GC; guardar heap snapshots y memoria nativa/RSS disponible. Evitar comparar primera carga fría con sesión caliente. | Pendiente físico. |
| Consumo | Misma luminosidad/volumen/red y duración; registrar batería/temperatura, CPU/GPU cuando estén disponibles. Repetir escenas equivalentes, comparar revisiones en el mismo equipo. | Pendiente físico. |
| Licencias | Archivar permisos y textos de licencia aplicables al paquete previsto antes de distribuirlo. | Bloqueado para MP3 identificados; no autorizado por esta auditoría. |

No marcar como realizadas estas mediciones, ni usar el FPS del test runner como FPS móvil. No hay APK ni instalación en esta entrega.

## Checklist del propietario: qué se puede afirmar

| Solicitud | Estado verificable |
| --- | --- |
| Cerrar y regresar sin perder progreso | Checkpoints/recompensas/reintentos automatizados pasan; cierre físico y kill pendientes. No garantía del último frame. |
| 60 misiones jugables y dificultad revisada | 60 superables, 540 partidas legales y diferencias documentadas; balance humano pendiente. |
| Cartas, pala y atún cómodos con dedos | Gestos y confirmación cubiertos; comodidad física pendiente. |
| Sin error crítico pendiente y suite aprobada | P0 demostrados corregidos; suite ejecutada, sin certificación de ausencia universal de bugs. |
| Tutorial sin confusión | Ayuda integrada y comprobable; comprensión por jugador nuevo pendiente. |
| Seis mundos entretenidos | Funcionales; entretenimiento y motivación no certificados. |
| Legibilidad en oleadas intensas | Arte/eventos/presupuestos y capturas revisados; lectura real pendiente. |
| Audio y pausa en sesión larga | Pruebas nativas simuladas repetidas; sesión física larga pendiente. |
| Rendimiento en Android real | **No realizado.** |
| Licencias aptas para distribución | **No cerrado; publicación pública bloqueada por permisos no documentados.** |

## Archivos y repositorio

Código: `mz_game_screen.dart`, `mz_progress.dart`, `mz_field_guide.dart`, `mz_screen.dart`, `mz_almanac.dart`, getters de diagnóstico en `mz_scene_layers.dart`/`mz_visual_feedback.dart`. Pruebas nuevas: `gameplay_diagnostic_test.dart`, `support/gameplay_probe.dart`, `v41_touch_test.dart`, `v41_recovery_test.dart`, `v41_performance_test.dart`; smoke test de campaña ajustado. Informes CSV/Markdown y generador Python estándar incluidos.

Sólo se publican código, tests y documentación de esta entrega. No build/, caches, secretos ni logs voluminosos. Rama `codex/marus-zombies-audio`, sin force-push, cambios en main, PR ni merge. Hash/push se confirman al terminar; el hash del propio documento no se inventa dentro de su commit.

## Cierre de validación

- Suite completa final: **339 aprobadas, 14 optativas omitidas, cero fallidas** (`build/mz-v41-final-tests.log`). Se ejecutó después del contraste final y de probar la ayuda expandida/desplazable.
- Análisis final: **sin incidencias** (`build/mz-v41-analyze.log`). Las seis observaciones iniciales de estilo se corrigieron, sin desactivar reglas.
- Capturas/gestos optativos: **12 aprobadas**; captura comparativa aislada antes/actual, una aprobada cada ejecución.
- Diagnóstico + smoke de campaña: **cuatro aprobadas**; CSV final de 540 partidas, sin tiempos agotados.
- Restauración y perfil inicial: cinco aprobadas; perfil posterior: dos aprobadas. Cinco ejecuciones aisladas del mezclador: cinco aprobadas, sin fallos observados en esas repeticiones.
- No se ejecutó compilación, empaquetado, instalación ni medición en un Android físico. La lista del propietario permanece parcialmente abierta por esos límites y los permisos de música.

## Entrega confirmada en GitHub

Implementación V4.1: **`42c95aa2eb6b64b317340122299381623807fdd1`**, `fix(marus): audit V4.1 gameplay and protect saves and touch tools`.

`git push origin HEAD:refs/heads/codex/marus-zombies-audio` terminó correctamente. `git ls-remote origin refs/heads/codex/marus-zombies-audio` devolvió ese mismo hash el 2026-10-10; árbol limpio tras el commit. Esta confirmación se registra en un cierre documental posterior, sin inventar el hash de su propio archivo. Los 20 archivos de implementación incluyen código, pruebas, informes y generador; ningún temporal de build/ ni asset nuevo. Sin force-push, main, PR ni merge.
