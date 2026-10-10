# Marus vs Zombies — diseño y plan de implementación

Estado: implementación inicial disponible, 10 de octubre de 2026. Acceso en los juegos del Patio. Ver [estado y controles](MARUS_VS_ZOMBIES.md) para distinguir lo implementado y la validación pendiente. Este documento conserva el diseño de referencia.
Los valores numéricos son una base de balance que se ajustará jugando.

## 1. Visión y alcance

Juego de defensa por carriles integrado en Anivermaru, para Android y web. Maru y Lady protegen su hogar reclutando gatos contra una invasión cómica de gatos y perros zombis. Partidas de campaña de 3–5 minutos, sin conexión obligatoria. Arte y animaciones propios: gatos completos, expresivos, con patas, bigotes y colas.

La referencia adjunta guía colores, patio, tarjetas de madera, gatos y robot. La composición jugable será un tablero inequívoco de **5 filas × 9 columnas**, enemigos desde la derecha y casa a la izquierda. Las cinco Roombas ocupan una franja externa, una por fila; no consumen columnas de plantación. El robot bulldog aparece en niveles de jefe.

Alcance completo propuesto: cinco mundos de diez niveles, once defensores, un ancestral inicial, cuatro enemigos base, enemigos temáticos, atún, tres poderes humanos, campaña, desafíos y supervivencia. Construcción por entregas; los 50 niveles no forman parte del primer prototipo.

## 2. Bucle y reglas de partida

1. Elegir nivel; ver enemigos, reglas y recompensa antes de comenzar.
2. Preparar hasta seis tarjetas de defensores desbloqueados. El tutorial presta las necesarias.
3. Empezar con 150 de hierba, cinco Roombas y diez segundos de preparación.
4. Recoger hierba, seleccionar tarjeta y tocar una casilla válida. Arrastrar es opcional.
5. Defender las oleadas, reforzar carriles y decidir cuándo gastar atún o galletitas.
6. Ganar al finalizar los eventos de invasión y eliminar los enemigos restantes; perder si uno cruza el límite de la casa sin defensa de emergencia disponible.
7. Ver estrellas, desbloqueos y recompensas; continuar o reintentar.

- Una unidad defensora por casilla. Colocar requiere hierba suficiente, tarjeta recargada y terreno compatible; una acción inválida no cobra recursos.
- Los enemigos avanzan continuamente por su fila, se detienen ante defensores y atacan. No se bloquean entre ellos.
- Los ataques normales buscan enemigos válidos delante; las habilidades especiales declaran sus excepciones.
- Pala: seleccionar y retirar un gato; sin reembolso, sin reiniciar la recarga. Previsualización antes de confirmar la casilla.
- Una Roomba se activa una sola vez, atraviesa su fila eliminando enemigos comunes y luego desaparece. No daña unidades aliadas ni regresa. Contra jefes aplica daño limitado definido por el encuentro.
- Pausa real al abrir menús, perder foco o pasar a segundo plano. No se acumulan ataques ni recursos durante la pausa.
- Empates de un mismo paso de simulación: resolver daño y muertes antes de comprobar invasión. Un enemigo muerto en ese paso no puede provocar derrota.

### Recursos

| Recurso | Uso | Obtención y persistencia |
|---|---|---|
| Hierba gatera | Reclutar durante el nivel | Burbujas de 25; cielo cada 8 s y girasoles. Se reinicia por partida |
| Atún premium | Habilidad de un defensor | Enemigos brillantes previstos en el nivel; máximo 3 latas. Se reinicia por partida |
| Galletitas | Poderes de la Mano del Humano y compra de atún | Recompensas de campaña y desafíos; saldo propio del módulo |
| Mentitas | Desbloquear ancestrales | Hitos y desafíos; saldo propio del módulo |
| Monedas de Anivermaru | Premios por hitos | Integración limitada con GameStore; no se convierten automáticamente en galletitas |

Las burbujas permanecen 10 s y se recogen tocándolas; ofrecer recogida automática como ajuste de accesibilidad. Primera producción del girasol a los 8 s; siguientes cada 24 s. El cielo sigue produciendo en los niveles normales. Los niveles con economía especial lo anuncian antes de empezar.

Propuesta de economía persistente: 100 galletitas por primera victoria y 25 por cada estrella adicional conseguida por primera vez. Repetir una estrella no repite el premio. Desafíos rotativos y hitos de supervivencia aportarán fuentes renovables. Sin compras con dinero real en este alcance. Atún comprado: 75 galletitas, máximo una compra por nivel.

