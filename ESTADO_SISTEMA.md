# Anivermaru — cambios y estado del sistema

Actualizado: 30 de septiembre de 2026. Resumen completo; distingue los cambios de esta entrega de funcionalidades incorporadas previamente.

## Cambios de esta entrega

### Identidad y Android

- Nombre visible **Anivermaru** en app, manifest Android y metadatos web.
- Nuevo logotipo con Maru y Lady siguiendo las figuras del juego; assets e iconos Android incluidos.
- APK de depuración compilado para pruebas. Los APK, claves de firma y herramientas locales no se incluyen en Git.

### Cartas y cámara 3D

- Reemplazo de ARCore/detección obligatoria de superficies por Camera2 con carta superpuesta visible inmediatamente.
- Frente y reverso del visor, rotación 360°, inclinación, escala, movimiento, centrado, giro automático y brillos.
- Controles fuera de las barras del sistema Android.
- Foto compuesta de cámara/carta; guardado explícito en Nuestro bloc o descarte.
- No hay anclaje físico, detección de superficies ni oclusión: se prioriza interacción y disponibilidad.

### Juegos y navegación

- Block Blaster: arrastre alineado con celdas reales, proyección por encima del dedo, eliminación de espacios sin respuesta táctil entre casillas y SFX nativos sencillos de colocación/limpieza.
- Ascenso: inclinación Android con calibración, suavizado y zona muerta; ON/OFF entre flechas, compatible con teclado/touch. Sensor suspendido al pasar a segundo plano.
- Cruce entre laterales conservando velocidad horizontal; zona renombrada Cielo estrellado.
- Deslizamiento vertical intencional desde la zona superior para cambiar menú: mínimo 150 px, menos de 450 ms, mínimo 1000 px/s y predominio vertical. No usa el área del mural ni actúa mientras otra ruta está abierta.

### Firebase, notas y rankings

- Ranking global `game_scores`, independiente del bloc: Android y PC compiten con todos los usuarios autenticados; filtro por juego y actualización en vivo.
- Migración histórica sin disminuir récords. Auditoría de migración: dos jugadores y cinco registros existentes; sin correos privados en este documento.
- Reglas Firestore: lectura autenticada, escritura solo del UID propio, juegos válidos y récord no decreciente. Reglas globales desplegadas en `cumplemes`.
- Permiso de consulta de membresía Firestore corregido para el agente de Storage; diagnóstico administrativo sin imprimir credenciales.
- Transporte de notas desacoplado para pruebas, errores específicos, listeners recuperables y cola persistida.
- Fotos previas al login se adoptan al conectar. Reutiliza adjuntos subidos aunque falle la escritura del documento; IDs estables y versiones de imagen.
- Una imagen fallida no elimina texto ni bloquea otras notas. Una caché offline incompleta no borra notas locales.
- Guardar desde la interfaz termina tras persistir localmente; subidas en segundo plano.

### Sin internet

- Guardado local: monedas, cartas/variantes, tablero de bloques, Wordlady, Candy y récord/resumen de Ascenso.
- Récords de los cuatro juegos son una cola durable; confirmación solo tras subida correcta.
- Un fallo de juego no bloquea los demás; récords nuevos durante una subida quedan pendientes.
- Arranque offline con cuenta/espacio recordados y conexión cloud sin bloquear el menú.
- Reintentos periódicos de progreso/notas y al regresar a la app. No hay servicio Android permanente de subida con la app cerrada.
- Separación por cuenta. Conflictos entre dispositivos conservan versiones y requieren elegir: no se suman monedas/cartas automáticamente.

## Funcionalidades previas conservadas

- Cuatro juegos destacados: Block Blaster Maru Editions, Wordlady, Candy Churu Cat y Ascenso Maruzon.
- 334 memes, Momazos vol. 1/vol. 2 y seis cartas de ejemplo; carrusel, álbum de faltantes sin spoilers, filtros y visor con zoom/giro.
- Rarezas ampliadas, garantía de legendaria a la apertura 25 sin obtenerla, variantes foil plateada/dorada y efectos de apertura según calidad.
- Colección y gato que descubrió la carta, marcos, colores derivados de imágenes y reversos personalizados.
- Mascotas con animaciones aleatorias, interacción táctil, cartas en menú y máximo dos gatos en Colección.
- Mural con textos, fotos, pintura editable y tamaño/posición; invitación/unión dentro de Nuestro bloc.
- Google y nombre de usuario editable, progreso por UID y presencia compartida.
- Ascenso: tormentas peligrosas incluso con cohete, aviones orientados al movimiento, OVNI/teletransporte seguro, animación triste y ocho zonas hasta el Cielo.

## Estado y comprobaciones

- Versión funcional de prueba para Android/web; aún no es una publicación release para Google Play.
- `flutter analyze --no-pub`: sin incidencias en la última revisión.
- Revisión final: **62 pruebas aprobadas** con `flutter test --no-pub --concurrency=1`. Una ejecución paralela falló al esperar la pantalla de pistas de Wordlady; esa prueba pasó aislada y en la suite secuencial. Queda pendiente hacer su espera de carga más robusta bajo carga paralela.
- Pruebas Flutter: juegos, cartas, variantes, colección, cámara, gestos, rankings y sincronización. Nueva cobertura de red fallida, reinicio, cambio de cuenta, nuevas marcas durante subida, fotos offline y caché incompleta.
- APK Android debug compilado; servidor web local recompilado.
- Reglas verificadas con emuladores Auth/Firestore/Storage/Realtime Database en la entrega de sincronización/rankings; configuración y registros globales auditados también en el proyecto real.
- Fallos de red/reinicio simulados en pruebas: no sustituyen validación integral de modo avión en un teléfono físico.

## Pendientes antes de publicación

1. Teléfonos reales: permisos/cámara, luces bajas, foto/giro/zoom, barras del sistema, sensibilidad/dirección de inclinación.
2. Dos usuarios/dispositivos: modo avión, notas con fotos/dibujos, récords de cuatro juegos, reinicio/reconexión y conflictos simultáneos.
3. Firma release, huellas Google/Play App Signing, APK/AAB final, privacidad y permisos.
4. Validación de recompensas/puntuaciones en servidor y App Check antes de competición pública o monetización; actualmente se calculan en el cliente.
5. Limpieza de adjuntos antiguos, cuotas locales y costos Blaze. En web las fotos pueden agotar la cuota del navegador.
6. Actualizar plugins Firebase/Android cuando soporten la nueva compatibilidad Kotlin Gradle requerida por futuras versiones de Flutter.
7. iOS no está preparado/validado para distribución; cámara 3D e inclinación nativa son Android.

Supabase/Drive permanecen como material histórico, no backend activo. Ascenso guarda récord/resumen, no restaura una simulación a mitad de salto.
