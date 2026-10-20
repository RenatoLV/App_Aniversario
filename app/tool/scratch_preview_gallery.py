"""Gallery from real Flutter screenshots, not mockups. Run after scratch_widget_test."""
import html
import json
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
out = root / 'build/previews/lucky-scratch'
geometry = []
for line in (root / 'build/scratch-pilot.log').read_text(encoding='utf-8').splitlines():
    if 'SCRATCH_GEOMETRY ' in line:
        geometry.append(json.loads(line.split('SCRATCH_GEOMETRY ', 1)[1]))
if len(geometry) != 12:
    raise SystemExit(f'Expected 12 measured layouts, got {len(geometry)}')
(out / 'geometry.json').write_text(json.dumps(geometry, indent=2), encoding='utf-8')
cards = []
for value in geometry:
    width, height, text = int(value['width']), int(value['height']), round(value['text'] * 100)
    figures = []
    for state in ['catalog', 'covered', 'partial', 'revealed']:
        name = f'{state}-{width}-{text}.png'
        if not (out / name).is_file():
            raise SystemExit(f'Missing screenshot: {name}')
        figures.append(f'<figure><a href="{name}"><img loading="lazy" src="{name}" alt="{state}"></a><figcaption>{state}</figcaption></figure>')
    cards.append(f'<section><h2>{width} × {height} · texto {text}%</h2><div>{"".join(figures)}</div></section>')
themes = ''.join(f'<figure><a href="{p.name}"><img src="{p.name}" alt="{html.escape(p.stem)}"></a><figcaption>{html.escape(p.stem)}</figcaption></figure>' for p in sorted(out.glob('theme-*.png')))
(out / 'index.html').write_text('''<!doctype html><html lang="es"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Raspes · Etapa 5</title><style>body{background:#171126;color:#fff2c7;font:16px system-ui;margin:24px}section{margin-bottom:36px}section>div,.themes{display:flex;gap:12px;align-items:start;overflow:auto}figure{margin:0;min-width:180px;max-width:300px}img{width:100%;max-height:580px;object-fit:contain}a{color:#ffd67a}figcaption{padding:8px}h2{font-size:19px}</style><h1>Raspes de Maru y Lady · Etapa 5</h1><p>Capturas reales Flutter. Catálogo → cubierto → trazo parcial → revelado. Cada caso usa el mismo resultado de prueba: premio 3, coste 10, neto −7. No son sorteos del jugador.</p>''' + ''.join(cards) + '<h2>Cinco presentaciones</h2><div class="themes">' + themes + '</div><p><a href="geometry.json">Geometría medida</a></p></html>', encoding='utf-8')
for group, values in [('portrait', [v for v in geometry if v['width'] < v['height']]), ('wide', [v for v in geometry if v['width'] > v['height']])]:
    sheet = Image.new('RGB', (960, 1160 if group == 'portrait' else 620), '#171126')
    draw = ImageDraw.Draw(sheet)
    for i, v in enumerate(values):
        image = Image.open(out / f'covered-{int(v["width"])}-{round(v["text"]*100)}.png').convert('RGB')
        image.thumbnail((310, 540 if group == 'portrait' else 260))
        x, y = (i % 3) * 320, (i // 3) * (580 if group == 'portrait' else 310)
        draw.text((x + 8, y + 6), f'{int(v["width"])}x{int(v["height"])} / {round(v["text"]*100)}%', fill='#fff2c7')
        sheet.paste(image, (x + (320-image.width)//2, y + 28))
    sheet.save(out / f'contact-{group}.png')
print(f'{len(geometry)} layouts, 53 source screenshots, gallery and contact sheets: {out}')
