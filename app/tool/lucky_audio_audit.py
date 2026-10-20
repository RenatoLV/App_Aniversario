"""Copy five existing SFX into an ignored audition page; never changes assignments."""
from pathlib import Path
import json
import shutil
import wave

app = Path(__file__).resolve().parent.parent
out = app / 'build/previews/lucky-stage4d1'
(out / 'audio').mkdir(parents=True, exist_ok=True)
rows = []
for name in ['paper.wav', 'place.wav', 'coin.wav', 'reveal.wav', 'spring.wav']:
    source = app / 'assets/audio' / name
    shutil.copyfile(source, out / 'audio' / name)
    with wave.open(str(source)) as sound:
        rows.append(dict(file=name, seconds=round(sound.getnframes()/sound.getframerate(), 3), sampleRate=sound.getframerate(), channels=sound.getnchannels()))
(out / 'audio-metadata.json').write_text(json.dumps(rows, indent=2), encoding='utf-8')
cards = ''.join(f'<article><h2>{r["file"]}</h2><p>{r["seconds"]} s · {r["sampleRate"]} Hz · {r["channels"]} canales</p><audio controls preload="none" src="audio/{r["file"]}"></audio><p>{"Actual al confirmar una ronda." if r["file"] == "paper.wav" else "Candidato sin asignación nueva."}</p></article>' for r in rows)
(out / 'audio-audit.html').write_text('''<!doctype html><html lang="es"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Audición Lucky Palace 4D.1</title><style>body{background:#171328;color:#fff4de;font:18px system-ui;max-width:850px;margin:30px auto;padding:16px}article{padding:16px;margin:14px 0;border:2px solid #dca343;border-radius:18px}audio{width:100%}</style><h1>Efectos existentes — revisión pendiente</h1><p>La inspección técnica no acredita calidad a oído. Solo paper.wav conserva su asignación de ronda. Escucha originales y compara; los candidatos no se han conectado al juego.</p>''' + cards + '''<script>document.querySelectorAll('audio').forEach(a=>{a.volume=.5;a.addEventListener('play',()=>document.querySelectorAll('audio').forEach(b=>{if(b!==a)b.pause()}))});</script></html>''', encoding='utf-8')
print(out / 'audio-audit.html')
