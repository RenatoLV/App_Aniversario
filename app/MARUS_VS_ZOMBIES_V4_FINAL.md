# Marus vs Zombies V4.0 · Entrega de código

Fecha: 2026-10-10. Repositorio: `RenatoLV/App_Aniversario`. Rama: `codex/marus-zombies-audio`.

Se conserva Flutter/Dart, Canvas/CustomPainter, arte vectorial procedural, simulación fija de 1/60 s y guardado existente. **No se ejecutaron compilaciones ni empaquetados en V4.0**: no APK, AAB, instaladores, firma, SDK ni Gradle. Las compilaciones web documentadas en V3.9/V3.9.1 pertenecen a entregas anteriores.

## Estado de las fases

| Fase | Resultado verificable |
| --- | --- |
| 0 · Auditoría | Rama y remoto correctos, sin divergencia inicial. Base: 314 pruebas aprobadas, diez optativas omitidas. Conservadas las modificaciones locales V3.7–V3.9.1. |
| 1 · Defensores | Los once ya estaban refinados al entrar en V4, incluidos Bumerán, Resorte y Relámpago de V3.9.1. Se conservaron y se probaron juntos; no se sustituyeron sus diseños. |
| 2 · Jefe | Brazos hidráulicos, articulaciones, puños, núcleo y expresión del robot. Movimiento secundario y respuesta a acciones especiales observadas. Entrada ámbar diferenciada del Láser; barra y entrada sin recorte superior. Se reutiliza la caída/desaparición existente. |
| 3 · Campaña | La estrategia de prueba recorre ahora realmente las 60 misiones. Se verifican seis mundos, orden, IDs históricos, calendario de aparición, obstáculos, checkpoint, recompensas repetidas y desbloqueos. Sin cambiar dificultad ni requisitos. |
| 4 · Transiciones | Cinco cambios de mundo y cierre de campaña, con postales vectoriales existentes, Maru y Lady, fundido y movimiento breve. Se muestran al continuar/salir tras una primera victoria final ya guardada. Omitibles y compatibles con movimiento reducido. |
| 5 · Combate | Recogida con diámetro táctil mínimo de 48 px y prioridad al recurso real más cercano. Conservados arrastre, pala, atún, oleadas, estados y Roombas. Corrección del recorte del cartel del jefe. |
| 6 · Móvil | Transiciones y HUD real probados en vertical y horizontal compactos. Se mantienen SafeArea, cartas desplazables, paneles de resultados, almanaque y revelación ya existentes. Las suites previas de esas pantallas siguen pasando. |
| 7 · Audio | Sonidos y músicas aprobados conservados. Corregida la recarga de fuente tras pausa prolongada/segundo plano. Prueba usa la finalización real de la cola musical en lugar de adivinar su duración. Créditos y manifiestos revisados. |
| 8 · Rendimiento | Un Picture estático reutilizado para ambos brazos del jefe; eliminación de la copia filtrada de muestras en cada estela de pez. Cachés de escenario, RepaintBoundary, limpieza y presupuestos conservados. Perfil CPU reproducible, sin atribuirle FPS móviles. |
| 9 · Bugs | Corregidos pausa musical prolongada, recorte de entrada del jefe y cobertura incompleta de la prueba de campaña. Regresiones añadidas; ninguna prueba deshabilitada para ocultar errores. |
| 10 · Validación | Suite completa, análisis estático, capturas y perfiles. Resultados finales consignados abajo. |
| 11 · Documentos | Este documento y sección V4.0 en `MARUS_VS_ZOMBIES_VISUAL_EVOLUTION_V3.md`. |
| 12 · GitHub | Se registra el commit y la comprobación remota en el apartado de entrega. Sin force-push, PR ni fusión automática. |

## Comportamiento del jefe

El observador visual detecta el reinicio real de `special`, igual que ya lo hacía para Pianotrón. El jefe mueve sus brazos durante esa acción, además del movimiento ambiental discreto. No se crean golpes ni nuevos ataques. Los avisos de pisotón, invocaciones, cambio de fila y daño conservan el motor anterior.

Las superficies de los brazos se graban una vez en un Picture pequeño, reflejado para el lado opuesto y transformado sobre pivotes fijos. Es una caché acotada de la biblioteca artística durante la vida de la aplicación, independiente de las cachés de cada escenario. No crece con enemigos ni partidas. Movimiento reducido elimina las oscilaciones y reacciones dinámicas.

