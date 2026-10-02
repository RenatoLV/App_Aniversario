# APK y actualizaciones

GitHub Releases distribuye APK Android ARM64 firmadas siempre con la misma clave. La app comprueba la última versión estable al abrir el menú; el botón de actualizaciones permite descargarla. Android solicita confirmar la instalación. No requiere Firebase para descargar actualizaciones.

Para publicar cambios:

1. Aumenta `version` en `app/pubspec.yaml`: por ejemplo `1.1.2+4`. El número después de `+` debe aumentar siempre.
2. Confirma y sube los cambios a `main`.
3. Ejecuta `git tag v1.1.2` y `git push origin v1.1.2`.
4. GitHub Actions prueba y compila el código etiquetado, firma la APK y publica APK, `update.json` y checksum en Releases. También se puede ejecutar **Android release** manualmente indicando una etiqueta existente.

Para activar la compilación en GitHub hay que configurar los secretos `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` y `ANDROID_KEY_PASSWORD` con la clave actual. Este paso está pendiente de autorización para transferir la clave privada a los secretos cifrados de GitHub. Nunca publiques ni reemplaces esa clave: Android solo permite actualizar sobre una APK con la misma firma. Guarda una copia privada de seguridad. En compilaciones locales se utiliza la clave actual de `~/.android/debug.keystore`; CI exige los secretos de firma y nunca genera una clave alternativa.

Esta distribución conserva la firma de la APK 1.1.0 creada en este equipo. Instalaciones antiguas con otra firma requieren migrar por separado. No desinstales una instalación antigua sin respaldar los datos.

Firebase Android (proyecto `cumplemes`) ya tiene los SHA-1 y SHA-256 de esta firma; `google-services.json` se actualizó para el acceso Google. El acceso real debe comprobarse también en el teléfono con una cuenta del usuario.
