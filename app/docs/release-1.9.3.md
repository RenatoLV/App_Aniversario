# Anivermaru 1.9.3 · Sobres, patio y recompensas

## Marus vs Zombies

- Los invasores brillantes mantienen su atún garantizado. El resto puede dejar atún y, mucho más raramente, Pellizco, Puntero o Spray.
- Muestreo de botín separado del RNG de combate: seis resultados de 200 para atún y uno de 200 para cada poder. Los brillantes sustituyen esa tirada por atún. Los drops adicionales se limitan cuando ya hay dieciséis objetos especiales en pantalla y duran dieciocho segundos.
- Los poderes recogidos se guardan en la partida suspendida, con tres cargas por tipo. Se utilizan desde Poderes, gratis y respetando el enfriamiento existente. Apuntar fuera de objetivo o fallar no consume la carga. Los desafíos mantienen su restricción de poderes humanos.
- Cada invasor derrotado otorga dos monedas para los sobres. Una primera victoria de campaña otorga cien monedas; otras victorias otorgan veinticinco. Los premios de galletitas, mentitas y final de mundo existentes se conservan.
- Las monedas de bajas se consolidan con los checkpoints existentes y al finalizar, incluso en derrota. El total acumulado de derechos de cobro y el contador abonado de la cartera evitan pagos repetidos al reabrir. Un cierre forzado antes del checkpoint conserva el límite de recuperación ya existente.
- Las cargas gratuitas y los drops se restauran sin invalidar checkpoints anteriores. No cambian daño, estadísticas de unidades, oleadas ni el RNG de combate; utilizar los nuevos objetos sí permite las acciones adicionales solicitadas.

## Sobres

- Apertura de diez sobres al precio progresivo habitual, con saldo completo requerido y sin compras parciales.
- Las diez cartas aparecen de una en una. Cada celestial conserva su animación específica y el jugador avanza manualmente; después se muestra el resumen de las diez cartas ya obtenidas.
- Sobre celestial garantizado del volumen seleccionado por **5.000 monedas**. Puede repetirse y conserva los acabados existentes. Su compra no altera el precio diario ni la garantía legendaria de los sobres normales.

## Patio y fútbol

- Puerta de la habitación prolongada hasta el piso, con umbral y espacio reservado bajo el cuadro.
- Nubes en un ciclo independiente de ciento sesenta segundos, con retorno fuera de pantalla, sin retroceso al terminar la brisa de ocho segundos.
- Corregido el `RangeError` web del identificador de Fútbol de Patitas: `1 << 32` producía cero en JavaScript. Se usan dos valores seguros de treinta bits.
- Cuarenta monedas por gol con registro de cobro idempotente, guía de dirección/potencia, tiros largos más controlables, pausa y cancha más amplia en horizontal.

## Validación y límites

Las pruebas cubren precio y saldo insuficiente, apertura secuencial alternando cartas normales y celestiales, restauración, monedas sin duplicación, drops y límites de cargas, tiros, pausa, orientación y alineación de la puerta. El proceso GitHub Actions vuelve a analizar, probar y compilar la APK con la firma preservada antes de publicarla.

Validación local: suite completa con **357 aprobadas y 14 optativas omitidas**. Tras separar el reintento de abono de monedas del checkpoint de combate ya confirmado, cierre específico con **29 aprobadas y una optativa omitida**, y análisis sin incidencias. Una transferencia pendiente de cartera no deshace un poder ni su débito que ya se guardaron correctamente.

La prueba automatizada independiente de Chrome no terminó su carga en este entorno; no se cuenta como aprobada. No hay mediciones nuevas en un Android físico ni certificación de licencias musicales. Se conservan los límites documentados en la revisión V4.1.
