"""Build the bounded home overlay from the retained deployed staging source.

No networking, live data, credentials, identity migration or client assets.
Godot export is a separate step; the manifest binds all copied source bytes.
"""
from pathlib import Path
import hashlib
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'temp/release/REQ-20260906-ADMIN-ALL-ANIMALS/source'
ROLLBACK = '--rollback-compatible' in sys.argv
OUT = ROOT / 'temp/release/REQ-20260925-HOME-SERVER'
if ROLLBACK:
    OUT = OUT / 'rollback'
DST = OUT / 'source'
BASE_ELF = BASE.parent / 'artifacts/JungleLawServer.x86_64'
BASE_SHA = '69c33449882ac2409c444af4b9d1e19edfd8e491fa578f2de46a5766e47f7d58'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def text(path, root=ROOT):
    return (root / path).read_text(encoding='utf-8-sig')


def replace_once(source, old, new):
    assert source.count(old) == 1, old[:100]
    return source.replace(old, new, 1)


def block(source, start, end):
    return source[source.index(start):source.index(end)]


def main():
    assert sha(BASE_ELF.read_bytes()) == BASE_SHA
    overrides = {}
    store_path = 'scripts/server/player_account_store.gd'
    current = text(store_path)
    store = text(store_path, BASE)
    store = replace_once(store, 'const DEFAULT_PATH =', 'const HomeRules = preload("res://scripts/shared/home_rules.gd")\n\nconst DEFAULT_PATH =')
    protection = block(current, '\t# Home is exclusively mutated', '\trecord["profile"] = _normalize_profile(profile_source)')
    store = replace_once(store, '\trecord["profile"] = _normalize_profile(profile_source)', protection + '\trecord["profile"] = _normalize_profile(profile_source)')
    home = block(current, 'func _home_today()', 'func _profile_result(')
    if not ROLLBACK:
        store = replace_once(store, 'func _profile_result(', home + 'func _profile_result(')
    overrides[store_path] = store
    adapter_path = 'scripts/server/player_account_profile_adapter.gd'
    # Exactly the old adapter plus wallet and home; independent source check.
    adapter = text(adapter_path, BASE)
    adapter = replace_once(adapter, 'const RANK_NAMES =', 'const HomeRules = preload("res://scripts/shared/home_rules.gd")\n\nconst RANK_NAMES =')
    adapter = replace_once(adapter, '\t\t"rank_stars": maxi(0,', '\t\t"wallet_gold": maxi(0, int(source.get("wallet_gold", 60))),\n\t\t"home": HomeRules.normalize_state(source.get("home", {})),\n\t\t"rank_stars": maxi(0,')
    overrides[adapter_path] = adapter
    network_path = 'scripts/network/online_room.gd'
    network = text(network_path, BASE)
    network = replace_once(network, 'const BattleAnalyticsContract =', 'const HomeRpc = preload("res://scripts/network/home_rpc.gd")\nconst BattleAnalyticsContract =')
    network = replace_once(network, 'var _account_store_factory = Callable()', 'var _account_store_factory = Callable()\nvar server_home_rpc_supported = false\nvar current_home_snapshot: Dictionary = {}')
    network = replace_once(network, 'func _ready() -> void:\n', 'func _ready() -> void:\n\t_home_rpc_node()\n')
    methods = block(text(network_path), 'func _home_rpc_node()', 'func request_player_profile(')
    network = replace_once(network, 'func request_player_profile(', methods + 'func request_player_profile(')
    old_sender = block(network, 'func _send_operation_result(', '\n\nfunc _affected_peer_ids(')
    new_sender = 'func _send_operation_result(peer_id: int, operation: String, result: Dictionary) -> void:\n\tvar response = result.duplicate(true)\n\tresponse["home_rpc_v1"] = true\n\trpc_id(peer_id, "_rpc_receive_operation_result", operation, response)\n'
    network = replace_once(network, old_sender, new_sender)
    network = replace_once(network, 'func _rpc_receive_operation_result(operation: String, result: Dictionary) -> void:\n', 'func _rpc_receive_operation_result(operation: String, result: Dictionary) -> void:\n\tserver_home_rpc_supported = bool(result.get("home_rpc_v1", false))\n')
    network = replace_once(network, '\t\t_client_session_token = String(result.get("session_token", ""))', '\t\tif String(result.get("user_id", "")) != current_user_id:\n\t\t\tcurrent_home_snapshot.clear()\n\t\t_client_session_token = String(result.get("session_token", ""))')
    network = replace_once(network, 'elif operation in ["load_player_profile", "save_player_profile"]:', 'elif operation in ["load_player_profile", "save_player_profile", "home_state", "home_unlock", "home_claim"]:')
    network = replace_once(network, '\t\tcurrent_profile_revision = maxi(0, int(result.get("profile_revision", current_profile_revision)))', '\t\tcurrent_profile_revision = maxi(0, int(result.get("profile_revision", current_profile_revision)))\n\t\tif typeof(result.get("home_snapshot")) == TYPE_DICTIONARY:\n\t\t\tcurrent_home_snapshot = result.home_snapshot.duplicate(true)')
    network = replace_once(network, '\t\t"profile_revision": current_profile_revision,', '\t\t"profile_revision": current_profile_revision,\n\t\t"home_snapshot": current_home_snapshot.duplicate(true),')
    network = replace_once(network, 'func _clear_account_state() -> void:\n', 'func _clear_account_state() -> void:\n\tcurrent_home_snapshot.clear()\n')
    rpc_pattern = r'@rpc[^\n]*\nfunc [^\n]+'
    assert re.findall(rpc_pattern, network) == re.findall(rpc_pattern, text(network_path, BASE))
    assert len(re.findall(rpc_pattern, network)) == 27
    overrides[network_path] = text(network_path, BASE) if ROLLBACK else network
    for path in ('scripts/shared/home_rules.gd', 'scripts/network/home_rpc.gd', 'runtime/config/home_buildings.json', 'runtime/config/home_economy.json'):
        overrides[path] = text(path)

    queue = ['scripts/core/config_db.gd', 'scripts/server/server_main.gd', network_path]
    seen = set()
    entries = []
    while queue:
        path = queue.pop()
        if path in seen:
            continue
        seen.add(path)
        data = overrides[path].encode('utf-8') if path in overrides else (BASE / path).read_bytes()
        target = DST / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        entries.append({'path': path, 'source': 'home_overlay' if path in overrides else 'deployed_baseline', 'sha256': sha(data)})
        for ref in re.findall(r'res://([A-Za-z0-9_./-]+\.(?:gd|json|txt))', data.decode('utf-8-sig')):
            if ref not in seen:
                queue.append(ref)
    for source in (BASE / 'runtime/config').glob('*.json'):
        path = source.relative_to(BASE).as_posix()
        data = source.read_bytes()
        (DST / path).parent.mkdir(parents=True, exist_ok=True)
        (DST / path).write_bytes(data)
        entries.append({'path': path, 'source': 'deployed_baseline', 'sha256': sha(data)})
    for name in ('home_economy', 'home_buildings'):
        path = f'runtime/config/{name}.json'
        data = (ROOT / path).read_bytes()
        (DST / path).write_bytes(data)
        entries.append({'path': path, 'source': 'home_overlay', 'sha256': sha(data)})
    (DST / 'scenes').mkdir(exist_ok=True)
    (DST / 'scenes/server.tscn').write_bytes((BASE / 'scenes/server.tscn').read_bytes())
    (DST / 'project.godot').write_text('''config_version=5
[application]
config/name="丛林法则"
run/main_scene="res://scenes/server.tscn"
config/features=PackedStringArray("4.6")
[autoload]
ConfigDB="*res://scripts/core/config_db.gd"
OnlineRoom="*res://scripts/network/online_room.gd"
[network]
server_host="106.15.61.103"
server_port=24567
[rendering]
renderer/rendering_method="gl_compatibility"
''', encoding='utf-8')
    (DST / 'export_presets.cfg').write_text('''[preset.0]
name="Home Server"
platform="Linux"
runnable=false
dedicated_server=true
custom_features="dedicated_server"
export_filter="all_resources"
include_filter="runtime/config/*.json"
exclude_filter="tests/*,tests/**/*"
export_path="../JungleLawServer-home-v1.0.0-staging.x86_64"
[preset.0.options]
binary_format/embed_pck=true
binary_format/architecture="x86_64"
''', encoding='utf-8')
    manifest = {'baseline_elf_sha256': BASE_SHA, 'parent_rpc_count': 27, 'rollback_compatible': ROLLBACK, 'source_files': entries,
                'excluded': ['identity migration', 'battle changes', 'client art and UI'], 'version': 'home-v1.0.0-staging'}
    (OUT / 'source-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    print('HOME_SERVER_SOURCE_READY', len(entries), DST)


if __name__ == '__main__':
    main()
