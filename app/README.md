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

Para importar memes desde la raíz: `py app/tool/import_memes.py --source "C:\ruta\a\tus\memes"`. Requiere Pillow. Hay 334 memes en dos volúmenes; el catálogo conserva IDs estables. Añadir imágenes requiere reconstruir la app; no hay todavía un catálogo descargable remoto.

APK de prueba: `build/app/outputs/flutter-apk/app-debug.apk`. No se incluye en Git. La distribución release, iOS y las pruebas físicas de cámara/inclinación permanecen pendientes.
