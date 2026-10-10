"""Readable analysis of the deterministic test-side players; standard library only.

Run from app/: python tool/report_mz_v41.py
Regenerate CSV first with DIAGNOSE_V41=true. Does not edit gameplay or balance.
"""
import csv
from collections import Counter, defaultdict
from pathlib import Path

root = Path(__file__).resolve().parents[1]
with (root / 'docs/mz-v41-gameplay.csv').open(encoding='utf-8', newline='') as f:
    rows = list(csv.DictReader(f))
assert len(rows) == 540
strategies = list(dict.fromkeys(r['strategy'] for r in rows))
worlds = list(dict.fromkeys(r['world'] for r in rows))
missions = defaultdict(list)
for row in rows:
    missions[int(row['mission'])].append(row)

out = [
    '# Diagnóstico de jugabilidad V4.1 · 60 misiones',
    '',
    'Fecha: 2026-10-10. 540 partidas, nueve estrategias deterministas. '
    'Cada partida utiliza como máximo seis cartas permitidas por la misión, '
    'los recursos iniciales reales y acciones públicas de la simulación. '
    'No se inyectan gatos, daño, recursos, enemigos ni números aleatorios. '
    'No se usan poderes de galletitas ni Gran León.',
    '',
    'Decisiones cada 0,5 segundos simulados, horizonte máximo 900 s y recogida '
    'manual automatizada de todos los recursos observados. Esto tiene precisión '
    'y atención superiores a una persona: no representa habilidad humana, '
    'dificultad subjetiva ni diversión. Cada perfil utiliza una política fija '
    'sin búsqueda del equipo óptimo; las derrotas se conservan.',
    '',
    '## Estrategias y límites', '',
    '| Perfil | Política |', '| --- | --- |',
    '| reference | Economía, Lanzador por fila, hielo, barreras ante presión, Catapulta o Láser según mundo; atún económico en Girasol. |',
    '| initial | Primeras seis cartas disponibles; minas y defensa básica; sin atún. No significa seis cartas desde el nivel 1. |',
    '| defensive | Prioriza barreras y minas; Girasol y Lanzador; sin cambiar resistencia ni armadura. |',
    '| offensive | Prioriza Lanzador antes de economía y añade atacantes; sin barrera equipada. |',
    '| moderate | Actúa cada 2 s, reserva 100 de hierba salvo amenaza a menos de cuatro casillas; atún económico. |',
    '| no_tuna | Equipo y colocación de reference, sin gastar ninguna lata. |',
    '| strategic_tuna | Equipo reference; atún en defensor no productor con amenaza real a menos de cinco casillas. Es una heurística, no un óptimo. |',
    '| late | Espera hasta que una amenaza llegue a cinco casillas antes de empezar a desplegar. Sigue recogiendo recursos. |',
    '| world | Reserva un hueco y posición para Catapulta/Bumerán/Resorte/Relámpago/Láser según mundo y disponibilidad. |',
    '',
    '## Resultados por perfil', '',
    '| Perfil | Victorias | Derrotas | Tiempo agotado |', '| --- | ---: | ---: | ---: |',
]
for s in strategies:
    c = Counter(r['result'] for r in rows if r['strategy'] == s)
    out.append(f"| {s} | {c['win']} | {c['loss']} | {c['timeout']} |")
out += ['', '## Victorias por mundo (de diez)', '',
        '| Mundo | ' + ' | '.join(strategies) + ' |',
        '| --- | ' + ' | '.join(['---:'] * len(strategies)) + ' |']
for w in worlds:
    wins = [str(sum(r['result'] == 'win' for r in rows if r['world'] == w and r['strategy'] == s)) for s in strategies]
    out.append('| ' + w + ' | ' + ' | '.join(wins) + ' |')
out += ['', '## Las 60 misiones', '',
        'V/D: victorias/derrotas de los nueve perfiles. Las demás columnas pertenecen '
        'a reference, para mantener comparable una misma política. IDs internos '
        'conservados; misión es el orden visible. No se promedia el tiempo de una '
        'derrota con el de una victoria para inferir rapidez.', '',
        '| Misión | ID | Mundo | V/D | Duración s | Hierba generada/gastada | Gatos colocados/perdidos | Restante | Kills | Roombas | Atún | ★ | Pico s |',
        '| ---: | ---: | --- | --- | ---: | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |']
