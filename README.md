# Anivermaru

Guía técnica completa: [cómo funciona el código, tecnologías, diseño de Maru y Lady e inventario de archivos](GUIA_COMPLETA_DEL_PROYECTO.md).

Lucky Palace y Patita de la Suerte están disponibles desde los minijuegos, con un saldo local compartido de fichas del casino, guardado y recuperación de partidas. Los accesos normales activan los premios locales v2; las partidas antiguas terminan con sus reglas originales. Las fichas están separadas de las monedas y la colección de la app. [Plan y avances](app/LUCKY_PALACE_PLAN.md).

[Auditoría histórica 3.5 y condiciones de la etapa 4](app/LUCKY_PALACE_STAGE4_READINESS.md): comparación de giros de 10/25, fuentes/precios reales y arquitectura transaccional. Sus restricciones sobre economía conectada no impiden jugar con las fichas locales.

Estado actualizado (30/09/2026): el backend activo es **Firebase**, no Supabase. Android y web conservan datos locales sin internet y reintentan sincronizar al recuperar conexión con la app abierta o al volver a abrirla. Ver [ESTADO_SISTEMA.md](ESTADO_SISTEMA.md) para el resumen completo de cambios, verificaciones y pendientes; [app/FIREBASE.md](app/FIREBASE.md) para configuración.

Aplicación Flutter de aniversario con juegos, Maru y Lady animados, sobres holográficos y una colección local de memes convertidos en cartas. El mismo proyecto funciona en web y Android.

El repositorio incluye **334 memes**, **27 cartas celestiales animadas** y seis cartas de ejemplo (367 entradas en el álbum). Las celestiales aparecen en los sobres Momazos vol. 1 y vol. 2 con probabilidad de 1% por apertura. Se reproducen en la apertura, colección y AR Android. Los sobres normales empiezan en 20 monedas y aumentan 5 por apertura hasta un máximo de 70; el contador se reinicia cada día local. El sobre celestial cuesta 5000 monedas. Para añadir GIF: [app/CELESTIAL_CARDS.md](app/CELESTIAL_CARDS.md).

## Qué incluye

- Lucky Palace y los raspes comparten un mostrador **Premios**: 200 monedas (5 partidas / 75 fichas), Amuleto de la suerte (10 / 150), Gafas Estrella de la noche (15 / 220), Traje Royal Maru (20 / 300), Medallón Maruzonita (25 / 420), Corona Lucky Palace (35 / 600), Traje Noche de confeti (40 / 750), 1200 monedas (50 / 900) y Cofre del primer año de 2000 monedas (75 / 1500). Cada giro de pago y cada raspe revelado cuenta, también los anteriores a esta actualización. Cada premio se canjea una sola vez; las seis prendas son exclusivas del casino y se equipan en la casita. El canje conserva un recibo para recuperar una entrega interrumpida sin otro cobro. La interfaz normal oculta símbolos, modos y controles de laboratorio.
- Casino y raspe comparten cuatro canciones locales: Milky (Bomberman Hero), Pipo Pipo (Serani Poji), Garfield explode the internet! (nobonoko) y Ninjin loves you yeah! instrumental. Continúan entre ambos juegos y el mostrador de premios, con los controles existentes de música, volumen y siguiente canción.
- Cada 21 se alternan seis celebraciones al cambiar de menú: globos del primer año, huellitas, globos de gato, corazones, estrellas fugaces y serpentinas. Son finitas, permiten tocar los controles y respetan la preferencia de reducir animaciones.

- Cada día 21, según la fecha local del dispositivo, el inicio recibe con «¡Feliz maruversario!», globos y besitos animados. Maru y Lady tienen una torta de dos pisos con fresas y vela número 1 durante todo el día, en todas sus actividades. La celebración se actualiza a medianoche y al volver a la app; se repite cada mes y respeta la opción de reducir animaciones.

- Marus vs Zombies, desde los juegos del Patio: campaña de seis mundos y 60
  misiones, once gatos defensores, Roombas, atún, poderes humanos, terreno especial,
  Dr. Cat-trófico, desafíos y supervivencia. Guardado local y sincronización del
  progreso. Controles y estado: [app/MARUS_VS_ZOMBIES.md](app/MARUS_VS_ZOMBIES.md).

