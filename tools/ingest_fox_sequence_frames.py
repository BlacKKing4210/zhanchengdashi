from __future__ import annotations

import argparse
import hashlib
import json
import os
import stat
import tempfile
import zipfile
from io import BytesIO
from pathlib import Path, PurePosixPath

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
APPROVED_OUTPUT_ROOT = (ROOT / "assets" / "animal_sequences" / "fox").resolve()
APPROVED_MANIFEST = (ROOT / "assets" / "animal_sequences" / "manifest.json").resolve()
EXPECTED_ARCHIVE_SHA256 = "3235d0961681105b7f0f31a924c5bd4f255f6eb3de435a1e04e857973501c0b6"
EXPECTED_ARCHIVE_SIZE = 3_454_652
FRAME_SIZE = (836, 480)
SOURCE_RECT = [230, 50, 410, 410]
BOTTOM_PADDING_RATIO = 80.0 / 410.0

ACTION_SPECS = {
    "狐狸待机1": {"id": "idle", "count": 13, "mode": "loop", "fps": 10.0},
    "狐狸行走": {"id": "move", "count": 15, "mode": "loop", "fps": 15.0},
    "狐狸施法": {"id": "attack", "count": 10, "mode": "motion_progress"},
}


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def decoded_name(info: zipfile.ZipInfo) -> str:
    name = info.filename
    if not (info.flag_bits & 0x800):
        try:
            name = name.encode("cp437").decode("utf-8")
        except (UnicodeEncodeError, UnicodeDecodeError) as exc:
            raise ValueError(f"zip_filename_encoding_invalid:{info.filename!r}") from exc
    return name


def validate_member_name(name: str) -> PurePosixPath:
    if "\\" in name or "\x00" in name:
        raise ValueError(f"unsafe_zip_member:{name!r}")
    path = PurePosixPath(name)
    if path.is_absolute() or not path.parts or any(part in ("", ".", "..") for part in path.parts):
        raise ValueError(f"unsafe_zip_member:{name!r}")
    return path


def is_zip_symlink(info: zipfile.ZipInfo) -> bool:
    mode = (info.external_attr >> 16) & 0xFFFF
    return stat.S_IFMT(mode) == stat.S_IFLNK


def inspect_archive(archive: Path) -> tuple[dict[str, list[tuple[int, bytes, str]]], dict]:
    if not archive.is_file():
        raise FileNotFoundError(archive)
    if archive.stat().st_size != EXPECTED_ARCHIVE_SIZE:
        raise ValueError(f"archive_size_mismatch:{archive.stat().st_size}")
    archive_sha = sha256_file(archive)
    if archive_sha != EXPECTED_ARCHIVE_SHA256:
        raise ValueError(f"archive_sha256_mismatch:{archive_sha}")

    grouped: dict[str, list[tuple[int, bytes, str]]] = {key: [] for key in ACTION_SPECS}
    seen: set[str] = set()
    with zipfile.ZipFile(archive) as bundle:
        for info in bundle.infolist():
            if info.flag_bits & 0x1:
                raise ValueError("encrypted_zip_member_not_allowed")
            if is_zip_symlink(info):
                raise ValueError(f"zip_symlink_not_allowed:{info.filename!r}")
            name = decoded_name(info)
            validate_member_name(name)
            if name in seen:
                raise ValueError(f"duplicate_zip_member:{name}")
            seen.add(name)
            path = PurePosixPath(name)
            if info.is_dir():
                if len(path.parts) != 1 or path.parts[0] not in ACTION_SPECS:
                    raise ValueError(f"unexpected_zip_directory:{name}")
                continue
            if len(path.parts) != 2 or path.parts[0] not in ACTION_SPECS:
                raise ValueError(f"unexpected_zip_file:{name}")
            if path.suffix.lower() != ".png":
                raise ValueError(f"unexpected_frame_extension:{name}")
            prefix = f"{path.parts[0]}_"
            if not path.stem.startswith(prefix):
                raise ValueError(f"unexpected_frame_name:{name}")
            try:
                index = int(path.stem[len(prefix) :])
            except ValueError as exc:
                raise ValueError(f"invalid_frame_index:{name}") from exc
            data = bundle.read(info)
            with Image.open(BytesIO(data)) as image:
                image.load()
                if image.format != "PNG" or image.mode != "RGBA" or image.size != FRAME_SIZE:
                    raise ValueError(
                        f"frame_contract_mismatch:{name}:{image.format}:{image.mode}:{image.size}"
                    )
                alpha = image.getchannel("A")
                if alpha.getbbox() is None:
                    raise ValueError(f"empty_alpha_frame:{name}")
                edge_alpha = max(
                    alpha.crop((0, 0, FRAME_SIZE[0], 1)).getextrema()[1],
                    alpha.crop((0, FRAME_SIZE[1] - 1, FRAME_SIZE[0], FRAME_SIZE[1])).getextrema()[1],
                    alpha.crop((0, 0, 1, FRAME_SIZE[1])).getextrema()[1],
                    alpha.crop((FRAME_SIZE[0] - 1, 0, FRAME_SIZE[0], FRAME_SIZE[1])).getextrema()[1],
                )
                if edge_alpha != 0:
                    raise ValueError(f"non_transparent_canvas_edge:{name}:{edge_alpha}")
            grouped[path.parts[0]].append((index, data, sha256_bytes(data)))

    total = 0
    for raw_action, spec in ACTION_SPECS.items():
        frames = sorted(grouped[raw_action], key=lambda item: item[0])
        expected_indices = list(range(1, int(spec["count"]) + 1))
        indices = [item[0] for item in frames]
        if indices != expected_indices:
            raise ValueError(f"frame_sequence_gap:{raw_action}:{indices}")
        grouped[raw_action] = frames
        total += len(frames)
    if total != 38:
        raise ValueError(f"unexpected_total_frame_count:{total}")
    return grouped, {"sha256": archive_sha, "size": archive.stat().st_size}


