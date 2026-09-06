"""Read-only validation of the newly built Android archive against current config."""
from pathlib import Path
import hashlib
import json
import sys
import zipfile

root = Path(__file__).resolve().parents[1]
apk = Path(sys.argv[1])
with zipfile.ZipFile(apk) as archive:
    assert archive.testzip() is None, "corrupt ZIP entry"
    names = archive.namelist()
    assert "lib/arm64-v8a/libgodot_android.so" in names
    assert not any(name.startswith("assets/tests/") or name.startswith("assets/temp/") for name in names)
    for table in ("cards", "global"):
        entry = next(name for name in names if name.endswith(f"runtime/config/{table}.json"))
        assert json.loads(archive.read(entry)) == json.loads((root / f"runtime/config/{table}.json").read_text(encoding="utf-8")), f"stale {table} configuration"
    assert any("account_identity_rpc" in name for name in names), "missing independent identity RPC bridge"
    assert any("profile_sync_rules" in name for name in names), "missing profile merge rules"
print(json.dumps({"apk": str(apk.resolve()), "bytes": apk.stat().st_size, "sha256": hashlib.file_digest(apk.open("rb"), "sha256").hexdigest(), "config_and_archive": "PASS"}, ensure_ascii=False))
