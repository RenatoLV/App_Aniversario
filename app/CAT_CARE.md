# La casita de Maru y Lady

Toca dos veces la casita de Inicio para entrar. También funciona sobre un gato.
El selector superior cambia entre Maru y Lady; cada uno tiene sus propios cuidados
y su conjunto de ropa.

- **Comida:** elige croquetas, pescadito o churú y pulsa el botón, o arrastra la
  comida hasta el gato. Se reproduce la animación antes de recuperar comida y cariño.
- **Baño:** frota sobre el gato para hacer espuma o pulsa «Dar un baño».
  Las burbujas y el enjuague recuperan la limpieza.
- **Ropa:** combina collar/pañuelo, gorro, lentes y polera. Toca otra vez una prenda
  equipada para quitarla, o pulsa «Sin ropa ni accesorios».
- Las caricias en la casita y en el menú de cuidados recuperan cariño.

El armario inicial es gratuito: collar corazón, collar cascabel, pañuelo rojo,
gorro de lana, gorro explorador, lentes redondos, polera marinera y polera estrella.
Los cuidados bajan suavemente con el tiempo, con un límite al estar fuera de la app.
No modifican la dificultad de los juegos ni eliminan las mascotas.

## Guardado y dibujos compartidos

`GameStore.catCare` guarda necesidades, fecha y ropa en `rincon.v1`. El respaldo
existente de Firebase incluye esos datos. Las partidas antiguas sin ese campo
conservan sus monedas y colección y reciben los valores iniciales de cuidados.

`CatCareScope` distribuye la ropa a todos los `CatActor`. Ascenso Maruzon pasa el
conjunto al dibujante del jugador, su transformación alien y la selección de gato.
La apertura de sobres utiliza el mismo vestuario. Los accesorios siguen las
transformaciones de cabeza y cuerpo; no son imágenes flotantes sobre el personaje.

Para personalizar las prendas, edita el catálogo `lib/cat_care.dart` y los trazados
de `lib/cat_clothing.dart` (anatomía de 100 × 100). Conserva sus identificadores para
mantener las elecciones guardadas. Las ranuras válidas son cuello, cabeza, ojos y
cuerpo; añadir ropa a una ranura incompatible se ignora al cargar los datos.

## Verificación

`test/cat_care_test.dart` comprueba guardado, migración, respaldo y separación entre
gatos. `test/cat_care_screen_test.dart` prueba doble toque, botones, arrastre de comida,
baño con el dedo y una pantalla de 320 píxeles. `test/cat_clothing_test.dart` verifica
las ocho prendas en los dibujos normales, alien y sobres, y la actualización de ropa
sin recrear los actores animados.
