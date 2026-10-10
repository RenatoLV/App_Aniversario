# Diagnóstico de jugabilidad V4.1 · 60 misiones

Fecha: 2026-10-10. 540 partidas, nueve estrategias deterministas. Cada partida utiliza como máximo seis cartas permitidas por la misión, los recursos iniciales reales y acciones públicas de la simulación. No se inyectan gatos, daño, recursos, enemigos ni números aleatorios. No se usan poderes de galletitas ni Gran León.

Decisiones cada 0,5 segundos simulados, horizonte máximo 900 s y recogida manual automatizada de todos los recursos observados. Esto tiene precisión y atención superiores a una persona: no representa habilidad humana, dificultad subjetiva ni diversión. Cada perfil utiliza una política fija sin búsqueda del equipo óptimo; las derrotas se conservan.

## Estrategias y límites

| Perfil | Política |
| --- | --- |
| reference | Economía, Lanzador por fila, hielo, barreras ante presión, Catapulta o Láser según mundo; atún económico en Girasol. |
| initial | Primeras seis cartas disponibles; minas y defensa básica; sin atún. No significa seis cartas desde el nivel 1. |
| defensive | Prioriza barreras y minas; Girasol y Lanzador; sin cambiar resistencia ni armadura. |
| offensive | Prioriza Lanzador antes de economía y añade atacantes; sin barrera equipada. |
| moderate | Actúa cada 2 s, reserva 100 de hierba salvo amenaza a menos de cuatro casillas; atún económico. |
| no_tuna | Equipo y colocación de reference, sin gastar ninguna lata. |
| strategic_tuna | Equipo reference; atún en defensor no productor con amenaza real a menos de cinco casillas. Es una heurística, no un óptimo. |
| late | Espera hasta que una amenaza llegue a cinco casillas antes de empezar a desplegar. Sigue recogiendo recursos. |
| world | Reserva un hueco y posición para Catapulta/Bumerán/Resorte/Relámpago/Láser según mundo y disponibilidad. |

## Resultados por perfil

| Perfil | Victorias | Derrotas | Tiempo agotado |
| --- | ---: | ---: | ---: |
| reference | 60 | 0 | 0 |
| initial | 36 | 24 | 0 |
| defensive | 58 | 2 | 0 |
| offensive | 55 | 5 | 0 |
| moderate | 48 | 12 | 0 |
| no_tuna | 31 | 29 | 0 |
| strategic_tuna | 57 | 3 | 0 |
| late | 34 | 26 | 0 |
| world | 60 | 0 | 0 |

## Victorias por mundo (de diez)

| Mundo | reference | initial | defensive | offensive | moderate | no_tuna | strategic_tuna | late | world |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| patio | 10 | 9 | 9 | 9 | 8 | 8 | 10 | 4 | 10 |
| cemetery | 10 | 5 | 10 | 9 | 8 | 1 | 10 | 5 | 10 |
| egypt | 10 | 8 | 10 | 9 | 6 | 5 | 10 | 4 | 10 |
| pirates | 10 | 8 | 10 | 10 | 9 | 8 | 10 | 7 | 10 |
| west | 10 | 4 | 9 | 9 | 9 | 4 | 8 | 4 | 10 |
| future | 10 | 2 | 10 | 9 | 8 | 5 | 9 | 10 | 10 |

## Las 60 misiones

V/D: victorias/derrotas de los nueve perfiles. Las demás columnas pertenecen a reference, para mantener comparable una misma política. IDs internos conservados; misión es el orden visible. No se promedia el tiempo de una derrota con el de una victoria para inferir rapidez.