La presentación ámbar corresponde a la aparición real observada. El cartel permanece dentro de la pantalla durante su desplazamiento inicial. En tableros bajos se conserva la barra y se omite el contador numérico si no cabe, evitando superponerlo con las casillas. La vida siempre procede del invasor real.

## Transiciones y progresión

Se integran en `_leave()` y `_restart(next: true)`, después de `MzProgress.complete()`. Requieren campaña, victoria, misión final de mundo y `receipt.starsBefore == 0`. Un guardado fallido no inicia la transición. No se escriben premios, monedas ni registros nuevos por mostrarla.

El control temporal de la pantalla evita abrir varias transiciones al tocar repetidamente. Al repetir una misión ya completada no se vuelve a celebrar. Regresar al mapa tampoco reproduce transiciones antiguas. «Omitir», «Continuar» y cerrar el diálogo permiten seguir; las recompensas ya están guardadas.

Orden visible e IDs conservados:

| Mundo | Misiones visibles | IDs internos |
| --- | --- | --- |
| Patio | 1–10 | 0–9 |
| Cementerio | 11–20 | 50–59 |
| Egipto | 21–30 | 10–19 |
| Piratas | 31–40 | 20–29 |
| Oeste | 41–50 | 30–39 |
| Futuro | 51–60 | 40–49 |

`highest` sigue contando los 50 IDs históricos para conservar los requisitos antiguos. `cemeteryHighest` cuenta sus diez misiones y `campaignCompleted` los 60 niveles. No se sustituye el primero por el total de campaña: eso desbloquearía cartas antes de lo previsto. Se mantienen las pruebas de partidas antiguas, requisitos del almanaque y acceso al Cementerio. El jefe final sigue siendo ID 49, misión visible 60.

La prueba de campaña anterior se llamaba «60 misiones» pero generaba IDs 0–49. Ahora itera `mzCampaign`, incluyendo Cementerio. La estrategia existente completó las 60 sin poderes pagados. Es una prueba de estrategia conservadora; no certifica el equilibrio óptimo ni la dificultad percibida.

## Audio y fallo intermitente

Una prueba nueva reprodujo que tras una pausa prolongada `setSourceUrl` aumentaba de ocho a nueve llamadas: la transición hacia silencio destruía el reproductor y la reanudación comenzaba otra fuente. Ahora pausa/segundo plano conserva reproductor y posición si la misma pista pertenece a la escena actual. Desactivar música o abandonar esa escena sigue liberando/cambiando el reproductor.

`GameAudio.musicSettled` expone la finalización de la cola existente, incluida preparación nativa. La prueba espera esa señal para validar reanudación, además de comprobar una pausa de 850 ms y un ciclo de segundo plano. No se silencian aserciones ni se sustituyen sonidos.

Esto corrige el defecto reproducido de pausa larga y elimina esperas estimadas en puntos concretos del test. **No demuestra que fuese la causa única del fallo intermitente previo**. Las comprobaciones nativas usan canales simulados: no se afirma escucha humana, latencia real ni calidad auditiva medida.

## Pruebas y resultados

- Base antes de V4: **314 aprobadas, diez omitidas, cero fallidas**.
- Suite final: **322 aprobadas, once omitidas y cero fallidas** (`build/mz-v40-final-tests.log`).
- Capturas/perfil V4 optativos: ocho aprobadas en la ejecución realizada; la prueba de estrés adicional se incorporó después y se ejecuta en la suite final.
- Análisis estático final: **sin incidencias**, ejecutado después de la suite (`build/mz-v40-analyze.log`).
- Prueba de pausa antes de la corrección: un fallo esperado/reproducido. Después, mixer y campaña pasaron. No se confunde ese registro inicial con el resultado final.

Se comprueban los 60 calendarios de aparición y escenarios, checkpoint/RNG contra control, las seis primeras victorias finales y su progreso, ausencia de recompensas repetidas, las once cartas desbloqueadas al terminar, impactos reales del jefe y ausencia de celebración al restaurar. El fixture de estrés reúne los once defensores, 80 invasores y un jefe; es un escenario sintético para cubrir combinaciones, no un equipo jugable de once cartas. Se conservan seis cartas equipables.

Las pruebas existentes cubren almanaque, cartas, revelación, victoria/derrota, accesibilidad, progresión antigua, mecanismos de Piratas/Oeste/Futuro, Roombas, pausa, x2, audio y habilidades. Se han ejecutado juntas, sin procesos de compilación paralelos.

Nuevas superficies revisadas a 320×568, 640×320, 844×390 y escritorio hasta 1440×900. Las capturas del jefe comparan la geometría antigua/nueva sobre el mismo estado del motor; comparten correcciones de layout. Hay ocho fotogramas de jefe —entrada, acción especial, daño y derrota— y seis transiciones. Permanecen en `build/previews/`, excluidos de Git.