## 3. Defensores y balance inicial

Vida normal: 300. Daño expresado por impacto; enfriamiento de tarjeta separado de cadencia de ataque. Todos los valores son hipótesis, no estadísticas copiadas de otro juego.

| Defensor | Hierba / recarga | Acción normal | Atún premium |
|---|---|---|---|
| Gato Lanzador | 100 / 5 s | 20 de daño cada 1,4 s; ovillo verde recto | Casco de piloto; 60 ovillos en 1 s, 10 de daño cada uno |
| Gato Siberiano | 175 / 8 s | 20 cada 1,8 s; reduce movimiento y ataque 40% durante 3 s | Ventisca del carril: 200 de daño y congelación 2 s |
| Gato Girasol | 50 / 5 s | Genera 25 de hierba cada 24 s | 15 burbujas de 25; total 375 de hierba |
| Gato Barrera | 50 / 15 s | 3.000 de vida; ocupa una casilla | Restaura vida y añade 6.000 de armadura; total máximo 9.000 |
| Gatitos Bomba | 150 / 30 s | Detonan tras 0,8 s: 1.200 de daño en área 3×3; se consumen | No admite atún: la tarjeta lo indica |
| Gato Caja | 25 / 15 s | Se arma en 8 s; contacto: 1.200 de daño al activador y se consume | Se arma y crea hasta 2 cajas armadas en casillas legales vacías |
| Gato Catapulta | 125 / 7 s | Croqueta de 35 cada 2,2 s; arco sobre obstáculos | Una croqueta de 150 a cada enemigo, máximo 12 objetivos |
| Gato Bumerán | 175 / 8 s | Pez de 20 cada 2 s; hasta 3 objetivos, ida y vuelta | Tres peces reforzados de 40 por impacto |
| Gato Resorte | 75 / 12 s | Empuja 1,5 casillas; recarga interna de 5 s | Empuja 3 casillas a enemigos cercanos de su fila |
| Gato Relámpago | 150 / 7 s | 15 cada 1,5 s; cadena de hasta 3 objetivos cercanos entre filas | Hasta 8 objetivos reciben 120 de daño |
| Gato Láser | 225 / 10 s | Haz de 30 de daño/s contra toda su fila; ignora escudos | Haz de 150 de daño/s durante 3 s |

El Barrera puede tener dos apariencias: hecho una bola o dentro de una caja. Una variante alta y más resistente queda para contenido posterior, no duplica el rol inicial.

Reglas compartidas: ralentizaciones no se multiplican; prevalece la más fuerte y se refresca su duración. No encadenar congelación permanente: 3 s de inmunidad al descongelarse. Daño sobrante rompe armadura y pasa al cuerpo. Las explosiones afectan obstáculos destructibles. Los gatos desaparecen entre pelusa y estrellas, sin gore.

El atún no se acumula sobre una habilidad activa. Armadura del Barrera se restablece al máximo, no suma capas. Si el Gato Caja tiene una sola casilla libre, crea una copia; si no tiene ninguna, se rechaza el uso sin consumir lata. Las copias no generan nuevas copias por sí solas.

## 4. Invasores

| Enemigo | Vida / protección | Comportamiento |
|---|---|---|
| Gato zombi común | 200 | Avanza 0,15 casillas/s; mordida de 50 cada segundo |
| Zombi con cono veterinario | 200 + 200 | Misma base; pierde visualmente el cono al romperse |
| Zombi con balde/lata | 200 + 600 | Avanza 0,12 casillas/s; armadura pesada |
| Gato de bandera | 260 | Avanza 0,18 casillas/s; anuncia la gran oleada |

El director de oleadas controla los refuerzos; la bandera no genera enemigos sin límite. Gatos y perros pueden compartir estadísticas con siluetas distintas. Enemigos brillantes dejan una lata al ser derrotados; la semilla y el nivel determinan cuáles lo son para asegurar oportunidades de aprendizaje.

### Dr. Cat-trófico

Bulldog de chatarra gigante, manejado por un gato científico. Jefe final del futuro; los finales anteriores usan encuentros temáticos más simples.

- Vida inicial de prueba: 12.000; tres fases delimitadas por 70% y 35% de vida.
- Fase 1: invoca zombis en dos filas y muestra núcleos vulnerables alineados con carriles.
- Fase 2: golpe de pata telegrafiado durante 2 s en hasta dos casillas; afecta defensores y no la casa directamente.
- Fase 3: sobrecarga, cambios de carril vulnerable y refuerzos limitados.
- Cada núcleo transmite daño al mismo jefe, pero un único proyectil no cuenta varias veces por el tamaño del dibujo.
- Nunca bloquear todas las filas vulnerables; debe poder derrotarse sin consumibles persistentes. Inmune a empujones y ejecuciones, con resistencias explícitas a control.

