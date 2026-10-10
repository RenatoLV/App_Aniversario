# Anivermaru 1.9.2 · Marus vs Zombies V4.1

Esta actualización incorpora la evolución V3/V4 de Marus vs Zombies y el cierre de calidad V4.1, conservando las reglas del combate, estadísticas, economía y desbloqueos.

## Cambios incluidos

- Arte vectorial y animaciones individuales de los once defensores, enemigos y habilidades de atún.
- Seis mundos y sesenta misiones, incluido Cementerio nocturno entre Patio y Egipto.
- Almanaque ilustrado con requisitos reales de obtención, colección y equipo.
- Revelación de cartas nuevas, presentación de resultados, avisos de grandes oleadas y llegada del jefe.
- Identidad sonora de defensores y mezclador con límites de voces, pausa y volumen.
- Corrección de guardados rechazados para impedir que datos no confirmados reaparezcan desde la caché.
- Prioridad de pala, atún y otras herramientas sobre recursos superpuestos.
- Confirmación y cancelación de atún en pantallas estrechas, mejor contraste y ayuda contextual plegable.

## Validación previa a la release

- 339 pruebas automatizadas aprobadas; 14 pruebas optativas omitidas.
- Análisis Flutter sin incidencias.
- Diagnóstico determinista de 540 partidas sobre las sesenta misiones, sin cambiar el balance.
- El proceso Android de GitHub Actions vuelve a comprobar pruebas, Firebase, análisis, compilación y firma antes de publicar los archivos.

## Instalación y límites

La APK ARM64 utiliza la firma existente para actualizar instalaciones compatibles sin desinstalar. GitHub Actions asigna el número de compilación creciente y genera `update.json` y `SHA256SUMS.txt`.

No se ha medido esta versión en un Android físico ni validado una sesión larga de audio en ese dispositivo. El diagnóstico automatizado no certifica la dificultad ni la diversión para jugadores reales. Continúa pendiente la autorización de redistribución de la música aportada por el propietario; esta release no certifica licencias comerciales.

Los resultados y límites detallados están en [la revisión V4.1](../MARUS_VS_ZOMBIES_V41_QUALITY_REVIEW.md) y [la evolución visual](../MARUS_VS_ZOMBIES_VISUAL_EVOLUTION_V3.md).
