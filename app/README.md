# Anivermaru — app Flutter

Ver [README principal](../README.md), [estado del sistema](../ESTADO_SISTEMA.md), [Firebase](FIREBASE.md) y [cámara 3D](AR_CARTAS.md).

Backend activo: Firebase. Android/web guardan localmente partidas, récords, cartas y notas; la sincronización se reintenta cuando hay conexión con la app abierta o al volver a ella. Supabase y Drive son material histórico, no requisitos de ejecución.

Desde esta carpeta, con Flutter en PATH:

```powershell
flutter pub get
flutter analyze
flutter test --concurrency=1
flutter build apk --debug
```

Para importar memes desde la raíz: `py app/tool/import_memes.py --source "C:\ruta\a\tus\memes"`. Requiere Pillow. Hay 377 memes en dos volúmenes; el catálogo conserva IDs estables. Añadir imágenes requiere reconstruir la app; no hay todavía un catálogo descargable remoto.

APK de prueba: `build/app/outputs/flutter-apk/app-debug.apk`. No se incluye en Git.
Los cambios en `main` generan una APK firmada en GitHub Releases. iOS y las pruebas
físicas de cámara/inclinación permanecen pendientes.

La optimización de recursos reduce 8.42 MB con animaciones verificadas sin pérdida,
sin retirar cartas, audio ni fuentes. Las miniaturas se decodifican al tamaño
físico mostrado y el visor mantiene resolución original. Ascenso actualiza la
física y el dibujo en cada frame, con menos reconstrucciones del HUD; Bomber
suelta el control táctil al cambiar de aplicación. Ver [La casita](CAT_CARE.md)
y [cartas celestiales](CELESTIAL_CARDS.md).

Los sobres cuestan 20 monedas al empezar el día y suben 5 con cada apertura exitosa hasta 70. La progresión se comparte entre Vol. 1 y Vol. 2 y se guarda con el progreso.
