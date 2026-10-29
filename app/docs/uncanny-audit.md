# Uncanny Cat Golf original: integración Android

## Revisión del cierre en release y presentación horizontal (29/10/2026)

Se descargó y examinó la APK publicada **v1.11.0-build1032** del commit
`fec3ce6`. Sus DEX no conservan las definiciones originales de `Dictionary` y
`GodotRenderView`, aunque la biblioteca
nativa de Godot contiene referencias a esos nombres. Las reglas anteriores
solo conservaban métodos `native`; no protegían clases ni métodos Java llamados
desde C++. **Confirmado con logcat del Xiaomi 14T (2406APNFAG), Android 16**:
el proceso `:uncanny_golf` aborta con SIGABRT durante `GodotLib.initialize` por
`NoSuchMethodError` al buscar `Godot.restart()V` y `Godot.setKeepScreenOn(Z)V`.
La optimización de release rompe así el arranque antes de cargar el juego.

Se protege `org.godotengine.**` contra eliminación y renombrado por R8. La nueva
comprobación `python tool/verify_uncanny_apk.py RUTA_APK` inspecciona las clases
realmente definidas en los DEX después de R8, las referencias del motor nativo,
los métodos de arranque llamados desde JNI, las arquitecturas, la escena
horizontal y el tamaño/hash/compresión del PCK.
Se ejecuta en CI sobre la APK final antes de publicar. La APK 1032 falla esta
comprobación por esas clases y métodos. Las cadenas antiguas `InputManagerCompat`
e `InputManagerV16` también aparecen en el binario nativo, pero esas clases no
existen ni en el AAR original de Maven; se excluyen de la comprobación.

La Activity solicita **sensorLandscape** y la escena móvil reafirma horizontal
en Godot, pues la configuración del PCK anterior todavía solicita vertical.
El nuevo punto de entrada es `res://uncanny/mobile_landscape.tscn`, incluido como
asset Android junto al PCK verificado: permite conservar exactamente el paquete
original descargado. Las futuras exportaciones también incluyen esa escena.
La escena presenta un único cuadro de **768×512 (3:2)**, con su HUD original,
centrado mediante escala uniforme y bandas laterales. Ya no separa el logo, los
indicadores ni la cancha. Los toques y arrastres se transforman a las coordenadas
originales; una captura conserva el arrastre al salir del cuadro. Pausa, reinicio,
Parry y salida siguen siendo botones transparentes a los lados.

Métricas verificadas del artefacto publicado:

| Elemento | Bytes | Observación |
| --- | ---: | --- |
| APK 1032 | 1.020.371.006 | Aproximadamente 973 MiB |
| PCK original | 553.807.328 | Aproximadamente 528 MiB, sin compresión ZIP |
| Godot x86_64 | 76.487.192 | Innecesario en la distribución ARM64 |
| Godot armeabi-v7a | 76.303.400 | Innecesario en la distribución ARM64 |
| Godot arm64-v8a | 69.115.776 | Arquitectura de la distribución |

Se filtran también las bibliotecas JNI transitivas al compilar para ARM64.
Eliminar las otras dos bibliotecas supone unos 153 MB menos antes de considerar
otros cambios de compilación. A 844×390, el cuadro completo mide 585×390; la
cancha original de 512×512 mide 390×390. A 740×360, el cuadro mide 540×360 y la
cancha 360×360. No hay recorte ni estiramiento. Estas son métricas de geometría
y empaquetado; no equivalen a FPS, RAM ni estabilidad medidos en un teléfono.
Con los 2340×1080 indicados para el A55 en horizontal, el cuadro completo mide
1620×1080, la cancha 1080×1080 y quedan dos bandas laterales de 360 píxeles.

Validación de esta corrección:

- Análisis Flutter sin incidencias; prueba del lanzador aprobada.
- APK completa compilada en **release** para ARM64, build local 1033:
  **866.828.729 bytes** (826,7 MiB), frente a 1.020.371.006 bytes de la 1032:
  reducción de **153.542.277 bytes** (15,0 %).
- `verify_uncanny_apk.py` aprobado sobre esa APK: cinco clases JNI, ocho métodos
  de arranque, solo ARM64, escena horizontal idéntica al código y PCK original
  íntegro, con SHA-256 y tamaño verificados.
- App nativa de prueba separada (`cl.nuestrorincon.uncannytest`) compilada con R8,
  misma Activity/escena/recursos/PCK y comprobación de APK aprobada. Evita
  reemplazar la instalación real, porque la clave local no coincide con la firma
  de la release oficial. Instalada tras aceptar el aviso de instalación por USB.
- Arranque y presentación horizontal observados en el Xiaomi 14T. Se recorrieron
  pantallas originales y se alcanzó el tutorial; el usuario confirmó haber
  probado personalmente las partes del juego. No equivale a una auditoría
  exhaustiva de todos los mapas.
- Se observó además un SIGTRAP al crear una segunda Activity con el motor ya
  inicializado. La Activity usa ahora `singleTask`; dos aperturas consecutivas
  por ADB conservaron el mismo proceso (PID 14590), sin crear otro motor.
- En Android 16, Atrás mandaba la tarea al fondo por la navegación predictiva.
  Se registra un `OnBackPressedCallback` para enviar la misma pausa que el botón
  superpuesto. Un regreso al launcher durante la prueba anterior coincidió con
  una pulsación Atrás enviada por el agente; el proceso siguió vivo.
- Muestras observadas del SurfaceView: aproximadamente 60 FPS. Memoria PSS del
  proceso entre unos 878 MiB y 1,3 GiB durante la prueba, con RSS de hasta 1,5 GiB.
  Son muestras puntuales, no un benchmark prolongado ni una medida en el A55.
  El consumo de memoria sigue siendo elevado.

La APK local no actualiza la app publicada debido a la diferencia de firma.
La distribución final debe compilarse con la firma preservada del workflow.

Las verificaciones históricas siguientes corresponden a la adaptación vertical
anterior y a una APK de depuración. No validaban la optimización de release.

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
