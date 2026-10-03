# La casita de Maru y Lady

Toca dos veces la casita de Inicio para entrar. También funciona sobre un gato.
El selector superior cambia entre Maru y Lady; cada uno tiene sus propios cuidados
y su conjunto de ropa.

- **Comida:** abre el refri y elige entre diez alimentos, o arrastra uno al gato.
  Cada alimento tiene dibujos, movimientos y efectos propios antes de recuperar
  comida y cariño: croquetas, pescado, churú, atún, salmón, pollo, camarón, huevo,
  calabaza y caldo.
- **Baño:** selecciona o arrastra el jabón y frota al gato hasta hacer espuma.
  Cambia a la regadera para enjuagarlo. El agua borra progresivamente las manchas
  de lodo; la limpieza se recupera cuando terminas el enjuague. También puedes
  tocar al gato para aplicar la herramienta elegida.
- **Ropa:** combina collar/pañuelo, gorro, lentes y polera. Toca otra vez una prenda
  equipada para quitarla, o pulsa «Sin ropa ni accesorios».
- Las caricias en la casita y en el menú de cuidados recuperan cariño.

El armario inicial es gratuito: diez collares y pañuelos, diez gorros, diez lentes
y diez poleras. Las 40 prendas tienen formas y detalles distintos y conservan los
identificadores de las ocho prendas originales para mantener el guardado.
Los cuidados bajan suavemente con el tiempo, con un límite al estar fuera de la app.
No modifican la dificultad de los juegos ni eliminan las mascotas.

## Guardado y dibujos compartidos

`GameStore.catCare` guarda necesidades, fecha y ropa en `rincon.v1`. El respaldo
existente de Firebase incluye esos datos. Las partidas antiguas sin ese campo
conservan sus monedas y colección y reciben los valores iniciales de cuidados.

`CatCareScope` distribuye la ropa a todos los `CatActor`. Ascenso Maruzon pasa el
conjunto al dibujante del jugador, su transformación alien y la selección de gato.
La apertura de sobres utiliza el mismo vestuario. La suciedad aparece gradualmente
en todos esos dibujos al bajar la limpieza. Los accesorios siguen las
transformaciones de cabeza y cuerpo; no son imágenes flotantes sobre el personaje.

Para personalizar las prendas, edita el catálogo `lib/cat_care.dart` y los trazados
de `lib/cat_clothing.dart` (anatomía de 100 × 100). Conserva sus identificadores para
mantener las elecciones guardadas. Las ranuras válidas son cuello, cabeza, ojos y
cuerpo; añadir ropa a una ranura incompatible se ignora al cargar los datos.

## Verificación

`test/cat_care_test.dart` comprueba guardado, migración, respaldo y separación entre
gatos. `test/cat_care_screen_test.dart` prueba doble toque, botones, arrastre de comida,
baño con el dedo y una pantalla de 320 píxeles. `test/cat_clothing_test.dart` verifica
las 40 prendas en los dibujos normales, alien y sobres, y la actualización de ropa
sin recrear los actores animados. `test/cat_care_art_test.dart` comprueba las diez
comidas, sus animaciones distintas y la suciedad gradual. Los dibujos de alimentos,
refri y herramientas de baño están en `lib/cat_care_art.dart`.
