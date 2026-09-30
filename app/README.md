# Maruversario — app Flutter

Ver ../README.md para el alcance, ejecución y estado de Supabase/Drive.

Interfaz actual: tablero arcade violeta con bloques facetados, arrastre y proyección de encaje, chispas, zarandeo y combo; sobres holo con una secuencia protagonizada por Maru o Lady y carta revelada inclinable; colección de 244 memes. Incluye Wordle, Dulces & bigotes y Galactic Leap. En el menú principal Maru y Lady interactúan, comen churu y comida, usan su caja de arena, muestran pensamientos, duermen y despiertan solos.

Revisión visual y mejoras pendientes: [REVISION_UX.md](REVISION_UX.md).

La configuración local de Supabase está en config.local.json (no se sube a Git). Ejecuta desde app/: ..\\.tools\\flutter\\bin\\flutter.bat run --dart-define-from-file=config.local.json

## Añadir memes

1. Copia JPG, JPEG, PNG o WebP a una carpeta. También se admiten imágenes válidas sin extensión. El nombre del archivo, sin extensión, será el nombre de la carta.
2. Desde la raíz del proyecto ejecuta `py app/tool/import_memes.py --source "C:\ruta\a\tus\memes"`. Necesita Pillow (`py -m pip install Pillow` si falta).
3. El importador convierte solo las imágenes nuevas a WebP y las añade al final de `app/tool/meme_catalog.json`. Nunca reordena IDs anteriores; las colecciones guardadas siguen apuntando a las mismas cartas. Revisa `app/tool/meme_contact_sheet.jpg` para comprobar bordes y proporciones.
4. Vuelve a compilar o actualizar la app para incluir esos archivos nuevos. Más adelante el catálogo remoto de Supabase y Drive permitirá añadir contenido sin reconstruir la APK.

## Supabase

La app prepara inicio anónimo sin correo. Cada dispositivo necesita una activación única con un código privado; después Supabase conserva la sesión. `supabase/migrations/001_private_space.sql` y `002_anonymous_activation.sql` crean el espacio privado, récords y notas con RLS. `supabase/generate_activation.py` generó dos códigos locales ignorados por Git y `seed.local.sql` con solo sus hashes. El propietario ejecutó `supabase/deploy.local.sql` con resultado «Success» y Anonymous Sign-Ins está habilitado. La API confirmó que una sesión anónima sin código no ve miembros, notas ni récords; no puede consultar códigos, usar uno falso ni enviar puntuaciones. Falta probar dos sesiones activadas en dispositivos reales. No compartas los códigos ni los incluyas en la APK.
