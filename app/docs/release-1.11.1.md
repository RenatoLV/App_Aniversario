# Anivermaru 1.11.1

- Corregido el cierre de Uncanny Cat Golf al iniciar en la APK de distribución: se conservan las clases y los métodos que Godot necesita desde su motor nativo.
- Juego original en horizontal, con el panel y la cancha distribuidos como en PC, sin recortes ni deformaciones.
- Controles transparentes de pausa, reinicio, Parry y salida en los laterales.
- Una segunda apertura reutiliza la instancia existente del motor. El botón Atrás pausa el juego con el sistema de navegación de Android actual.
- Distribución ARM64 sin bibliotecas innecesarias de otras arquitecturas. Se conserva intacto el paquete verificado del juego original.
- La compilación comprueba la APK final para detectar pérdidas de clases o métodos de Godot antes de publicar.

Integración probada en Xiaomi 14T con Android 16; el usuario confirmó haber probado personalmente las partes del juego. El tamaño y los requisitos de memoria siguen siendo elevados por los recursos originales incluidos.

Juego original: **SH2K (SlappyHappy2000) y The Canny Crew**. Integración móvil no oficial. Créditos originales conservados dentro del juego.
