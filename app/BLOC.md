# Nuestro bloc

El mural tiene un tamaño estable, papel punteado y márgenes redondeados. Arrastra el fondo para explorar o pellizca para cambiar el zoom. Los botones −, encuadrar y + permiten volver a encontrar los recuerdos.

Toca una nota, foto o dibujo para seleccionar, editar, cambiar su tamaño o borrarlo. Activa **Mover notas** para arrastrar los elementos con un dedo; con dos dedos sobre el elemento cambia su tamaño. El modo **Explorar** vuelve a mover el mural. Un doble toque abre el editor. El borrado ofrece **Deshacer**, también en el bloc compartido.

Las fotos conservan su proporción. El dibujo abre un lienzo de pantalla completa con lápiz, marcador, goma, colores, grosor y deshacer/rehacer. La goma también borra los píxeles de un dibujo guardado.

## Compartir

Conecta Google y abre el botón de personas. Busca el nombre de la app, envía una solicitud y revisa **Enviadas**. El dueño responde en **Recibidas**; después de aceptar, aparece **Entrar a su bloc**. Los códigos de invitación existentes siguen disponibles. Los cambios se guardan localmente y se reintentan cuando vuelve la conexión.

`user_directory/{uid}` contiene exclusivamente nombre, clave de búsqueda y última conexión: no expone correo ni progreso. `bloc_requests/{destino}_{solicitante}` solo es legible por ambos participantes. Firebase valida que únicamente el destinatario dueño del bloc pueda aceptar una solicitud. Un solicitante puede volver a enviar una solicitud rechazada, pero no aprobarla ni modificar una ya aceptada.

Los documentos de notas usan `deleted` para propagar el borrado y permitir deshacer sin perder la foto o dibujo. Los documentos anteriores sin este campo siguen funcionando. Las notas nunca cambian de posición por temporizadores; durante el arrastre se pospone la escritura y se conservan los cambios locales frente a snapshots antiguos.

## Verificación

`flutter analyze --no-pub` y `flutter test --no-pub` incluyen pruebas de gestos en celular, borrado/restauración con sincronización, goma sobre un dibujo guardado y herramientas en una pantalla de 320 × 640.

`firebase emulators:exec --project demo-cumplemes --only auth,firestore,database,storage "node tool/firebase_tests/rules.test.cjs"` comprueba privacidad, solicitudes, aprobación, pertenencia y permisos sobre notas e imágenes.
