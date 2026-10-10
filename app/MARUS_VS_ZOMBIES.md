# Marus vs Zombies

Acceso: **Casita → Patio → A jugar en el pasto → Marus vs Zombies**, junto al fútbol.
El módulo funciona sin conexión en Flutter para Android y web.

## Contenido implementado

- Campaña de 60 misiones, diez por mundo: Patio, Cementerio nocturno, Egipto, Piratas, Oeste y Futuro.
- Tablero 5×9 y cinco Roombas externas, una defensa de emergencia por carril.
- Once gatos, selección de hasta seis tarjetas, costes y recargas independientes.
- Hierba del cielo y de girasoles, recogida manual o automática, pala y atún.
- Armaduras, hielo, minas, explosiones, croquetas, peces de ida y vuelta,
  resortes, rayos y láser continuo; poderes de atún y nodos compartidos del futuro.
- Enemigos comunes y temáticos, loro con secuestro/rescate, minero anunciado,
  pianista que cambia carriles, cañón y escudo. Dr. Cat-trófico tiene tres fases,
  refuerzos finitos y golpes de casilla anunciados.
- Tumbas destructibles, agua, tablones que se rompen con aviso y carritos móviles.
- Mano del Humano: pellizco, puntero que atrae y empuja, y spray. Gran León Mítico.
- Estrellas, desbloqueos, almanaque, desafío diario con equipo prestado,
  supervivencia, récord y premios por hitos.
- Ilustraciones vectoriales originales animadas y música original reproducible
  con `python tool/create_marus_music.py`. Controles de audio del proyecto.

## Controles

Toca una tarjeta y una casilla. En teléfonos verticales aparece una confirmación
de fila y columna para evitar colocaciones accidentales. Recoge las burbujas
amarillas y las latas verdes tocándolas. La pala retira sin reembolso.

Atún: selecciona su botón y luego un gato. Una lata activa también los gatos
del mismo símbolo cuando se usa en un nodo del futuro. Los Gatitos Bomba no
admiten atún. Puntero y spray funcionan tocando un área; no exigen dos dedos.
Carritos: selecciona su herramienta, toca un carrito y luego otra posición libre
de la vía. La fila de destino no debe tener un gato ni otro carrito.

Teclado: 1–6 selecciona tarjetas, flechas mueven el foco, Enter ejecuta y Escape
cancela selección o pausa. Clic derecho cancela. Las tarjetas 3:4 están en el
panel lateral en horizontal y superior en vertical, ambos deslizables: se pueden
arrastrar con un fantasma y una casilla
imantada antes de soltar. SafeArea reserva al menos 44 puntos por lado; los
botones de sistema miden 48×48 y las herramientas inferiores tienen 64 de alto.
La hierba vuela hacia su contador y las colocaciones/trampas dan respuesta háptica.
El botón x2 acelera únicamente la simulación, sin alterar daño por impacto.

## Progreso y economía

La clave `marusZombies.v1` guarda campaña, estrellas, inventario, ajustes y partida
suspendida en SharedPreferences. Está incluida en ProgressSync y en el aislamiento
por cuenta existente. Se guarda cada diez segundos de juego, al pausar, al comprar,
al terminar y al volver al mapa. Las partidas retomadas empiezan pausadas.

Galletitas y mentitas son monedas propias del módulo. Una primera victoria entrega
100 galletitas y cada estrella adicional nueva entrega 25. Los jefes entregan diez
mentitas. Los retos nuevos dan cinco; cada hito nuevo de cinco oleadas de supervivencia
también da cinco. El León cuesta 100 mentitas y requiere completar Piratas.

Los costes de Mano del Humano son 50/75/100 galletitas. Comprar una lata cuesta 75,
una vez por partida. El desafío diario desactiva esos consumos y el ancestral.
El mundo completado entrega 150/200/250/300/350 monedas de Anivermaru una sola vez,
mediante GameStore y un reclamo pendiente recuperable si se interrumpe el guardado.

El inventario y el resultado de un consumo se escriben juntos; las escrituras se
serializan. Los premios dependen de estrellas y reclamos persistidos para que un
doble resultado no los duplique. Una partida incompatible devuelve sus gastos
registrados una sola vez. Reemplazar voluntariamente una partida no devuelve gastos.
El menú del módulo bloquea restauraciones remotas durante su uso para evitar que
una sincronización sustituya una partida activa; conserva el mecanismo de conflictos
por revisión de la app. No hay clasificación competitiva del módulo.

## Implementación y verificación

`lib/marus_zombies/` contiene catálogo, niveles, modelos, simulación Dart, guardado,
arte y pantallas. Las oleadas se generan de forma determinista, con aperturas,
introducción gradual de enemigos temáticos, grandes oleadas y finales finitos.
El motor avanza a pasos fijos de 1/60 s y aplica daño antes de comprobar invasión.
El dibujo y las partículas no modifican combate. Los sprites son dibujos vectoriales
propios, no imágenes finales derivadas de la referencia adjunta.

Comprobaciones:

```powershell
C:/src/flutter/bin/flutter.bat analyze --no-pub
C:/src/flutter/bin/flutter.bat test --no-pub test/marus_zombies test/patio_screen_test.dart test/progress_sync_test.dart test/game_rewards_test.dart test/menu_swipe_test.dart
C:/src/flutter/bin/flutter.bat test --no-pub test/marus_zombies/screen_test.dart --dart-define=RENDER_MZ=true
```

La prueba de campaña recorre las 50 misiones con recogida automática y una estrategia
determinista sin poderes de pago; usa minas contra los mineros del Oeste. Es una
comprobación de resolubilidad, no sustituye probar dificultad y diversión con personas.
Las pruebas de pantalla cubren 320×568, 390×844, 844×390 y 1280×800, colocación,
pausa, navegación desde Patio y continuidad del guardado. Las capturas opcionales
quedan en `build/previews/mz-*.png`. Hay pruebas de ráfagas simultáneas con 60 enemigos,
colisiones, regreso del bumerán, terreno, poderes, pausa, snapshots y premios.

Pendiente de validación en hardware: objetivo de 60 FPS en un Android de referencia,
sesión larga de supervivencia y ajuste editorial del balance. La sincronización usa
el mecanismo existente; sus pruebas aquí verifican inclusión en el respaldo local,
sin afirmar una sesión real con Firebase en dos dispositivos.

El acabado del HUD, las cartas, las herramientas con relieve y los ejemplos Dart/Flame se documentan en [MARUS_VS_ZOMBIES_UI.md](MARUS_VS_ZOMBIES_UI.md).