for n, group in sorted(missions.items()):
    r = next(r for r in group if r['strategy'] == 'reference')
    wins = sum(x['result'] == 'win' for x in group)
    out.append(f"| {n} | {r['id']} | {r['world']} | {wins}/{9-wins} | {r['seconds']} | "
               f"{r['generated']}/{r['spent']} | {r['placed']}/{r['lost']} | {r['remaining']} | "
               f"{r['kills']} | {r['roombas']} | {r['tuna']} | {r['stars']} | {r['peakPressureAt']} |")
out += ['', '## Transiciones y cierres que merecen prueba humana', '',
        '| Misión | Mundo | Perfiles que ganan | Duración reference s | Pérdidas / Roombas |',
        '| ---: | --- | ---: | ---: | --- |']
for n in [1,10,11,20,21,30,31,40,41,50,51,60]:
    group = missions[n]
    r = next(r for r in group if r['strategy'] == 'reference')
    out.append(f"| {n} | {r['world']} | {sum(x['result']=='win' for x in group)}/9 | {r['seconds']} | {r['lost']} / {r['roombas']} |")
out += ['', '## Uso observado de defensores', '',
        'Colocaciones acumuladas en los nueve perfiles. Son sesgos del repertorio '
        'y posiciones del bot: no prueban que una carta sea necesaria, inútil o '
        'dominante. reference y world ganan las 60 con equipos que cambian por tramo; '
        'no se ha demostrado que un único equipo fijo domine toda la campaña.', '',
        '| Defensor | Colocaciones |', '| --- | ---: |']
counts = Counter()
for r in rows:
    for entry in filter(None, r['placementsByCat'].split('|')):
        cat, n = entry.split(':')
        counts[cat] += int(n)
for cat, n in sorted(counts.items()):
    out.append(f'| {cat} | {n} |')
out += ['', '## Interpretación y decisiones', '',
        '- Hay sensibilidad al equipo, al atún y a la respuesta tardía. Revisar '
        'Oeste con principiantes; comparar Cementerio y Egipto con/sin Catapulta. '
        'El conjunto no prueba una curva gradual ni niveles «demasiado fáciles».',
        '- El jefe puede prolongar significativamente la misión 60; probar '
        'fatiga y comprensión de sus fases en una sesión real antes de ajustar vida '
        'o daño. No se aplicó rebalanceo.',
        '- Cementerio tiene lápidas y noche, pero los mismos cuatro arquetipos '
        'básicos de Patio y ninguna carta nueva. El salto Bumerán→Resorte ocupa '
        'veinte misiones visibles. Su variedad y motivación quedan pendientes de '
        'evaluación humana; se añadió ayuda contextual sin nuevos contenidos.',
        '- La prueba conservadora anterior decidía Láser por ID >=40 y por eso '
        'omitía Catapulta en Cementerio (IDs 50–59). El diagnóstico y smoke test '
        'ahora eligen por mundo. Es una corrección de la prueba, no del equipo del jugador.',
        '', '## Definición de métricas y reproducción', '',
        '`mz-v41-gameplay.csv` conserva las 540 filas, equipo, estadísticas y '
        'colocaciones por tipo. Generada = 25 por pickup de hierba realmente '
        'observado; recogida se registra separadamente. No incluye lo que el bot '
        'no llegó a observar entre decisiones, ni se confunde con saldo inicial. '
        'Gastada procede exclusivamente de colocaciones exitosas. '
        '`survivorDamage` es un mínimo de HP/armadura perdido por gatos que siguen '
        'presentes al final de cada intervalo; no atribuye daño inventado a gatos '
        'retirados, raptados o explosivos. `dangerSeconds` cuenta intervalos de '
        '0,5 s con enemigo x<1,5. Presión = suma de max(0,10−x) de invasores reales; '
        'su máximo sólo compara concentración/proximidad, no es un criterio de diversión. '
        '`lost` usa la estadística oficial y no cuenta consumibles como bajas normales.',
        '', 'Desde `app/`, secuencialmente:', '', '```powershell',
        'flutter test test/marus_zombies/gameplay_diagnostic_test.dart --no-pub --dart-define=DIAGNOSE_V41=true',
        'python tool/report_mz_v41.py', '```', '',
        'La ejecución normal comprueba legalidad y determinismo; la matriz completa '
        'es optativa para no añadir ~50 s a cada suite. No hay compilación de aplicación.', '']
(root / 'docs/mz-v41-gameplay.md').write_text('\n'.join(out), encoding='utf-8')