def build_manifest(grouped: dict[str, list[tuple[int, bytes, str]]], archive_meta: dict) -> dict:
    actions: dict[str, dict] = {}
    frame_sha256: dict[str, str] = {}
    for raw_action, spec in ACTION_SPECS.items():
        action_id = str(spec["id"])
        frames = [
            f"res://assets/animal_sequences/fox/{action_id}/frame_{index:03d}.png"
            for index, _data, _sha in grouped[raw_action]
        ]
        action = {
            "mode": str(spec["mode"]),
            "frames": frames,
        }
        if "fps" in spec:
            action["fps"] = float(spec["fps"])
        actions[action_id] = action
        for path, (_index, _data, digest) in zip(frames, grouped[raw_action], strict=True):
            frame_sha256[path] = digest
    return {
        "version": 1,
        "source": {
            "archive_name": "狐狸远程.zip",
            "archive_size": int(archive_meta["size"]),
            "archive_sha256": str(archive_meta["sha256"]),
            "rights_status": "user_supplied_for_project_integration_public_release_review_required",
        },
        "animals": {
            "fox": {
                "frame_size": list(FRAME_SIZE),
                "source_rect": SOURCE_RECT,
                "bottom_padding_ratio": BOTTOM_PADDING_RATIO,
                "actions": actions,
                "frame_sha256": frame_sha256,
            }
        },
    }


def expected_output_files(grouped: dict[str, list[tuple[int, bytes, str]]]) -> dict[Path, bytes]:
    result: dict[Path, bytes] = {}
    for raw_action, spec in ACTION_SPECS.items():
        action_id = str(spec["id"])
        for index, data, _digest in grouped[raw_action]:
            result[Path(action_id) / f"frame_{index:03d}.png"] = data
    return result


def verify_existing(output_root: Path, manifest_path: Path, files: dict[Path, bytes], manifest_bytes: bytes) -> None:
    if not output_root.is_dir() or not manifest_path.is_file():
        raise ValueError("existing_ingest_missing")
    actual_files = sorted(path.relative_to(output_root) for path in output_root.rglob("*") if path.is_file())
    expected_sources = set(files)
    actual_sources = {path for path in actual_files if path.suffix.lower() == ".png"}
    allowed_imports = {Path(f"{path.as_posix()}.import") for path in expected_sources}
    unexpected_files = set(actual_files) - expected_sources - allowed_imports
    if actual_sources != expected_sources or unexpected_files:
        raise ValueError(
            "existing_file_set_mismatch:"
            f"sources={sorted(actual_sources)}:unexpected={sorted(unexpected_files)}"
        )
    for relative, data in files.items():
        if sha256_file(output_root / relative) != sha256_bytes(data):
            raise ValueError(f"existing_frame_hash_mismatch:{relative.as_posix()}")
    if manifest_path.read_bytes() != manifest_bytes:
        raise ValueError("existing_manifest_mismatch")


def install(output_root: Path, manifest_path: Path, files: dict[Path, bytes], manifest_bytes: bytes) -> None:
    if output_root.exists() or manifest_path.exists():
        raise FileExistsError("refusing_to_overwrite_existing_sequence_assets")
    parent = output_root.parent
    parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix=".fox-sequence-ingest-", dir=parent))
    stage_fox = stage / "fox"
    stage_manifest = stage / "manifest.json"
    stage_fox.mkdir()
    for relative, data in files.items():
        target = stage_fox / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open("xb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        if sha256_file(target) != sha256_bytes(data):
            raise OSError(f"staged_frame_readback_failed:{relative.as_posix()}")
    with stage_manifest.open("xb") as handle:
        handle.write(manifest_bytes)
        handle.flush()
        os.fsync(handle.fileno())
    if stage_manifest.read_bytes() != manifest_bytes:
        raise OSError("staged_manifest_readback_failed")
    os.rename(stage_manifest, manifest_path)
    try:
        os.rename(stage_fox, output_root)
    except Exception:
        manifest_path.unlink(missing_ok=True)
        raise
    stage.rmdir()


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate and ingest the approved fox sequence archive.")
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--output-root", type=Path, default=APPROVED_OUTPUT_ROOT)
    parser.add_argument("--manifest-output", type=Path, default=APPROVED_MANIFEST)
    parser.add_argument("--check-only", action="store_true")
    parser.add_argument("--verify-existing", action="store_true")
    args = parser.parse_args()

    output_root = args.output_root.resolve()
    manifest_path = args.manifest_output.resolve()
    if output_root != APPROVED_OUTPUT_ROOT or manifest_path != APPROVED_MANIFEST:
        raise ValueError("output_path_outside_approved_project_contract")
    if args.check_only and args.verify_existing:
        raise ValueError("choose_check_only_or_verify_existing")

    grouped, archive_meta = inspect_archive(args.archive.resolve())
    manifest = build_manifest(grouped, archive_meta)
    manifest_bytes = (json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode("utf-8")
    files = expected_output_files(grouped)

    if args.check_only:
        print(json.dumps({"status": "VALID", "frames": len(files), "archive": archive_meta}, sort_keys=True))
        return 0
    if args.verify_existing:
        verify_existing(output_root, manifest_path, files, manifest_bytes)
        print(json.dumps({"status": "MATCH", "frames": len(files)}, sort_keys=True))
        return 0
    install(output_root, manifest_path, files, manifest_bytes)
    verify_existing(output_root, manifest_path, files, manifest_bytes)
    print(json.dumps({"status": "INSTALLED", "frames": len(files)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
