"""Generate two one-time device codes and a SQL seed. Run only once."""
import hashlib
import secrets
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CODES = ROOT / "activation.local.txt"
SEED = ROOT / "seed.local.sql"
if CODES.exists() or SEED.exists():
    raise SystemExit("Activation files already exist; refusing to rotate codes.")

space = str(uuid.uuid4())
codes = [("Maru", secrets.token_urlsafe(24)), ("Lady", secrets.token_urlsafe(24))]
CODES.write_text("Space ID: " + space + "\n" +
    "\n".join(f"{name}: {code}" for name, code in codes) + "\n", encoding="utf-8")
rows = []
for slot, (_, code) in enumerate(codes, start=1):
    digest = hashlib.sha256(code.encode("utf-8")).hexdigest()
    rows.append(f"insert into public.activation_codes(space_id,slot,code_hash) "
                f"values ('{space}',{slot},decode('{digest}','hex')) "
                "on conflict (space_id,slot) do nothing;")
SEED.write_text("-- Apply after 001 and 002. Contains hashes, never plaintext codes.\n"
    + f"insert into public.spaces(id,name) values ('{space}','Nuestro rincón') "
      "on conflict (id) do nothing;\n" + "\n".join(rows) + "\n", encoding="utf-8")
print(f"Created {SEED.name} and {CODES.name}. Keep the codes private.")
