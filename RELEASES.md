# APK y actualizaciones

GitHub Releases distribuye APK Android ARM64 firmadas siempre con la misma clave. La app comprueba la última versión estable al abrir el menú; el botón de actualizaciones permite descargarla. Android solicita confirmar la instalación. No requiere Firebase para descargar actualizaciones.

Para publicar cambios:

1. Confirma y sube cambios de `app/` a `main`. Puedes cambiar el nombre de versión en `app/pubspec.yaml`, por ejemplo `1.1.2+4`.
2. GitHub Actions asigna un número de compilación creciente (1000 + número de ejecución), prueba y compila el commit, firma la APK y publica APK, `update.json` y checksum en Releases. La etiqueta se crea automáticamente, por ejemplo `v1.1.2-build1004`.
3. También se puede ejecutar **Android release** manualmente desde Actions. Cada ejecución nueva genera una versión instalable más reciente; repetir una misma ejecución mantiene su número.

No reinicies el contador de este workflow ni publiques después una APK local con un número inferior al último publicado. Para compilación local posterior usa `--build-number` con un número mayor y pasa ese mismo valor mediante `ANDROID_BUILD_NUMBER` a `prepare_release.cjs`.

Los secretos `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` y `ANDROID_KEY_PASSWORD` ya están configurados con la clave actual, con autorización expresa del propietario. Nunca publiques ni reemplaces esa clave: Android solo permite actualizar sobre una APK con la misma firma. Guarda una copia privada de seguridad. En compilaciones locales se utiliza la clave actual de `~/.android/debug.keystore`; CI exige los secretos de firma y nunca genera una clave alternativa.

Esta distribución conserva la firma de la APK 1.1.0 creada en este equipo. Instalaciones antiguas con otra firma requieren migrar por separado. No desinstales una instalación antigua sin respaldar los datos.

Firebase Android (proyecto `cumplemes`) ya tiene los SHA-1 y SHA-256 de esta firma; `google-services.json` se actualizó para el acceso Google. El acceso real debe comprobarse también en el teléfono con una cuenta del usuario.