## 5. Mano del Humano y ancestrales

Los poderes se seleccionan con botón y muestran alcance y coste. Gestos especiales son opcionales; deben funcionar con un dedo, ratón y teclado. Cobrar solo al ejecutar una acción válida. Recarga global inicial: 15 s.

| Poder | Coste propuesto | Regla |
|---|---|---|
| Pellizco | 50 galletitas | Derrota un enemigo común seleccionado; 500 de daño a élites, 250 al jefe |
| Láser de juguete | 75 | Arrastre de hasta 2 s; atrae hasta 5 enemigos en un radio de 2 casillas dentro de sus carriles y luego los empuja 2 casillas |
| Spray de agua | 100 | Área 3×3, 150 de daño y aturdimiento 2 s; jefe recibe daño y 0,5 s de interrupción |

El láser puede tirar enemigos al agua. Salir por el borde derecho elimina enemigos comunes; élites se detienen en el límite. El control no permite llevarlos directamente a la casa. Las colisiones causadas por el poder producen 50 de daño una vez por pareja y activación.

**Gran León Mítico:** desbloqueo por 100 mentitas; diez mentitas por primera victoria de jefe y cinco por hito de desafío nuevo. Disponible después del mundo 3 mediante retos adicionales. Se equipa en una ranura propia, una invocación gratuita por nivel tras desbloquearlo, no ocupa una casilla.

Al invocarlo: rugido de 200 de daño global y daño ×3 durante 15 s para Lanzadores y Bumeranes. El rugido limpia enemigos débiles y daña resistentes; no ejecuta jefes. El bono también afecta su atún, pero no se multiplica con otro ancestral. Otros míticos y familias se diseñarán después de probar este sistema.

## 6. Campaña de cinco mundos

Diez niveles por mundo: 1–2 introducción, 3–4 combinación, 5 desafío guiado, 6–8 variaciones, 9 gran oleada y 10 jefe. Desbloqueo secuencial por victoria, sin exigir tres estrellas. Duración de jefes: objetivo 5–7 minutos.

| Mundo | Terreno y reglas | Nuevas unidades y amenazas |
|---|---|---|
| Patio de Maru | Césped 5×9, cajas y rascadores decorativos fuera de casillas | Siete defensores base; común, cono, balde y bandera; final contra caravana de baldes |
| Reino del Gato Faraón | Tumbas destructibles ocupan casillas y bloquean disparos rectos; catapultas atacan detrás | Bumerán; momia, faraón con sarcófago y ladrón que roba burbujas sin recoger |
| Barco del Perro Pirata | Máscara de agua, cubiertas y tablones manteniendo 5×9 | Resorte; corsario que aterriza en casilla anunciada, loro que secuestra un gato y cañón de huesos |
| Saloon de los Gatos Callejeros | Vías fijas y carritos con una unidad; arrastre vertical entre posiciones legales | Relámpago; pianista que cambia enemigos de fila y minero que aparece detrás |
| Cyber-Gatos 2099 | Nodos holográficos unidos por color y símbolo | Láser; mecha y perro de escudo hexagonal; Dr. Cat-trófico |

Reglas de borde que se implementarán explícitamente:

- Tumbas: la primera recibe el disparo recto; atraviesos del Bumerán se bloquean por piedra. Se avisa antes de levantar nuevas tumbas y nunca se reemplaza un defensor.
- Piratas: no se puede plantar sobre agua; empujar enemigos al agua los elimina. Roturas de tablón tienen aviso de 2 s; sus ocupantes caen. Cada nivel conserva rutas transitables desde la entrada a la casa. El loro libera al gato en su casilla original si muere antes de escapar; si está ocupada, usa la vacía más cercana de la misma fila; sin espacio, el gato se pierde.
- Oeste: mover carritos es una orden de simulación; no permite duplicar gatos ni entrar en casillas ocupadas. Los proyectiles ya disparados conservan trayectoria. Mineros salen con aviso de 2 s y después se dirigen a la casa; minas, bombas y carritos aportan contrajuego.
- Futuro: gastar una lata activa una sola vez los gatos compatibles en nodos del mismo grupo. Se fija la lista al iniciar; no hay activación recursiva, nuevas latas ni duplicación de efectos. Nodos identificados también con símbolos para daltonismo.