- Bomber Miau: cuatro arenas con relieve y colores diferentes, Maru, Lady, Milo y
  Nube, seis poderes, IA sin conexión y duelos en línea. Permite buscar usuarios
  e invitarlos, o encontrar un rival en la arena. Firebase controla bombas,
  poderes y resultados; la ropa de Maru y Lady se conserva. Controles táctiles
  simultáneos y teclado. Detalles: [app/BOMBER_MIAU.md](app/BOMBER_MIAU.md).

- Ascenso Maruzon: saltos verticales infinitos con selección de mascota,
  nubes, rocas, plataformas móviles, tormentas, monedas y cohetes. El cielo
  cambia al espacio al ascender; Lady deja una estela arcoíris. Controles táctiles
  y de teclado, pausa, captura con vista previa y récord local.
  Funcionamiento: [app/GALACTIC_LEAP.md](app/GALACTIC_LEAP.md).

- Candy Churu Cat: combina premios en un tablero 9×9, crea especiales,
  encadena cascadas y limpia gelatinas junto a Maru y Lady. Incluye niveles
  progresivos, glaseado, chocolate, lazos, huecos, potenciadores y guardado local.
  Arquitectura y reglas: [app/MATCH3.md](app/MATCH3.md).

- Wordlady: Wordle de cinco letras con vocabulario español y chileno,
  100 monedas por victoria y dos pistas al día por dispositivo (fecha local).
  Las respuestas se eligen de una lista de palabras cotidianas y chilenismos
  conocidos; el diccionario amplio se usa solamente para validar los intentos.
  La partida, las victorias y las pistas se conservan localmente.
  Los diccionarios Hunspell incluidos provienen de
  https://github.com/wooorm/dictionaries (es y es-CL, proyecto RLA-ES de Santiago Bosio).
  Se utilizan sus entradas de cinco letras, sin expandir los afijos de Hunspell.
  Se distribuyen bajo MPL 1.1 o posterior; la licencia y los créditos originales
  están en `app/assets/wordle_dictionary_license.txt`.

- Escena interactiva de Maru y Lady: caricias, movimiento, siestas, pensamientos, churu y caja de arena.
- La casita: doble toque en el recuadro de los gatos para darles comida, bañarlos
  y vestirlos. Cocina, baño y probador decorados, refri con apertura animada y
  dormitorios independientes con camas, alfombras, lámparas y pósteres de tus
  cartas. Cada gato conserva sus cuidados, decoración y ropa; las 40 prendas iniciales
  se combinan por categoría y aparecen también en juegos, sobres y animaciones.
  Detalles y personalización: [app/CAT_CARE.md](app/CAT_CARE.md).
- Block Blaster Maru Editions: juego de bloques 8×8 con puntuación, combos, récord, monedas y SFX Android.
- Sobres con animación de apertura, rarezas y carta holográfica inclinable.
- Colección con 334 memes y seis cartas de ejemplo; variantes foil, filtros, álbum por volumen y visor con giro/zoom.
  Momazos vol. 1 y vol. 2 se abren como libros de dos páginas: desliza, usa las
  flechas o el selector de páginas. El filtro «Mis cartas» muestra las descubiertas.
  Maru y Lady juegan con las cartas de la página visible; las pendientes permanecen ocultas.
- Bloc de notas local y compartido con fotos y dibujos editables.
- Persistencia local del tablero, monedas, colección y notas.
- Firebase: Google/nombre de usuario, progreso por cuenta, rankings globales, notas compartidas, Storage y presencia.
- Cámara 3D: carta visible sin detección de superficies, giro 360°, brillos y foto para Nuestro bloc o descarte.
- Inclinación Android y cruce de extremos en Ascenso; gesto vertical fuerte desde arriba para cambiar menú.

## Requisitos

