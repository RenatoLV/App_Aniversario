# Anivermaru

Estado actualizado (30/09/2026): el backend activo es **Firebase**, no Supabase. Android y web conservan datos locales sin internet y reintentan sincronizar al recuperar conexión con la app abierta o al volver a abrirla. Ver [ESTADO_SISTEMA.md](ESTADO_SISTEMA.md) para el resumen completo de cambios, verificaciones y pendientes; [app/FIREBASE.md](app/FIREBASE.md) para configuración.

Aplicación Flutter de aniversario con juegos, Maru y Lady animados, sobres holográficos y una colección local de memes convertidos en cartas. El mismo proyecto funciona en web y Android.

El repositorio incluye **334 memes** de Momazos vol. 1 y vol. 2 y sus imágenes WebP, además de seis cartas de ejemplo dibujadas con código (340 entradas en el álbum). No hace falta descargar los memes por separado para ejecutar la aplicación.

## Qué incluye

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
  y vestirlos. Cada gato conserva sus cuidados y su ropa; las ocho prendas iniciales
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