| Misión | ID | Mundo | V/D | Duración s | Hierba generada/gastada | Gatos colocados/perdidos | Restante | Kills | Roombas | Atún | ★ | Pico s |
| ---: | ---: | --- | --- | ---: | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 0 | patio | 9/0 | 127.27 | 400/300 | 3/0 | 300 | 8 | 0 | 0 | 3 | 113.0 |
| 2 | 1 | patio | 9/0 | 123.18 | 975/850 | 11/1 | 250 | 18 | 0 | 0 | 3 | 68.5 |
| 3 | 2 | patio | 8/1 | 150.6 | 1125/1200 | 18/4 | 75 | 20 | 2 | 0 | 1 | 108.0 |
| 4 | 3 | patio | 8/1 | 158.78 | 1225/1250 | 19/5 | 125 | 22 | 2 | 0 | 1 | 102.5 |
| 5 | 4 | patio | 8/1 | 168.98 | 1275/1375 | 19/4 | 50 | 24 | 2 | 0 | 1 | 108.0 |
| 6 | 5 | patio | 8/1 | 179.42 | 1425/1550 | 20/4 | 0 | 26 | 2 | 0 | 1 | 101.0 |
| 7 | 6 | patio | 5/4 | 234.82 | 1850/2000 | 29/14 | 0 | 28 | 2 | 0 | 1 | 114.5 |
| 8 | 7 | patio | 8/1 | 202.45 | 2675/2750 | 33/12 | 75 | 30 | 3 | 3 | 1 | 119.5 |
| 9 | 8 | patio | 8/1 | 212.5 | 3225/2700 | 28/4 | 675 | 42 | 1 | 4 | 1 | 108.0 |
| 10 | 9 | patio | 6/3 | 252.98 | 3850/3550 | 45/22 | 450 | 44 | 3 | 5 | 1 | 109.0 |
| 11 | 50 | cemetery | 8/1 | 173.2 | 2450/2500 | 29/7 | 100 | 29 | 2 | 3 | 1 | 111.0 |
| 12 | 51 | cemetery | 7/2 | 244.27 | 2975/3100 | 42/24 | 25 | 31 | 4 | 3 | 1 | 147.5 |
| 13 | 52 | cemetery | 7/2 | 187.7 | 2975/2725 | 29/5 | 400 | 33 | 2 | 4 | 1 | 108.0 |
| 14 | 53 | cemetery | 5/4 | 191.02 | 3000/2750 | 29/5 | 400 | 35 | 2 | 4 | 1 | 108.0 |
| 15 | 54 | cemetery | 8/1 | 207.97 | 3125/3125 | 34/9 | 150 | 37 | 2 | 4 | 1 | 119.5 |
| 16 | 55 | cemetery | 7/2 | 201.07 | 3100/2850 | 29/4 | 400 | 39 | 2 | 4 | 1 | 108.0 |
| 17 | 56 | cemetery | 7/2 | 214.73 | 2800/2900 | 32/7 | 50 | 41 | 2 | 3 | 1 | 114.5 |
| 18 | 57 | cemetery | 7/2 | 244.78 | 3800/3550 | 40/15 | 400 | 43 | 3 | 5 | 1 | 119.5 |
| 19 | 58 | cemetery | 7/2 | 229.0 | 3325/2700 | 28/4 | 775 | 45 | 1 | 4 | 1 | 108.0 |
| 20 | 59 | cemetery | 5/4 | 269.92 | 3625/3550 | 43/18 | 225 | 47 | 3 | 4 | 1 | 109.0 |
| 21 | 10 | egypt | 9/0 | 159.33 | 2375/2500 | 27/4 | 25 | 29 | 2 | 3 | 1 | 108.0 |
| 22 | 11 | egypt | 8/1 | 177.88 | 2525/2500 | 29/6 | 150 | 31 | 2 | 3 | 1 | 114.5 |
| 23 | 12 | egypt | 7/2 | 174.4 | 2850/2750 | 32/10 | 250 | 33 | 3 | 4 | 1 | 112.0 |
| 24 | 13 | egypt | 8/1 | 182.62 | 2550/2675 | 28/8 | 25 | 35 | 1 | 3 | 1 | 133.5 |
| 25 | 14 | egypt | 5/4 | 227.58 | 2925/3025 | 35/12 | 50 | 37 | 2 | 3 | 1 | 119.5 |
| 26 | 15 | egypt | 7/2 | 237.68 | 3375/3450 | 41/17 | 75 | 39 | 3 | 4 | 1 | 114.0 |
| 27 | 16 | egypt | 8/1 | 210.18 | 3075/2875 | 34/11 | 350 | 41 | 3 | 4 | 1 | 97.0 |
| 28 | 17 | egypt | 6/3 | 233.47 | 3675/3000 | 34/9 | 825 | 43 | 3 | 5 | 1 | 96.5 |
| 29 | 18 | egypt | 9/0 | 233.25 | 3350/3500 | 36/9 | 0 | 45 | 2 | 4 | 1 | 102.5 |
| 30 | 19 | egypt | 5/4 | 286.22 | 3725/3825 | 49/26 | 50 | 47 | 3 | 4 | 1 | 152.5 |
| 31 | 20 | pirates | 8/1 | 179.4 | 2575/2600 | 28/5 | 100 | 32 | 2 | 3 | 1 | 108.0 |
| 32 | 21 | pirates | 8/1 | 212.53 | 3125/3275 | 43/20 | 0 | 34 | 3 | 4 | 1 | 115.0 |
| 33 | 22 | pirates | 6/3 | 181.62 | 2950/2800 | 30/6 | 300 | 36 | 2 | 4 | 1 | 111.5 |
| 34 | 23 | pirates | 9/0 | 190.5 | 2650/2650 | 26/2 | 150 | 38 | 0 | 3 | 3 | 131.0 |
| 35 | 24 | pirates | 9/0 | 202.45 | 3100/2850 | 30/7 | 400 | 40 | 1 | 4 | 1 | 54.0 |
| 36 | 25 | pirates | 9/0 | 212.5 | 3200/2900 | 32/8 | 450 | 42 | 2 | 4 | 1 | 111.5 |
| 37 | 26 | pirates | 8/1 | 223.5 | 3275/2450 | 24/0 | 975 | 44 | 0 | 4 | 3 | 60.5 |
| 38 | 27 | pirates | 8/1 | 234.5 | 3350/3050 | 33/9 | 450 | 46 | 2 | 4 | 1 | 125.5 |
| 39 | 28 | pirates | 8/1 | 245.5 | 3475/2350 | 22/0 | 1275 | 48 | 0 | 4 | 3 | 65.0 |
| 40 | 29 | pirates | 9/0 | 270.83 | 3650/2800 | 30/7 | 1000 | 50 | 1 | 4 | 1 | 120.0 |
| 41 | 30 | west | 5/4 | 190.48 | 2950/2800 | 40/10 | 300 | 35 | 1 | 4 | 1 | 132.5 |
| 42 | 31 | west | 6/3 | 206.63 | 3125/2600 | 37/5 | 675 | 37 | 2 | 4 | 1 | 106.0 |
| 43 | 32 | west | 8/1 | 211.68 | 3175/2650 | 39/9 | 625 | 39 | 2 | 4 | 1 | 147.0 |
| 44 | 33 | west | 5/4 | 224.05 | 2900/2575 | 35/7 | 450 | 41 | 1 | 3 | 1 | 156.0 |
| 45 | 34 | west | 9/0 | 250.9 | 3850/2325 | 30/0 | 1675 | 43 | 0 | 5 | 3 | 96.0 |
| 46 | 35 | west | 6/3 | 234.97 | 3325/2375 | 30/0 | 1100 | 45 | 0 | 4 | 3 | 97.5 |
| 47 | 36 | west | 4/5 | 255.7 | 3900/3725 | 50/17 | 325 | 47 | 2 | 5 | 1 | 131.5 |
| 48 | 37 | west | 9/0 | 299.92 | 4300/2325 | 32/4 | 2100 | 49 | 0 | 5 | 2 | 132.5 |
| 49 | 38 | west | 9/0 | 267.97 | 4375/2125 | 27/2 | 2400 | 51 | 0 | 6 | 3 | 107.5 |
| 50 | 39 | west | 6/3 | 353.25 | 5075/2650 | 36/3 | 2575 | 53 | 0 | 6 | 3 | 127.0 |
| 51 | 40 | future | 9/0 | 199.0 | 3075/2900 | 27/4 | 325 | 38 | 2 | 4 | 1 | 108.0 |
| 52 | 41 | future | 7/2 | 219.17 | 3250/3175 | 31/7 | 200 | 40 | 2 | 4 | 1 | 114.5 |
| 53 | 42 | future | 7/2 | 222.17 | 3625/3100 | 32/9 | 650 | 42 | 3 | 5 | 1 | 114.0 |
| 54 | 43 | future | 7/2 | 229.47 | 3675/3675 | 37/13 | 150 | 44 | 2 | 5 | 1 | 148.5 |
| 55 | 44 | future | 7/2 | 235.5 | 3750/3600 | 33/7 | 250 | 46 | 2 | 5 | 1 | 119.5 |
| 56 | 45 | future | 7/2 | 241.97 | 3425/3200 | 28/4 | 375 | 48 | 2 | 4 | 1 | 108.0 |
| 57 | 46 | future | 8/1 | 257.5 | 3925/3700 | 34/8 | 375 | 50 | 2 | 5 | 1 | 108.0 |
| 58 | 47 | future | 7/2 | 263.97 | 3925/3550 | 34/9 | 525 | 52 | 3 | 5 | 1 | 114.0 |
| 59 | 48 | future | 7/2 | 274.97 | 4025/4125 | 39/13 | 50 | 54 | 2 | 5 | 1 | 148.5 |
| 60 | 49 | future | 7/2 | 521.72 | 8375/6775 | 54/28 | 1750 | 77 | 2 | 11 | 1 | 119.5 |

