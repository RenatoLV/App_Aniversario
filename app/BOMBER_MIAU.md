# Bomber Miau

Las arenas nuevas miden 13×15, con entradas libres junto a ambos puntos de inicio.
Hay monedas personales de 5 en esos caminos y cada victoria entrega 150 monedas.
Ganar 5 y 10 partidas desbloquea premios únicos de 500 y 1.500 monedas.
La bomba en línea conserva la casilla al pulsar; una bomba que llega con retraso
permite salir si el cuerpo del gato todavía toca su casilla, sin permitir reingresar.

Inicio incluye Bomber Miau. Hay cuatro arenas con colores y recorridos diferentes:
Jardín de patitas, Azotea lunar, Dulce despensa y Templo del sol. Los bloques tienen
caras, relieve y sombra, mientras la colisión conserva una cuadrícula clara.
Se puede elegir Maru, Lady, Milo o Nube; tienen las mismas estadísticas. Maru y Lady
usan su ropa guardada también en partidas en línea.

La IA funciona sin conexión. Para jugar con otra persona se requiere iniciar sesión
con Google: buscar un rival en la arena elegida o buscar un usuario por nombre y
enviarle una invitación. El destinatario puede aceptar o rechazar desde este menú.
Las invitaciones y la búsqueda duran un minuto. Las partidas duran tres minutos,
con cuenta atrás inicial y diez segundos de margen después de perder conexión.

El control izquierdo sigue el dedo y el botón derecho coloca una bomba; admite
ambos dedos a la vez. En computadora se usan WASD/flechas y espacio. Las bombas
explotan en 2,8 segundos, paran en paredes, rompen la primera caja y provocan cadenas.
Ovillo: alcance; atún: bombas; pez: velocidad; caja: atravesar cajas durante cuatro
segundos; patita: proteger un impacto; tortita: escudo durante cinco segundos.
Los límites son cinco de alcance, tres bombas y 1,5 veces la velocidad inicial.
Al terminar el efecto de caja se permite salir de la caja actual sin teletransportarse.

Firebase RTDB comparte movimiento, arena, bombas y presencia. Las funciones
`bomberMatch`, `bomberBomb` y `bomberContact` controlan emparejamiento, invitaciones,
cuenta atrás, poderes, detonaciones y resultado. Los clientes solo escriben su
movimiento y presencia: no pueden cambiar estadísticas, bombas o resultado.
El servidor procesa también el contacto con fuego que sigue activo después de explotar.

Pruebas: `flutter test test/bomber_test.dart`, `npm test` desde functions y, desde app:
`firebase emulators:exec --project demo-cumplemes --only auth,firestore,database,storage,functions "node tool/firebase_tests/run_all.cjs"`.
La release de GitHub ejecuta estas comprobaciones antes de firmar la APK.