### Primer mundo, nivel por nivel

| Nivel | Enseñanza / desbloqueo |
|---|---|
| 1 | Lanzador y hierba del cielo; tres carriles activos dentro de la cuadrícula 5×9 |
| 2 | Girasol y economía; se habilitan los cinco carriles |
| 3 | Barrera y cono veterinario |
| 4 | Siberiano y mezcla de enemigos |
| 5 | Caja y tiempos de armado |
| 6 | Gatitos Bomba y grupos compactos |
| 7 | Catapulta y primer balde |
| 8 | Enemigo brillante, atún y selección de seis tarjetas entre siete |
| 9 | Bandera, dos grandes oleadas y uso de Roombas |
| 10 | Caravana de baldes, jefe sencillo con refuerzos finitos; acceso a Egipto |

Estrellas independientes y visibles desde la preparación: una por ganar, otra por ganar sin activar Roombas y otra por cumplir objetivo del nivel. Ejemplos: conservar dos girasoles o no perder más de tres defensores. Ninguna exige gastar galletitas. Registro de mejor resultado, sin quitar estrellas ganadas.

Campaña primero. Supervivencia posterior: intensidad por oleada, descansos de compra y récord local. Desafío rotativo posterior: semilla fija, mazo prestado y consumibles persistentes desactivados para comparar resultados. Clasificación en línea requiere validación adicional del backend antes de publicarse.

## 7. Pantallas, controles y dirección artística

Flujo: Inicio de Anivermaru → portada del módulo → mapa → preparación → partida → resultados. Portada con Continuar, Mundos, Almanaque y, cuando existan, Desafíos y Supervivencia. Almanaque muestra coste, resistencia, habilidad y contrajuego.

En partida: hierba, seis tarjetas con coste y recarga, barra de oleadas, pausa, pala, atún y poderes. Previsualización de colocación válida/inválida; selección cancelable; alerta de fila amenazada. Aviso «¡Se acerca una horda de michis!» antes de cada gran oleada.

Diseño principal horizontal: tablero central, reserva de Roombas a la izquierda y zona de entrada a la derecha. En vertical se mantiene visible el tablero completo y se permite seleccionar una casilla ampliada antes de confirmar; sugerencia de girar, sin bloqueo de orientación. Prototipar ambos diseños antes de producir todo el arte: nueve columnas en un teléfono estrecho requieren interacción asistida.

Ratón: clic tarjeta y casilla; clic derecho cancela. Teclado: 1–6 tarjetas, flechas para casilla enfocada, Enter confirma, Escape pausa/cancela. Texto y botones con tamaño adaptable, reducción de movimiento, vibración y audio desactivables. Indicadores de estado por icono además de color.

Arte: ilustración 2D cálida, contornos oscuros, césped legible, sombras suaves y efectos de pelusa. Separar siluetas de defensor y enemigo; nada de decoraciones tapando amenazas. Barras de vida breves al recibir daño, armaduras con estados de rotura. Maru y Lady pueden presentar tutorial y resultados; su apariencia no cambia el balance.

Producción de assets: diseñar primero una hoja de estilo y un gato a tamaño real de casilla. Luego fondos por mundo, once defensores, enemigos, jefe, cinco estados de Roomba y efectos. Animaciones por unidad según rol: reposo, ataque/producción, impacto, habilidad y desaparición; caminar/morder para zombis, armado para cajas. Atlas con anclaje y hitbox documentados; resolución lógica y variante de mayor densidad. El prototipo usa dibujos simples originales; el arte final sustituye recursos sin modificar reglas.

Sonido: colocación, ovillo, mordida suave, hierba, lata, alarma, Roomba, explosión de pelusa, victoria y derrota. Música propia o con licencia compatible por mundo; reutilizar controles de volumen del proyecto.

## 8. Arquitectura adaptada al repositorio

Base comprobada: Flutter/Dart, Android y web; GameStore, SharedPreferences, ProgressSync, Firebase y GameAudio ya existen. Bomber Miau separa pantalla, simulación y painter. No hay Flame declarado en pubspec.yaml. Propuesta: conservar Flutter y CustomPainter inicialmente; evaluar un motor adicional solo si el prototipo medido lo justifica.