## Transiciones y cierres que merecen prueba humana

| Misión | Mundo | Perfiles que ganan | Duración reference s | Pérdidas / Roombas |
| ---: | --- | ---: | ---: | --- |
| 1 | patio | 9/9 | 127.27 | 0 / 0 |
| 10 | patio | 6/9 | 252.98 | 22 / 3 |
| 11 | cemetery | 8/9 | 173.2 | 7 / 2 |
| 20 | cemetery | 5/9 | 269.92 | 18 / 3 |
| 21 | egypt | 9/9 | 159.33 | 4 / 2 |
| 30 | egypt | 5/9 | 286.22 | 26 / 3 |
| 31 | pirates | 8/9 | 179.4 | 5 / 2 |
| 40 | pirates | 9/9 | 270.83 | 7 / 1 |
| 41 | west | 5/9 | 190.48 | 10 / 1 |
| 50 | west | 6/9 | 353.25 | 3 / 0 |
| 51 | future | 9/9 | 199.0 | 4 / 2 |
| 60 | future | 7/9 | 521.72 | 28 / 2 |

## Uso observado de defensores

Colocaciones acumuladas en los nueve perfiles. Son sesgos del repertorio y posiciones del bot: no prueban que una carta sea necesaria, inútil o dominante. reference y world ganan las 60 con equipos que cambian por tramo; no se ha demostrado que un único equipo fijo domine toda la campaña.