- [Flutter](https://docs.flutter.dev/get-started/install) estable, disponible en `PATH`.
- Chrome o Edge para ejecutar la versión web.
- Android Studio y un SDK de Android para compilar o ejecutar en un teléfono/emulador.
- Python 3 y Pillow solamente si se quieren importar memes nuevos.

Comprueba la instalación:

```powershell
flutter doctor
```

## Instalación

```powershell
git clone https://github.com/RenatoLV/App_Aniversario.git
cd App_Aniversario\app
flutter pub get
```

La aplicación funciona sin internet. Los cambios se guardan localmente; con una cuenta Google se sincronizan después con Firebase.

### Ejecutar en web

Desde la carpeta `app`:

```powershell
flutter run -d chrome
```

También se puede levantar un servidor web local:

```powershell
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 7357
```

### Ejecutar o compilar para Android

Con un teléfono con depuración USB o un emulador disponible:

```powershell
flutter devices
flutter run
```

Para generar una APK de prueba:

```powershell
flutter build apk --debug
```

El archivo queda en `app/build/app/outputs/flutter-apk/app-debug.apk`.

## Configuración histórica de Supabase (no usada por la app actual)

La configuración activa está en [app/FIREBASE.md](app/FIREBASE.md). Lo siguiente describe el prototipo anterior, conservado como referencia; no se necesita para ejecutar Anivermaru.

Copia `app/config.example.json` como `app/config.local.json` y reemplaza los valores de ejemplo:

```json
{
  "SUPABASE_URL": "https://TU_PROYECTO.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_REEMPLAZAR"
}
```

Después inicia Flutter así:

```powershell
flutter run -d chrome --dart-define-from-file=config.local.json
```

Las migraciones están en `supabase/migrations/`. Los códigos de activación, archivos de despliegue local y configuraciones reales están ignorados por Git. No publiques claves privadas, JWT, contraseñas ni la clave `service_role`.

## Memes y cartas

Las 334 imágenes listas para usar están en `app/assets/memes/`. El orden estable de las cartas se guarda en `app/tool/meme_catalog.json` y el código generado en `app/lib/meme_cards.dart`.

Para añadir imágenes nuevas:

1. Copia archivos JPG, JPEG, PNG o WebP a una carpeta. También se reconocen imágenes válidas sin extensión.
2. Instala Pillow una sola vez:

   ```powershell
   py -m pip install Pillow
   ```

3. Desde la raíz del repositorio ejecuta:

   ```powershell
   py app/tool/import_memes.py --source "C:\ruta\a\tus\memes"
   ```

4. Revisa `app/tool/meme_contact_sheet.jpg` y vuelve a ejecutar o compilar Flutter.

El importador convierte las imágenes a WebP, evita nombres duplicados y añade las cartas al final del catálogo. Nunca reordena los IDs existentes, por lo que una colección guardada sigue apuntando a las mismas cartas. El nombre del archivo se usa como nombre de la carta.

## Validación

### Uncanny Cat Golf

Integración Android del juego original con Godot 4.4.1, sus assets y mapas completos y controles táctiles en vertical. Juego original de **SH2K (SlappyHappy2000) y The Canny Crew**: [Uncanny Cat Golf en itch.io](https://slappyhappy2000.itch.io/uncanny-cat-golf). Créditos completos y diferencias frente al proyecto original en [la auditoría](app/docs/uncanny-audit.md); [notas de la versión 1.11.0](app/docs/release-1.11.0.md).

Desde `app`:

```powershell
flutter analyze
flutter test
```

## Estructura

- `app/`: aplicación Flutter, assets y herramientas de importación.
- `supabase/migrations/`: esquema SQL y políticas RLS.
- `integrations/drive/`: prototipo opcional de integración privada con Google Drive.
- `memes/por_agregar/`: instrucciones para preparar futuros lotes de imágenes.

## Datos y seguridad

Firebase protege datos por UID y membresía del mural; los rankings son comunes a usuarios autenticados. Monedas, cartas, partidas y notas tienen guardado local y sincronización posterior. Los conflictos entre dispositivos conservan ambas versiones para elegir. Antes de distribuir: firma release estable, validación física de cámara/inclinación, App Check y validación de puntuaciones/recompensas en servidor. No subir credenciales privadas ni claves de firma. Supabase/Drive son material histórico, no backend activo.
