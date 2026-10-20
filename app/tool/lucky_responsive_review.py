"""Build a reproducible comparison from real Flutter captures and measured Rects.
Run after lucky_mobile_quality_test with LUCKY_CAPTURE=build/previews/lucky-responsive/after.
"""
import csv
import html
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
out = root / 'build/previews/lucky-responsive'
rows = {}
for line in (root / 'build/responsive-final-ui.log').read_text(encoding='utf-8').splitlines():
    if 'RESPONSIVE_GEOMETRY ' in line:
        value = json.loads(line.split('RESPONSIVE_GEOMETRY ', 1)[1])
        rows[(value['width'], value['text'])] = value
if len(rows) != 12:
    raise SystemExit(f'Expected twelve measured viewports, found {len(rows)}')
values = [rows[k] for k in sorted(rows)]
out.mkdir(parents=True, exist_ok=True)
(out / 'geometry.json').write_text(json.dumps(values, indent=2), encoding='utf-8')
with (out / 'geometry.csv').open('w', newline='', encoding='utf-8') as f:
    writer = csv.writer(f)
    writer.writerow(['viewport_w','viewport_h','text_scale','region','x','y','width','height'])
    for v in values:
        for region, rect in v['regions'].items():
            writer.writerow([v['width'],v['height'],v['text'],region,*rect])
sections = []
for v in values:
    w, h, scale = int(v['width']), int(v['height']), round(v['text'] * 100)
    name = f'quality-{w}-{scale}.png'
    for side in ['before','after']:
        if not (out / side / name).is_file():
            raise SystemExit(f'Missing real screenshot: {side}/{name}')
    sections.append(f'<section data-scale="{scale}"><h2>{w} × {h} · texto {scale}%</h2><div class="pair">' +
        ''.join(f'<figure><figcaption>{label}</figcaption><a href="{side}/{name}"><img loading="lazy" src="{side}/{name}" alt="{label} {w} por {h}, texto {scale} por ciento"></a></figure>' for side,label in [('before','Antes · 4D.1'),('after','Después · 4D.1.1')]) + '</div></section>')
(out / 'index.html').write_text("""<!doctype html><html lang="es"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Lucky Palace · revisión responsive</title>
<style>body{background:#120f24;color:#fff1ce;font:16px system-ui;margin:24px auto;max-width:1350px;padding:0 16px}h1{color:#ffd46d}select{font:inherit;padding:12px;background:#30203c;color:white}.pair{display:grid;grid-template-columns:1fr 1fr;gap:20px}figure{margin:0;text-align:center}img{max-width:100%;height:auto;max-height:850px}figcaption{padding:12px}section{border-top:1px solid #795e63;padding:20px 0}a{color:#ffd46d}@media(max-width:600px){.pair{grid-template-columns:1fr}}[hidden]{display:none}</style>
<h1>Lucky Palace · hotfix 4D.1.1</h1><p>Capturas reales de Flutter con Fredoka, Nunito y Material Icons. Mismo fixture: saldo 495, premio 20, coste cobrado 25, neto −5 y 12 giros gratis. No son mediciones Android.</p>
<label>Escala de texto <select id="scale"><option value="all">Todas</option><option>100</option><option>130</option><option>200</option></select></label><p><a href="geometry.json">Rect completos (JSON)</a> · <a href="geometry.csv">Medidas CSV</a></p>
""" + ''.join(sections) + """<script>document.getElementById('scale').onchange=function(){document.querySelectorAll('section').forEach(s=>s.hidden=this.value!=='all'&&s.dataset.scale!==this.value)}</script></html>""", encoding='utf-8')
print(f'Twelve comparisons and 96 Rects: {out / "index.html"}')
