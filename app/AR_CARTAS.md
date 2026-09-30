# Cartas en realidad aumentada

En Colección, abre una carta y pulsa **Ver en realidad aumentada**. El modo usa ARCore nativo en Android (no es una imagen pegada sobre la cámara). La carta conserva el diseño, volumen, rareza y acabado elegidos al abrir el visor.

1. Acepta el aviso de cámara y concede el permiso de Android.
2. Instala/actualiza Google Play Services para AR si Android lo solicita.
3. Mueve el teléfono despacio, en un lugar iluminado con una mesa o suelo con textura.
4. Toca una superficie detectada: la carta se ancla a ese lugar, de pie y mirando hacia ti. Puedes moverte alrededor de ella.
5. Pellizca para agrandar o achicar (20–400%). También hay botones + y −. Toca otra superficie para recolocarla.
6. Pulsa **Foto**. La captura incluye la cámara y la carta, sin botones.
7. Revisa la foto: **Guardar en Nuestro bloc** crea una nota con la foto en el mural de la app; **Descartar** no crea ni sincroniza nada.

## Privacidad y almacenamiento

La función no usa Cloud Anchors ni envía las imágenes de cámara a Firebase durante la sesión. Se utiliza Google Play Services para AR, con sus requisitos de disponibilidad/instalación. Solo al guardar se incorpora el JPEG al mismo flujo de notas local/offline y Storage existente. Si el usuario tiene un espacio conectado, sus miembros podrán ver esa nota.

Los archivos de intercambio nativo se crean en la caché privada de la app y se eliminan al volver al visor. La captura se limita a 1200 píxeles en su lado mayor para no superar el límite de adjuntos del mural. No requiere permisos de galería ni escribe en la galería.

## Alcance y comprobación pendiente

- Android 7+ en dispositivos compatibles con ARCore. La app sigue funcionando sin AR en dispositivos no compatibles.
- Web/iOS muestran un aviso de que este modo aún no está disponible.
- Se detectan superficies horizontales. No hay oclusión por objetos reales ni reflejos foil dinámicos: se usa una textura del frente de la carta seleccionada.
- La cámara, el seguimiento, la orientación y el anclaje necesitan validación física; una compilación o prueba de widgets no demuestra que la cámara funcione en cada teléfono.

Prueba manual: conceder y denegar cámara; aceptar/cancelar instalación de AR; colocar en una mesa; moverse alrededor; pellizcar sin recolocación involuntaria; capturar; descartar y comprobar que no hay nota; volver a capturar y guardar; reiniciar la app y verificar la nota; comprobarla con otro miembro del espacio; volver atrás desde AR; cambiar de app y volver; bloquear y desbloquear el teléfono.