| Defensor | Colocaciones |
| --- | ---: |
| barrier | 2752 |
| bomb | 94 |
| boomerang | 117 |
| catapult | 1270 |
| ice | 1479 |
| laser | 168 |
| launcher | 3694 |
| lightning | 104 |
| mine | 2340 |
| spring | 54 |
| sunflower | 6254 |

## Interpretación y decisiones

- Hay sensibilidad al equipo, al atún y a la respuesta tardía. Revisar Oeste con principiantes; comparar Cementerio y Egipto con/sin Catapulta. El conjunto no prueba una curva gradual ni niveles «demasiado fáciles».
- El jefe puede prolongar significativamente la misión 60; probar fatiga y comprensión de sus fases en una sesión real antes de ajustar vida o daño. No se aplicó rebalanceo.
- Cementerio tiene lápidas y noche, pero los mismos cuatro arquetipos básicos de Patio y ninguna carta nueva. El salto Bumerán→Resorte ocupa veinte misiones visibles. Su variedad y motivación quedan pendientes de evaluación humana; se añadió ayuda contextual sin nuevos contenidos.
- La prueba conservadora anterior decidía Láser por ID >=40 y por eso omitía Catapulta en Cementerio (IDs 50–59). El diagnóstico y smoke test ahora eligen por mundo. Es una corrección de la prueba, no del equipo del jugador.

## Definición de métricas y reproducción

`mz-v41-gameplay.csv` conserva las 540 filas, equipo, estadísticas y colocaciones por tipo. Generada = 25 por pickup de hierba realmente observado; recogida se registra separadamente. No incluye lo que el bot no llegó a observar entre decisiones, ni se confunde con saldo inicial. Gastada procede exclusivamente de colocaciones exitosas. `survivorDamage` es un mínimo de HP/armadura perdido por gatos que siguen presentes al final de cada intervalo; no atribuye daño inventado a gatos retirados, raptados o explosivos. `dangerSeconds` cuenta intervalos de 0,5 s con enemigo x<1,5. Presión = suma de max(0,10−x) de invasores reales; su máximo sólo compara concentración/proximidad, no es un criterio de diversión. `lost` usa la estadística oficial y no cuenta consumibles como bajas normales.

Desde `app/`, secuencialmente:

```powershell
flutter test test/marus_zombies/gameplay_diagnostic_test.dart --no-pub --dart-define=DIAGNOSE_V41=true
python tool/report_mz_v41.py
```

La ejecución normal comprueba legalidad y determinismo; la matriz completa es optativa para no añadir ~50 s a cada suite. No hay compilación de aplicación.
