# Cartas celestiales

Los GIF forman parte de **Momazos Vol. 1 y Momazos Vol. 2**. No hay sobres separados.
Cada apertura tiene una probabilidad independiente de 1% de elegir una celestial
del volumen seleccionado; no significa una carta garantizada cada 100 aperturas.
Las cartas normales mantienen sus identificadores y las rarezas anteriores conservan
sus índices guardados. Las celestiales usan IDs permanentes desde 10000 y rareza 6.

## Agregar GIF

1. Copiar nuevos GIF animados a `C:\Users\renat\Downloads\CARTAS CELESTIALES`.
2. Desde `app`, ejecutar `python tool/import_celestials.py` (requiere Pillow).
   También se puede indicar otra carpeta con `--source "ruta"`.
3. Ejecutar `dart format lib/celestial_cards.dart`, revisar los nombres y comentarios
   de Maru y Lady en `tool/celestial_catalog.json`, y repetir la importación si se editó
   ese catálogo. Los archivos originales se copian sin recodificarlos.
4. Subir los assets, el catálogo y el Dart generado a GitHub junto con una nueva versión
   en `pubspec.yaml`. El workflow existente compila y publica la nueva APK en Releases.

Se reparten nuevas cartas al volumen con menos celestiales, sin cambiar el volumen
ni el ID de cartas anteriores. Repetir la importación no duplica archivos idénticos.
Retirar un GIF de la carpeta de origen no elimina cartas que los jugadores ya poseen.
Para sustituir una animación manteniendo su carta, reemplazar el archivo de origen
conservando su nombre. Usar GIF en bucle continuo para que la animación no termine.
La app necesita una nueva compilación para incorporar nuevos GIF; no lee Downloads
desde el teléfono. La primera importación contiene 27 cartas: 14 en Vol. 1 y 13 en Vol. 2.

## Reproducción y guardado

Flutter utiliza su decodificador multiframe en apertura, colección, inspección e
intercambios. Los GIF mantienen su proporción dentro del marco y sus demoras originales.
Android AR recibe el GIF completo y el rectángulo del arte: usa AnimatedImageDrawable
desde Android 9 y Movie en Android 7/8, con recorte y ajuste proporcional. El reverso,
el nombre y el borde permanecen independientes de la animación. Pausar el giro de
la carta permite seguir viendo el GIF. Una fotografía captura el fotograma visible.

Los inventarios guardan únicamente ID, copias, rareza y acabado en el progreso
existente de Firebase. La función de intercambio reconoce la rareza celestial.
La apertura entrega exactamente una carta: el primer sobre del día local cuesta 20
monedas y los siguientes 50, compartiendo el descuento entre ambos volúmenes. La animación
no concede premios adicionales ni cambia la probabilidad. Una celestial también
reinicia la garantía de legendaria o superior.

## Verificación visual aislada

`flutter build web --release -t tool/celestial_preview.dart --output build/celestial-preview --pwa-strategy none`
genera un visor de prueba con el catálogo descubierto. Servir esa carpeta en un
puerto distinto del de la app, por ejemplo 7361. No se incorpora al menú ni a la APK.
Las pruebas cubren ambas probabilidades, persistencia, decodificación de todos los GIF,
apertura móvil, accesibilidad con movimiento reducido y el contrato de AR.