```text
app/lib/marus_zombies/
  mz_screen.dart            # Portada, mapa, preparación y resultados
  mz_game_screen.dart       # Ticker, ciclo de vida, controles y overlays
  mz_simulation.dart        # Reglas Dart sin dependencia de widgets
  mz_models.dart            # Entidades, estados, coordenadas y eventos
  mz_catalog.dart           # Definiciones de gatos, enemigos y habilidades
  mz_level.dart             # Formato y validación de niveles
  mz_levels.dart            # Primeros niveles tipados
  mz_wave_director.dart     # Programación y presupuesto de invasiones
  mz_combat.dart            # Objetivos, impactos y estados temporales
  mz_world_rules.dart       # Terreno, tumbas, agua, vías y nodos
  mz_painter.dart           # Dibujo de tablero, unidades y efectos
  mz_input.dart             # Traducción de toques/teclado a órdenes
  mz_progress.dart          # Progreso, inventario, migraciones y guardado
  mz_assets.dart            # Atlas, precarga y anclajes
app/assets/marus_zombies/
app/test/marus_zombies/
```

Entidades con identificadores estables: Defender, Invader, Projectile, Pickup, Roomba, TerrainCell y Boss. Estados de enemigo: entrando, caminando, atacando, controlado, derrotado. Los efectos visuales consumen eventos del motor y no deciden daño.

Órdenes: PlaceDefender, RemoveDefender, CollectPickup, FeedTuna, UseHumanPower, MoveCart, SummonAncestor. Cada una valida estado, casilla, coste y recarga dentro del motor antes de modificar datos. La interfaz no descuenta recursos por su cuenta.

Simulación a paso fijo de 1/60 s, coordenadas lógicas en casillas y semilla reproducible. Ticker acumula tiempo e interpola render; máximo cinco pasos por frame para evitar bloqueos. Interrupciones largas pausan en vez de simular ataques invisibles. Orden estable: órdenes → apariciones → estados/movimiento → ataques/impactos → bajas → recogibles → Roombas e invasión → victoria. Colisiones barridas evitan que proyectiles rápidos atraviesen blancos entre pasos.

Agrupar enemigos por carril; comprobar solo candidatos relevantes. Fondo estático separado, RepaintBoundary y caché de sprites; actualizar HUD solo cuando cambian sus datos. Ráfaga de 60 ovillos conserva impactos individuales, con límite separado para partículas decorativas. Los límites de partículas nunca eliminan daño ni enemigos. Láser usa daño por tiempo, no por frame.

Formato de nivel: id, worldId, version, seed, terrain, startingCatnip, allowedCards, objectives, waves, guaranteedDrops y rewards. Una oleada contiene tiempo mínimo, aviso, grupos (tipo, fila, cantidad, intervalo) y condición de avance. Validar rutas, IDs, casillas, recompensas y final alcanzable. Empezar con datos Dart tipados; JSON/editor cuando el formato esté estable.

### Integraciones concretas

- `home.dart`: tarjeta `marus-vs-zombies`, navegación `/marus-zombies` y llamada con GameStore, siguiendo la entrada de Bomber Miau.
- `game_audio.dart`: escena musical y efectos; registrar pistas en `assets/audio/music/tracks.json` y assets en `pubspec.yaml`.
- `store.dart`: premios globales de hitos mediante `rewardGameCoins` con IDs estables como `mz:world:patio:first-clear`; importes por calibrar contra la economía actual.
- `progress_sync.dart`: añadir clave `marusZombies.v1`, restauración y aislamiento por cuenta. Respetar su control de revisiones; no sumar saldos de dos dispositivos.
- `game_result.dart`: ampliar ResultTheme y sus switches si se reutiliza; si la pantalla requiere estrellas/mazo, componer una tarjeta específica del módulo.
- Firebase: campaña local no necesita tráfico por frame. Revisar límites y validaciones de snapshots antes de sincronizar la nueva clave; rankings o premios globales verificables implican funciones, reglas y pruebas de backend.

## 9. Guardado, economía y confiabilidad

Progreso versionado: niveles completados, estrellas máximas, gatos/mundos desbloqueados, mazo, galletitas, mentitas, ancestral y ajustes. Partida suspendida separada: versión de contenido, semilla/estado del generador, paso, entidades, recursos, recargas, oleadas, Roombas e IDs de operaciones.

Guardar al finalizar nivel, gastar moneda persistente y suspender. Para consumos/recompensas mantener registro de operaciones con ID: una repetición tras cierre inesperado no debe cobrar ni premiar dos veces. Primero persistir una operación pendiente, luego aplicar cambios y marcarla completada; recuperar pendientes al arrancar. Las compras persistentes y el snapshot se actualizan juntos para impedir restaurar una lata sin su coste.

