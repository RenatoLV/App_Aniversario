# Uncanny Cat Golf original: integración Android

La versión final ejecuta el proyecto original en **Godot 4.4.1**, la misma versión que declara el EXE entregado. Se retiró la recreación 2D en Flutter; una copia local de ese prototipo se conserva fuera de Git en `.tools/uncanny-flutter-prototype`.

## Contenido comprobado

Fuente: `C:\Users\renat\Downloads\ucanny\UNCANNY DECOMP`, versión 1.0.3b. El PCK Android exportado tiene **4.825 entradas, los 319 scripts y las 372 escenas originales con sus remapeos**, además de la presentación móvil. El inventario de origen incluye 95 escenas regulares con nombres numéricos (5 en W0 y 18 por cada mundo W1–W5), además de otras escenas especiales. Se exporta todo el proyecto, incluidos W5, los demás mapas y modos, editor, minijuegos y recursos originales; no se limita a los 16 mapas del prototipo.

Se verificaron **1.890 archivos de imágenes, audio, modelos y escenas idénticos byte por byte** frente al origen. Sus hashes están en `uncanny-preserved-assets.json`. `uncanny-source-inventory.csv` lista los scripts y niveles regulares cotejados. La presencia en el paquete no afirma que cada minijuego o cada herramienta del editor haya sido probado manualmente en un teléfono.

## Cambios de integración

- El original sigue dibujando sus propios modelos, mapas, interfaces y efectos; Flutter solo abre la pantalla Android.
- Activity separada en proceso `:uncanny_golf`, bloqueada en vertical. Vista de Godot a pantalla completa, sin cabecera ni panel externo, con botones transparentes superpuestos.
- Toque directo sobre los menús y arrastre sobre la cancha, más pausa, reinicio y Parry mediante las entradas originales.
- La escena original se renderiza a sus 768×512 coordenadas dentro de un SubViewport. La cancha de 512×512 ocupa todo el ancho del teléfono; los indicadores originales se distribuyen arriba y abajo. Los mapas mantienen sus proporciones y se ven completos. Un fondo del original cubre el resto de la pantalla.
- La transformación inversa de los toques conserva la sensibilidad original, incluso si el arrastre sale del área de la cancha. Los botones Area2D comprueban el toque sin exigir un hover previo de mouse.
- El botón de regreso guarda la partida y termina el proceso dedicado de Godot para permitir abrirlo de nuevo sin duplicar sus instancias internas.
- Directorio de guardado propio para no tocar las partidas de Windows; emulación de mouse desde el toque.
- Carga secuencial de escenas en móvil para evitar bloqueos del grupo de hilos al resolver dependencias compartidas.
- Una protección contra una referencia nula durante la exportación de `@tool` en `bingball/objects/standup.gd`; no modifica su sonido ni su modelo.
- La versión web informa que esta integración requiere Android; no sustituye el original por una recreación.

## Compilación reproducible

Ejecutar desde la raíz:

```powershell
python app/tool/prepare_uncanny_original.py --source "C:\Users\renat\Downloads\ucanny\UNCANNY DECOMP" --godot "RUTA\Godot_v4.4.1-stable_win64_console.exe"
```

La herramienta copia el proyecto a un directorio de trabajo, importa con Godot 4.4.1, exporta el PCK Android y verifica los archivos originales. No modifica la carpeta proporcionada. El gran archivo PCK se distribuye como asset de GitHub Releases, no como blob de Git. `app/tool/uncanny_pack.json` fija tamaño y SHA-256; `fetch_uncanny_pack.py` los valida antes de usar el paquete en la compilación Android.

La presentación móvil y el mapeo de entradas están comentados en `app/tool/uncanny_mobile`. La exportación falla ante errores de GDScript aunque Godot devuelva código de salida cero. La Activity vuelve a ocultar las barras de Android al recuperar el foco; se pueden mostrar temporalmente con el gesto del sistema.

## Validación

- `flutter analyze --no-pub`: sin incidencias.
- Suite Flutter: 502 pruebas aprobadas, 15 omitidas por sus condiciones originales. Prueba del lanzador: aprobada a 320×568, 390×844 y 740×360, incluida la presentación de errores nativos.
- APK de depuración compilada e instalada en Android 15, emulador x86_64 con GPU host. Se recorrieron los menús originales, se creó y guardó una partida y se abrió el tutorial 0-1.
- Toque y arrastre: movimiento del jugador y contador de golpes comprobados. Botones superpuestos de pausa/reanudar y reinicio comprobados. Salida y nueva apertura comprobadas sin reutilizar las instancias del motor.
- No se afirma una prueba exhaustiva de los 95 mapas, minijuegos o editor, ni una prueba en un teléfono físico. Parry conserva la condición de desbloqueo del modificador original.

## Créditos

**Uncanny Cat Golf**: **SH2K (SlappyHappy2000)** y **The Canny Crew**, con **Haze Weathers, mbx8rt, Penny Rigate, greenhead352 y bibizu**, según su página oficial:

https://slappyhappy2000.itch.io/uncanny-cat-golf

Integración móvil no oficial en Anivermaru. Se conservan los créditos dentro del juego. La atribución no declara una licencia sobre el original; no se encontró un archivo de licencia en la carpeta suministrada. Godot mantiene su propia licencia MIT.