## Rendimiento medido

Perfil final de CPU al grabar Canvas/Picture a 960×540, escenario cacheado, fixture saturado con 80 invasores, jefe, once defensores y poderes reales. Cinco rondas de treinta dibujos tras calentamiento, alternando orden de versiones:

| Versión | Mediana ms/dibujo | Rango |
| --- | --- | --- |
| Geometría anterior del jefe | 12,216 | 11,561–12,265 |
| Jefe refinado con brazo cacheado | 12,528 | 11,928–13,079 |

Diferencia de muestra: **+0,313 ms (~2,6 %)**. Rangos solapados; no permite afirmar un sobrecosto estable ni una mejora global de FPS. La prueba compara el refinamiento del jefe; ambas ramas conservan V3.7–V3.9.1 y las restantes mejoras V4. Los datos completos están en `mz-v40-profile.json`.

No se mide rasterización GPU, reconstrucción de toda la UI, reproductor real, memoria nativa en dispositivos ni Android/iOS. Los presets no certifican rendimiento en teléfonos económicos.

## Licencias y recursos

Se revisaron `assets/audio/LICENSES.md`, `audio_sources/marus/manifest.json`, `patio_selection_v35.json`, `v36/manifest.json`, `defender_selection_v36.json` y la selección musical. Los diez originales del manifiesto V3.6 existen y coinciden con sus SHA-256. **La integridad de un archivo no es autorización de distribución.**

Los manifiestos/atribuciones existentes declaran fuentes CC0, CC BY 3.0 y CC BY-SA 3.0 y describen sus adaptaciones. Se conservaron créditos y archivos; V4 no descargó audio ni música. Esta auditoría local no certifica independientemente toda la cadena de licencias.

`music/marus/zombies-on-your-lawn.mp3` y `marus_card_victory.mp3` son aportes del propietario, ya existentes en el repositorio. **No consta una autorización de distribución pública/comercial** en los documentos revisados; no se declaran CC0 ni libres de derechos. Debe resolverse ese permiso antes de distribuir públicamente la aplicación. No se cambiaron las pistas aprobadas.

## Archivos de la entrega

Código V4: `lib/game_audio.dart`, `lib/marus_zombies/mz_world_transition.dart`, `mz_game_screen.dart`, `mz_character_art.dart`, `mz_painter.dart`, `mz_visual_feedback.dart`, `mz_combat_art.dart`, `mz_threat_art.dart`.

Pruebas V4: `test/marus_zombies/v4_polish_test.dart`, `campaign_test.dart`, `combat_mixer_test.dart`.

Incluidas también las mejoras locales previas V3.7–V3.9.1: `mz_threat_feedback.dart` y pruebas `threat_feedback_test.dart`, `tuna_visual_test.dart`, `special_visual_test.dart`, `final_defender_visual_test.dart`, junto con sus cambios de arte/observadores y documentación V3. No se descarta trabajo anterior ni se reescriben esos avances.

No hay cambios en simulación, catálogo, niveles, modelos, guardado, economía, estadísticas, dependencias ni assets de audio. No se publican previews, cachés o archivos de compilación.

## Mantenimiento y pendientes

Desde `app/`:

```powershell
flutter test --no-pub
flutter analyze --no-pub
flutter test test/marus_zombies/v4_polish_test.dart --no-pub --dart-define=RENDER_V4=true
```

La última orden produce capturas/perfiles y **no compila una aplicación**. Esperar a que finalice una tarea antes de otra para perfiles comparables. Seguir usando `capturePower()` antes de `feed()`, eventos reales y observadores que no escriben en la simulación. Al añadir cambios de campaña, respetar IDs históricos y contrastar requisitos con `highest`, no con el total visible.

Pendientes para la posterior prueba en celular: tacto y notch reales, legibilidad subjetiva, GPU/FPS, memoria, latencia audiovisual, interrupciones nativas y retorno desde segundo plano. Comprobar larga pausa y navegación durante carga musical en Android/iOS. Obtener/confirmar permisos para los MP3 comerciales. No hay fallos pendientes en la suite final ejecutada; no equivale a una certificación de distribución.

## Entrega a GitHub

Commit de implementación: **pendiente de consignar tras crear el commit**.

Push: **pendiente de verificar**. El resultado real se registra después de confirmar `git push` y comparar HEAD remoto. No se utiliza force-push ni se publica en `main`.