Retomar siempre pausado. Si una actualización invalida el snapshot, conservar campaña e inventario y reiniciar el nivel con explicación; los gastos persistentes de esa partida incompatibles se restituyen una sola vez mediante el registro. Una restauración de nube no pisa una partida activa: resolver al volver al menú. No fusionar snapshots de partidas.

La campaña local no se considera prueba confiable para una clasificación competitiva. El primer lanzamiento entrega progreso local y recompensas idempotentes; validación de resultados en servidor se diseña antes de habilitar competencia con valor global.

## 10. Plan de entregas y criterios de aceptación

| Etapa | Entrega concreta | Lista para avanzar cuando… |
|---|---|---|
| 0. Diseño técnico y visual | Wireframe horizontal/vertical, catálogo tipado y formato de nivel | Tablero legible y selección cómoda en móvil; reglas ambiguas cerradas |
| 1. Primera partida completa | Una misión, Lanzador/Girasol/Barrera, común/cono, hierba, Roombas, pausa y resultado | Se puede ganar y perder; recursos, impactos y pausa son correctos |
| 2. MVP integrado | 10 niveles del patio, siete gatos, cuatro enemigos, atún básico, mapa, guardado y audio | Campaña completada de principio a fin en Android y web, sin gastos obligatorios |
| 3. Expansión táctica | Mano del Humano, economía de galletitas, almanaque, mejoras de arte | Cobros recuperables, controles equivalentes y habilidades balanceadas |
| 4. Mundos | Egipto → Piratas → Oeste → Futuro, diez niveles cada uno | Cada mundo pasa pruebas de terreno y aporta contrajuego antes del siguiente |
| 5. Endgame | Dr. Cat-trófico, Gran León, desafíos y supervivencia | Jefe vencible sin compras; progreso y retos sostenibles |
| 6. Pulido y lanzamiento completo | Assets finales, rendimiento, accesibilidad y sincronización | Pasa batería de aceptación, dispositivos objetivo y regresiones del proyecto |

No asignar fechas cerradas sin medir las primeras dos etapas y el coste de animación. Estimar las siguientes usando tiempo observado por enemigo, nivel y conjunto de sprites. Entregar una versión jugable al terminar cada etapa, no esperar al juego completo.

### Pruebas necesarias al implementar

- Motor: daño/armadura, targeting, cadencia independiente de FPS, ralentización, ráfaga, minas, economía, Roomba única por carril y orden victoria/derrota.
- Simulación reproducible: misma semilla y órdenes generan mismo resultado; repartir igual tiempo en frames distintos no cambia el combate dentro de los límites de pausa.
- Escenarios de mundos: tumba bloqueante, casilla de agua, tablón roto, secuestro, minero, carrito ocupado y activación de nodos sin recursión.
- Persistencia: doble resultado, doble toque de compra, cierre entre operaciones, snapshot incompatible, cambio de cuenta y conflicto de revisiones.
- Widgets: tocar/arrastrar, teclado, coste insuficiente, pausa, vuelta al menú, distintos tamaños y texto ampliado.
- Sesiones reales: completar patio sin atún comprado ni Mano del Humano; comprobar aperturas recuperables y que una mala decisión no provoque derrota inevitable antes del aviso.
- Rendimiento en dispositivo Android de referencia y navegador: objetivo 60 FPS, prueba con 60 enemigos, seis ráfagas simultáneas y efectos reducidos. Medir también una sesión de supervivencia de 20 minutos para detectar crecimiento de memoria.
- Al integrar: `flutter analyze`, tests del módulo y regresiones de menú, recompensas y progress_sync. Emuladores Firebase si se cambian funciones o reglas.

## 11. Riesgos y decisiones iniciales

La mayor incertidumbre es el volumen de arte y el balance combinado de recursos, atún y nodos. Por eso se valida primero un nivel completo y luego el patio. El gesto de dos dedos y la cuadrícula en vertical necesitan una alternativa clara desde el prototipo. Las ráfagas y cadenas se prueban antes de producir todos los enemigos. La economía persistente necesita recuperación de operaciones antes de habilitar compras.

Decisiones de partida: campaña individual offline; cinco mundos como alcance final; patio como primera versión; ilustración propia basada en el tono de la referencia; Flutter con simulación separada; seis tarjetas; sin multijugador ni compras reales en esta propuesta. Las cifras se afinan con pruebas de juego, manteniendo cada nivel resoluble sin consumibles persistentes.
