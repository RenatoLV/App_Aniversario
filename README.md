# Maruversario

Aplicación Flutter de aniversario con juegos, Maru y Lady animados, sobres holográficos y una colección local de memes convertidos en cartas. El mismo proyecto funciona en web y Android.

El repositorio incluye **244 memes** y sus imágenes WebP, además de seis cartas de ejemplo dibujadas con código (250 entradas en el álbum). No hace falta descargar los memes por separado para ejecutar la aplicación.

## Qué incluye

- Maru & Lady: Galactic Leap: saltos verticales infinitos con selección de mascota,
  nubes, rocas, plataformas móviles, tormentas, monedas y cohetes. El cielo
  cambia al espacio al ascender; Lady deja una estela arcoíris. Controles táctiles
  y de teclado, pausa, captura con vista previa y récord local.
  Funcionamiento: [app/GALACTIC_LEAP.md](app/GALACTIC_LEAP.md).

- Dulces & bigotes: combina premios en un tablero 9×9, crea especiales,
  encadena cascadas y limpia gelatinas junto a Maru y Lady. Incluye niveles
  progresivos, glaseado, chocolate, lazos, huecos, potenciadores y guardado local.
  Arquitectura y reglas: [app/MATCH3.md](app/MATCH3.md).

- Palabras & bigotes: Wordle de cinco letras con vocabulario español y chileno,
  100 monedas por victoria y dos pistas al día por dispositivo (fecha local).
  La partida, las victorias y las pistas se conservan localmente.
  Los diccionarios Hunspell incluidos provienen de
  https://github.com/wooorm/dictionaries (es y es-CL, proyecto RLA-ES de Santiago Bosio).
  Se utilizan sus entradas de cinco letras, sin expandir los afijos de Hunspell.
  Se distribuyen bajo MPL 1.1 o posterior; la licencia y los créditos originales
  están en `app/assets/wordle_dictionary_license.txt`.

- Escena interactiva de Maru y Lady: caricias, movimiento, siestas, pensamientos, churu y caja de arena.
- Juego de bloques 8×8 con puntuación, combos, récord y monedas.
- Sobres con animación de apertura, rarezas y carta holográfica inclinable.
- Colección con 244 memes y seis cartas de ejemplo; conserva copias repetidas y la mejor rareza obtenida.
- Bloc de notas local.
- Persistencia local del tablero, monedas, colección y notas.
- Integración opcional con Supabase para el espacio privado, récords y notas compartidas.

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

La aplicación funciona sin Supabase: en ese caso los datos se guardan solamente en el dispositivo.

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

## Configuración opcional de Supabase

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

Las 244 imágenes listas para usar están en `app/assets/memes/`. El orden estable de las cartas se guarda en `app/tool/meme_catalog.json` y el código generado en `app/lib/meme_cards.dart`.

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

Las monedas, sobres y cartas son locales. Supabase es opcional y usa RLS para proteger el espacio compartido. Una sesión anónima no se recupera automáticamente si se borran los datos de la aplicación o se cambia de dispositivo. Antes de distribuir una APK definitiva, utiliza una firma de publicación estable.
