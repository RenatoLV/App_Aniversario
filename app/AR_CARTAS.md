# Cartas — cámara 3D

En Colección, abre una carta y pulsa **AR · Cámara 3D**. El modo actual usa Camera2 nativo en Android y una carta superpuesta, visible inmediatamente sin buscar superficies ni exigir buena iluminación. Reemplaza el ARCore anterior. Conserva frente y reverso del visor, volumen, rareza y acabado.

1. Acepta el aviso de cámara y concede el permiso de Android.
2. La carta aparece sin instalar ARCore ni Google Play Services para AR.
3. Arrastra para girar 360° e inclinar; la carta tiene frente, reverso y brillos animados.
4. Usa modo mover/centrar para cambiar su posición, y giro automático/pausa para revisar el diseño.
5. Pellizca para agrandar o achicar. También hay botones + y −, respetando las barras del sistema Android.
6. Pulsa **Foto**. La captura incluye la cámara y la carta, sin botones.
7. Revisa la foto: **Guardar en Nuestro bloc** crea una nota con la foto en el mural de la app; **Descartar** no crea ni sincroniza nada.

## Privacidad y almacenamiento

No usa Cloud Anchors ni envía imágenes de cámara a Firebase durante la sesión. Solo al guardar se incorpora la captura al flujo local/offline y Storage de las notas. Si hay un espacio conectado, sus miembros pueden ver la nota. No requiere instalación ni seguimiento de ARCore.

Los archivos de intercambio nativo se crean en la caché privada de la app y se eliminan al volver al visor. La captura se limita a 1200 píxeles en su lado mayor para no superar el límite de adjuntos del mural. No requiere permisos de galería ni escribe en la galería.

## Alcance y comprobación pendiente

- Android con cámara compatible con Camera2; ya no se requiere compatibilidad ARCore.
- Web/iOS muestran un aviso de que este modo aún no está disponible.
- No hay anclaje físico, detección de superficies ni oclusión por objetos reales. Se usan texturas de ambas caras con giro y brillos.
- Cámara, controles, orientación y captura necesitan validación física; una compilación o prueba de widgets no demuestra compatibilidad con cada teléfono.

Prueba manual: conceder/denegar cámara; giro 360° y reverso; pellizcar, mover y centrar; luces bajas; controles con navegación por gestos/tres botones; capturar, descartar y comprobar que no hay nota; guardar sin red, reiniciar y sincronizar con otro miembro; volver atrás; cambiar de app y volver; bloquear/desbloquear.
