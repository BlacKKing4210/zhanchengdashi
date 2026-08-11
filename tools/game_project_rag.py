#!/usr/bin/env python3
"""Deterministic mandatory RAG for producer-led game projects."""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import math
import os
import re
import shutil
import sqlite3
import sys
import zipfile
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable
from xml.etree import ElementTree as ET


TOOL_VERSION = "1.0.0"
MANIFEST_COLUMNS = [
    "source_id",
    "path",
    "kind",
    "authority",
    "status",
    "version",
    "owner",
    "feature_ids",
    "tags",
    "updated_at",
    "expires_at",
    "access_scope",
    "conflict_group",
    "resolution_state",
]
KINDS = {"workflow", "design", "config", "code", "art", "qa", "pm", "deployment", "research"}
AUTHORITIES = {"canonical", "approved", "supporting", "generated"}
STATUSES = {"active", "draft", "superseded", "disabled"}
ACCESS_SCOPES = {"project", "public"}
RESOLUTION_STATES = {"", "resolved", "unresolved"}
AUTHORITY_BONUS = {"canonical": 0.050, "approved": 0.030, "supporting": 0.012, "generated": 0.0}
TEXT_EXTENSIONS = {
    ".md",
    ".txt",
    ".csv",
    ".json",
    ".yaml",
    ".yml",
    ".toml",
    ".ini",
    ".cfg",
    ".xml",
    ".html",
    ".css",
    ".gd",
    ".tscn",
    ".tres",
    ".godot",
    ".js",
    ".jsx",
    ".ts",
    ".tsx",
    ".cs",
    ".cpp",
    ".c",
    ".h",
    ".hpp",
    ".py",
    ".ps1",
    ".sh",
    ".java",
    ".kt",
    ".shader",
    ".glsl",
    ".sql",
}
DOCUMENT_EXTENSIONS = {".docx", ".pdf", ".xlsx"}
SECRET_PATH_PARTS = {
    ".env",
    "credentials",
    "credential",
    "secrets",
    "secret",
    "private_key",
    "private-key",
    "id_rsa",
    "id_ed25519",
    ".ssh",
    "cookies",
    "tokens",
}
WORD_RE = re.compile(r"[^\W_]+", re.UNICODE)
CJK_RE = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]+")


class RagError(RuntimeError):
    """Fail-closed RAG error."""


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise RagError(f"invalid JSON {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise RagError(f"JSON root must be an object: {path}")
    return value


def rel_posix(path: Path, root: Path) -> str:
    return path.resolve().relative_to(root.resolve()).as_posix()


def project_path(root: Path, relative: str) -> Path:
    value = str(relative or "").strip().replace("\\", "/")
    if not value:
        raise RagError("empty project-relative path")
    candidate = Path(value)
    if candidate.is_absolute():
        raise RagError(f"absolute path is forbidden: {value}")
    resolved = (root / candidate).resolve()
    try:
        resolved.relative_to(root.resolve())
    except ValueError as exc:
        raise RagError(f"path escapes project root: {value}") from exc
    return resolved


def split_ids(value: str) -> list[str]:
    return sorted({item.strip() for item in str(value or "").split(";") if item.strip()})


def parse_time(value: str) -> dt.datetime | None:
    text = str(value or "").strip()
    if not text:
        return None
    normalized = text.replace("Z", "+00:00")
    try:
        parsed = dt.datetime.fromisoformat(normalized)
    except ValueError as exc:
        raise RagError(f"invalid ISO date/time: {text}") from exc
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed.astimezone(dt.timezone.utc)


def load_config(root: Path) -> tuple[dict[str, Any], Path]:
    path = root / "knowledge" / "rag_config.json"
    config = read_json(path)
    if config.get("schema_version") != 1:
        raise RagError("rag_config.json schema_version must be 1")
    required_sections = ("chunking", "retrieval", "evaluation")
    for section in required_sections:
        if not isinstance(config.get(section), dict):
            raise RagError(f"rag_config.json missing object: {section}")
    if config["retrieval"].get("embedding_provider") != "hashing-ngrams-v1":
        raise RagError("unsupported embedding_provider; expected hashing-ngrams-v1")
    if config["retrieval"].get("reranker") != "authority-feature-overlap-v1":
        raise RagError("unsupported reranker; expected authority-feature-overlap-v1")
    for key in ("index_path", "gate_receipt_path", "task_receipt_dir", "context_dir"):
        project_path(root, str(config.get(key) or ""))
    return config, path


def secret_like_path(relative: str) -> bool:
    lowered = relative.replace("\\", "/").casefold()
    parts = {part for part in lowered.split("/") if part}
    if parts.intersection(SECRET_PATH_PARTS):
        return True
    name = Path(lowered).name
    return name.startswith(".env.") or name.endswith((".pem", ".key", ".p12", ".pfx"))


def load_manifest(root: Path) -> tuple[list[dict[str, str]], Path]:
    path = root / "knowledge" / "knowledge_manifest.csv"
    try:
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            if reader.fieldnames != MANIFEST_COLUMNS:
                raise RagError(
                    "knowledge_manifest.csv columns must exactly match: " + ",".join(MANIFEST_COLUMNS)
                )
            rows = [{key: str(row.get(key) or "").strip() for key in MANIFEST_COLUMNS} for row in reader]
    except OSError as exc:
        raise RagError(f"cannot read manifest: {exc}") from exc
    if not rows:
        raise RagError("knowledge_manifest.csv has no sources")

    errors: list[str] = []
    ids: set[str] = set()
    paths: set[str] = set()
    conflict_groups: dict[str, list[dict[str, str]]] = defaultdict(list)
    now = dt.datetime.now(dt.timezone.utc)
    for index, row in enumerate(rows, start=2):
        prefix = f"manifest row {index}"
        source_id = row["source_id"]
        normalized_path = row["path"].replace("\\", "/").casefold()
        if not source_id:
            errors.append(f"{prefix}: missing source_id")
        elif source_id in ids:
            errors.append(f"{prefix}: duplicate source_id {source_id}")
        ids.add(source_id)
        if not normalized_path:
            errors.append(f"{prefix}: missing path")
        elif normalized_path in paths:
            errors.append(f"{prefix}: duplicate path {row['path']}")
        paths.add(normalized_path)
        for field, allowed in (
            ("kind", KINDS),
            ("authority", AUTHORITIES),
            ("status", STATUSES),
            ("access_scope", ACCESS_SCOPES),
            ("resolution_state", RESOLUTION_STATES),
        ):
            if row[field] not in allowed:
                errors.append(f"{prefix}: invalid {field}={row[field]}")
        try:
            source_path = project_path(root, row["path"])
        except RagError as exc:
            errors.append(f"{prefix}: {exc}")
            continue
        if secret_like_path(row["path"]):
            errors.append(f"{prefix}: secret-like path is forbidden: {row['path']}")
        if row["status"] == "active":
            if not source_path.is_file():
                errors.append(f"{prefix}: active source missing: {row['path']}")
            elif source_path.suffix.casefold() not in TEXT_EXTENSIONS | DOCUMENT_EXTENSIONS:
                errors.append(f"{prefix}: unsupported active source type: {source_path.suffix}")
            try:
                expiry = parse_time(row["expires_at"])
                parse_time(row["updated_at"])
            except RagError as exc:
                errors.append(f"{prefix}: {exc}")
                expiry = None
            if row["kind"] == "research" and not row["expires_at"]:
                errors.append(f"{prefix}: active research requires expires_at")
            if expiry is not None and expiry <= now:
                errors.append(f"{prefix}: active source expired at {row['expires_at']}")
            if row["conflict_group"]:
                conflict_groups[row["conflict_group"]].append(row)

    for group, members in sorted(conflict_groups.items()):
        if len(members) > 1 and any(row["resolution_state"] != "resolved" for row in members):
            names = ",".join(row["source_id"] for row in members)
            errors.append(f"unresolved conflict_group {group}: {names}")
    if errors:
        raise RagError("; ".join(errors))
    return rows, path


def active_sources(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    return [row for row in rows if row["status"] == "active"]


def decode_text(path: Path) -> str:
    data = path.read_bytes()
    for encoding in ("utf-8-sig", "utf-16", "gb18030"):
        try:
            return data.decode(encoding)
        except UnicodeDecodeError:
            continue
    raise RagError(f"unsupported text encoding: {path}")


def xml_text(element: ET.Element) -> str:
    return "".join(text for text in element.itertext() if text)


def extract_docx(path: Path) -> list[tuple[str, str]]:
    try:
        with zipfile.ZipFile(path) as archive:
            root = ET.fromstring(archive.read("word/document.xml"))
    except (OSError, KeyError, zipfile.BadZipFile, ET.ParseError) as exc:
        raise RagError(f"cannot parse DOCX {path}: {exc}") from exc
    paragraphs: list[str] = []
    for element in root.iter():
        if element.tag.endswith("}p"):
            text = xml_text(element).strip()
            if text:
                paragraphs.append(text)
    return [("paragraphs", "\n".join(paragraphs))]


def extract_pdf(path: Path) -> list[tuple[str, str]]:
    try:
        from pypdf import PdfReader  # type: ignore
    except ImportError as exc:
        raise RagError("PDF source requires pypdf; install it or provide an approved text sidecar") from exc
    try:
        reader = PdfReader(str(path))
        return [(f"page {index}", page.extract_text() or "") for index, page in enumerate(reader.pages, start=1)]
    except Exception as exc:  # pypdf exposes several parser exception types
        raise RagError(f"cannot parse PDF {path}: {exc}") from exc


def extract_xlsx(path: Path) -> list[tuple[str, str]]:
    namespaces = {
        "main": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
        "rel": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
        "pkg": "http://schemas.openxmlformats.org/package/2006/relationships",
    }
    try:
        with zipfile.ZipFile(path) as archive:
            names = set(archive.namelist())
            shared: list[str] = []
            if "xl/sharedStrings.xml" in names:
                root = ET.fromstring(archive.read("xl/sharedStrings.xml"))
                shared = [xml_text(item) for item in root.findall("main:si", namespaces)]
            workbook = ET.fromstring(archive.read("xl/workbook.xml"))
            relationships = ET.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
            targets = {
                item.attrib["Id"]: item.attrib["Target"]
                for item in relationships.findall("pkg:Relationship", namespaces)
            }
            segments: list[tuple[str, str]] = []
            for sheet in workbook.findall("main:sheets/main:sheet", namespaces):
                name = sheet.attrib.get("name", "Sheet")
                relationship_id = sheet.attrib.get(f"{{{namespaces['rel']}}}id", "")
                target = targets.get(relationship_id, "")
                target = target.lstrip("/")
                if not target.startswith("xl/"):
                    target = "xl/" + target
                worksheet = ET.fromstring(archive.read(target))
                lines: list[str] = []
                for row in worksheet.findall(".//main:row", namespaces):
                    values: list[str] = []
                    for cell in row.findall("main:c", namespaces):
                        cell_type = cell.attrib.get("t", "")
                        value_node = cell.find("main:v", namespaces)
                        if cell_type == "inlineStr":
                            inline = cell.find("main:is", namespaces)
                            value = xml_text(inline) if inline is not None else ""
                        elif value_node is None:
                            value = ""
                        elif cell_type == "s":
                            try:
                                value = shared[int(value_node.text or "0")]
                            except (ValueError, IndexError):
                                value = value_node.text or ""
                        else:
                            value = value_node.text or ""
                        values.append(value)
                    if any(values):
                        lines.append("\t".join(values))
                segments.append((f"sheet {name}", "\n".join(lines)))
            return segments
    except (OSError, KeyError, zipfile.BadZipFile, ET.ParseError) as exc:
        raise RagError(f"cannot parse XLSX {path}: {exc}") from exc


def extract_segments(path: Path) -> list[tuple[str, str]]:
    suffix = path.suffix.casefold()
    if suffix in TEXT_EXTENSIONS:
        return [("lines", decode_text(path))]
    if suffix == ".docx":
        return extract_docx(path)
    if suffix == ".pdf":
        return extract_pdf(path)
    if suffix == ".xlsx":
        return extract_xlsx(path)
    raise RagError(f"unsupported source type: {suffix}")


def locate(base: str, text: str, start: int, end: int) -> str:
    if base == "lines":
        begin = text.count("\n", 0, start) + 1
        finish = text.count("\n", 0, end) + 1
        return f"lines {begin}-{finish}"
    if base == "paragraphs":
        begin = text.count("\n", 0, start) + 1
        finish = text.count("\n", 0, end) + 1
        return f"paragraphs {begin}-{finish}"
    return f"{base}, chars {start + 1}-{end}"


def chunk_segment(
    text: str,
    base: str,
    target_chars: int,
    overlap_chars: int,
    min_chars: int,
) -> list[tuple[str, str]]:
    normalized = text.replace("\r\n", "\n").replace("\r", "\n").strip()
    if not normalized:
        return []
    chunks: list[tuple[str, str]] = []
    start = 0
    while start < len(normalized):
        proposed = min(len(normalized), start + target_chars)
        end = proposed
        if proposed < len(normalized):
            candidates = [
                normalized.rfind("\n", start + min_chars, proposed),
                normalized.rfind(" ", start + min_chars, proposed),
            ]
            boundary = max(candidates)
            if boundary > start:
                end = boundary
        content = normalized[start:end].strip()
        if content and (len(content) >= min_chars or not chunks):
            chunks.append((locate(base, normalized, start, end), content))
        if end >= len(normalized):
            break
        next_start = max(start + 1, end - overlap_chars)
        start = next_start
    return chunks


def search_tokens(text: str) -> list[str]:
    lowered = text.casefold()
    tokens: list[str] = []
    for match in WORD_RE.finditer(lowered):
        word = match.group(0)
        if CJK_RE.fullmatch(word):
            chars = list(word)
            tokens.extend(chars)
            for size in (2, 3):
                tokens.extend("".join(chars[index : index + size]) for index in range(len(chars) - size + 1))
        else:
            tokens.append(word)
    return tokens


def fts_text(text: str) -> str:
    return " ".join(search_tokens(text))


def hashed_vector(
    counts: Counter[str],
    document_frequency: dict[str, int],
    document_count: int,
    dimensions: int,
) -> dict[int, float]:
    vector: dict[int, float] = defaultdict(float)
    for token, count in counts.items():
        digest = hashlib.blake2b(token.encode("utf-8"), digest_size=8).digest()
        raw = int.from_bytes(digest, "big", signed=False)
        index = raw % dimensions
        sign = 1.0 if raw & 1 else -1.0
        idf = math.log((document_count + 1) / (document_frequency.get(token, 0) + 1)) + 1.0
        weight = (1.0 + math.log(max(count, 1))) * idf * sign
        vector[index] += weight
    norm = math.sqrt(sum(value * value for value in vector.values())) or 1.0
    return {index: value / norm for index, value in vector.items() if value}


def cosine(left: dict[int, float], right: dict[int, float]) -> float:
    if len(left) > len(right):
        left, right = right, left
    return sum(value * right.get(index, 0.0) for index, value in left.items())


def index_signature(
    manifest_hash: str,
    config_hash: str,
    sources: list[dict[str, Any]],
    chunk_count: int,
) -> str:
    payload = {
        "tool_version": TOOL_VERSION,
        "manifest_hash": manifest_hash,
        "config_hash": config_hash,
        "sources": [(item["source_id"], item["sha256"]) for item in sources],
        "chunk_count": chunk_count,
        "embedding_provider": "hashing-ngrams-v1",
        "reranker": "authority-feature-overlap-v1",
    }
    return sha256_bytes(json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8"))


def initialize_project(root: Path) -> dict[str, Any]:
    assets = Path(__file__).resolve().parents[1] / "assets"
    knowledge = root / "knowledge"
    knowledge.mkdir(parents=True, exist_ok=True)
    date = dt.date.today().isoformat()
    mapping = {
        "knowledge_manifest.template.csv": knowledge / "knowledge_manifest.csv",
        "rag_config.template.json": knowledge / "rag_config.json",
        "golden_queries.template.csv": knowledge / "golden_queries.csv",
        "knowledge-readme.template.md": knowledge / "README.md",
    }
    created: list[str] = []
    skipped: list[str] = []
    for source_name, destination in mapping.items():
        if destination.exists():
            skipped.append(rel_posix(destination, root))
            continue
        content = (assets / source_name).read_text(encoding="utf-8").replace("{{DATE}}", date)
        destination.write_text(content, encoding="utf-8")
        created.append(rel_posix(destination, root))
    ignore = knowledge / ".gitignore"
    if not ignore.exists():
        ignore.write_text("index/\n", encoding="utf-8")
        created.append(rel_posix(ignore, root))
    tool_destination = root / "tools" / "game_project_rag.py"
    tool_source = Path(__file__).resolve()
    if not tool_destination.exists():
        tool_destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(tool_source, tool_destination)
        created.append(rel_posix(tool_destination, root))
    else:
        skipped.append(rel_posix(tool_destination, root))
    return {"status": "READY", "created": created, "skipped": skipped}


def build_index(root: Path) -> dict[str, Any]:
    config, config_path = load_config(root)
    manifest, manifest_path = load_manifest(root)
    sources = active_sources(manifest)
    if not sources:
        raise RagError("manifest has no active sources")
    chunking = config["chunking"]
    target_chars = int(chunking.get("target_chars", 1600))
    overlap_chars = int(chunking.get("overlap_chars", 240))
    min_chars = int(chunking.get("min_chars", 80))
    if target_chars < 200 or overlap_chars < 0 or overlap_chars >= target_chars or min_chars < 1:
        raise RagError("invalid chunking configuration")
    dimensions = int(config["retrieval"].get("vector_dimensions", 2048))
    if dimensions < 256:
        raise RagError("vector_dimensions must be at least 256")

    chunk_rows: list[dict[str, Any]] = []
    source_receipts: list[dict[str, Any]] = []
    for source in sources:
        path = project_path(root, source["path"])
        source_hash = sha256_file(path)
        source_receipts.append(
            {
                "source_id": source["source_id"],
                "path": source["path"].replace("\\", "/"),
                "sha256": source_hash,
                "version": source["version"],
                "authority": source["authority"],
            }
        )
        ordinal = 0
        for base, text in extract_segments(path):
            for locator_value, content in chunk_segment(
                text, base, target_chars, overlap_chars, min_chars
            ):
                ordinal += 1
                chunk_id = sha256_bytes(
                    f"{source['source_id']}|{source_hash}|{ordinal}|{locator_value}".encode("utf-8")
                )[:24]
                chunk_rows.append(
                    {
                        "chunk_id": chunk_id,
                        "source_id": source["source_id"],
                        "path": source["path"].replace("\\", "/"),
                        "locator": locator_value,
                        "chunk_index": ordinal,
                        "content": content,
                        "search_text": fts_text(
                            " ".join(
                                [
                                    source["source_id"],
                                    source["path"],
                                    source["kind"],
                                    source["feature_ids"],
                                    source["tags"],
                                    content,
                                ]
                            )
                        ),
                        "authority": source["authority"],
                        "kind": source["kind"],
                        "status": source["status"],
                        "version": source["version"],
                        "owner": source["owner"],
                        "feature_ids": source["feature_ids"],
                        "tags": source["tags"],
                        "sha256": source_hash,
                        "updated_at": source["updated_at"],
                        "expires_at": source["expires_at"],
                    }
                )
        if ordinal == 0:
            raise RagError(f"active source produced no indexable text: {source['path']}")

    token_counts: dict[str, Counter[str]] = {}
    document_frequency: Counter[str] = Counter()
    for row in chunk_rows:
        counts = Counter(search_tokens(row["content"]))
        token_counts[row["chunk_id"]] = counts
        document_frequency.update(counts.keys())
    document_count = len(chunk_rows)
    if document_count == 0:
        raise RagError("no chunks were produced")

    manifest_hash = sha256_file(manifest_path)
    config_hash = sha256_file(config_path)
    signature = index_signature(manifest_hash, config_hash, source_receipts, document_count)
    index_path = project_path(root, str(config["index_path"]))
    index_path.parent.mkdir(parents=True, exist_ok=True)
    temporary = index_path.with_suffix(index_path.suffix + ".tmp")
    if temporary.exists():
        temporary.unlink()
    connection = sqlite3.connect(temporary)
    try:
        connection.executescript(
            """
            PRAGMA journal_mode=OFF;
            PRAGMA synchronous=FULL;
            CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
            CREATE TABLE chunks (
                chunk_id TEXT PRIMARY KEY,
                source_id TEXT NOT NULL,
                path TEXT NOT NULL,
                locator TEXT NOT NULL,
                chunk_index INTEGER NOT NULL,
                content TEXT NOT NULL,
                authority TEXT NOT NULL,
                kind TEXT NOT NULL,
                status TEXT NOT NULL,
                version TEXT NOT NULL,
                owner TEXT NOT NULL,
                feature_ids TEXT NOT NULL,
                tags TEXT NOT NULL,
                sha256 TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                expires_at TEXT NOT NULL
            );
            CREATE VIRTUAL TABLE chunks_fts USING fts5(
                chunk_id UNINDEXED,
                source_id,
                path,
                content,
                search_text,
                tokenize='unicode61 remove_diacritics 2'
            );
            CREATE TABLE vectors (
                chunk_id TEXT PRIMARY KEY,
                vector_json TEXT NOT NULL
            );
            CREATE TABLE term_df (
                token TEXT PRIMARY KEY,
                df INTEGER NOT NULL
            );
            """
        )
        metadata = {
            "schema_version": "1",
            "tool_version": TOOL_VERSION,
            "created_at": utc_now(),
            "project_root": str(root.resolve()),
            "manifest_hash": manifest_hash,
            "config_hash": config_hash,
            "index_signature": signature,
            "embedding_provider": "hashing-ngrams-v1",
            "reranker": "authority-feature-overlap-v1",
            "vector_dimensions": str(dimensions),
            "document_count": str(document_count),
            "sources_json": json.dumps(source_receipts, ensure_ascii=False, sort_keys=True),
        }
        connection.executemany("INSERT INTO metadata(key, value) VALUES (?, ?)", metadata.items())
        for row in chunk_rows:
            connection.execute(
                """
                INSERT INTO chunks VALUES (
                    :chunk_id, :source_id, :path, :locator, :chunk_index, :content,
                    :authority, :kind, :status, :version, :owner, :feature_ids,
                    :tags, :sha256, :updated_at, :expires_at
                )
                """,
                row,
            )
            connection.execute(
                "INSERT INTO chunks_fts VALUES (?, ?, ?, ?, ?)",
                (row["chunk_id"], row["source_id"], row["path"], row["content"], row["search_text"]),
            )
            vector = hashed_vector(token_counts[row["chunk_id"]], document_frequency, document_count, dimensions)
            connection.execute(
                "INSERT INTO vectors VALUES (?, ?)",
                (row["chunk_id"], json.dumps(sorted(vector.items()), separators=(",", ":"))),
            )
        connection.executemany(
            "INSERT INTO term_df(token, df) VALUES (?, ?)", sorted(document_frequency.items())
        )
        connection.commit()
    finally:
        connection.close()
    os.replace(temporary, index_path)
    return {
        "status": "READY",
        "index_path": rel_posix(index_path, root),
        "index_signature": signature,
        "source_count": len(sources),
        "chunk_count": document_count,
        "sources": source_receipts,
        "manifest_hash": manifest_hash,
        "config_hash": config_hash,
    }


def index_metadata(connection: sqlite3.Connection) -> dict[str, str]:
    return {key: value for key, value in connection.execute("SELECT key, value FROM metadata")}


def verify_index(root: Path) -> dict[str, Any]:
    config, config_path = load_config(root)
    manifest, manifest_path = load_manifest(root)
    sources = active_sources(manifest)
    index_path = project_path(root, str(config["index_path"]))
    if not index_path.is_file():
        raise RagError(f"index missing: {rel_posix(index_path, root)}")
    try:
        connection = sqlite3.connect(f"file:{index_path.as_posix()}?mode=ro", uri=True)
        metadata = index_metadata(connection)
        connection.close()
    except sqlite3.Error as exc:
        raise RagError(f"invalid RAG index: {exc}") from exc
    if metadata.get("schema_version") != "1" or metadata.get("tool_version") != TOOL_VERSION:
        raise RagError("index schema or tool version is stale")
    if metadata.get("manifest_hash") != sha256_file(manifest_path):
        raise RagError("manifest changed after indexing")
    if metadata.get("config_hash") != sha256_file(config_path):
        raise RagError("RAG config changed after indexing")
    try:
        indexed_sources = json.loads(metadata.get("sources_json", "[]"))
    except json.JSONDecodeError as exc:
        raise RagError("index source metadata is invalid") from exc
    expected = {item["source_id"]: item for item in indexed_sources}
    current_receipts: list[dict[str, Any]] = []
    errors: list[str] = []
    for source in sources:
        path = project_path(root, source["path"])
        current_hash = sha256_file(path)
        indexed = expected.get(source["source_id"])
        if indexed is None:
            errors.append(f"active source missing from index: {source['source_id']}")
        elif indexed.get("path") != source["path"].replace("\\", "/"):
            errors.append(f"source path changed after indexing: {source['source_id']}")
        elif indexed.get("sha256") != current_hash:
            errors.append(f"source changed after indexing: {source['source_id']} ({source['path']})")
        current_receipts.append(
            {
                "source_id": source["source_id"],
                "path": source["path"].replace("\\", "/"),
                "sha256": current_hash,
                "version": source["version"],
                "authority": source["authority"],
            }
        )
    if set(expected) != {source["source_id"] for source in sources}:
        errors.append("active source set changed after indexing")
    if errors:
        raise RagError("; ".join(errors))
    return {
        "status": "READY",
        "index_path": rel_posix(index_path, root),
        "index_signature": metadata["index_signature"],
        "manifest_hash": metadata["manifest_hash"],
        "config_hash": metadata["config_hash"],
        "source_count": len(current_receipts),
        "chunk_count": int(metadata["document_count"]),
        "sources": current_receipts,
        "embedding_provider": metadata["embedding_provider"],
        "reranker": metadata["reranker"],
    }


def load_vector(value: str) -> dict[int, float]:
    return {int(index): float(weight) for index, weight in json.loads(value)}


def retrieve(
    root: Path,
    query: str,
    feature_ids: Iterable[str] = (),
    top_k: int | None = None,
) -> dict[str, Any]:
    if not query.strip():
        raise RagError("query must not be empty")
    verification = verify_index(root)
    config, _ = load_config(root)
    retrieval = config["retrieval"]
    lexical_k = int(retrieval.get("lexical_k", 24))
    vector_k = int(retrieval.get("vector_k", 24))
    final_k = int(top_k or retrieval.get("final_k", 8))
    rrf_k = int(retrieval.get("rrf_k", 60))
    index_path = project_path(root, str(config["index_path"]))
    connection = sqlite3.connect(f"file:{index_path.as_posix()}?mode=ro", uri=True)
    connection.row_factory = sqlite3.Row
    try:
        tokens = search_tokens(query)
        if not tokens:
            raise RagError("query produced no searchable tokens")
        unique_tokens = list(dict.fromkeys(tokens))[:64]
        match = " OR ".join('"' + token.replace('"', '""') + '"' for token in unique_tokens)
        lexical_rows = connection.execute(
            """
            SELECT chunk_id, bm25(chunks_fts) AS lexical_score
            FROM chunks_fts
            WHERE chunks_fts MATCH ?
            ORDER BY lexical_score
            LIMIT ?
            """,
            (match, lexical_k),
        ).fetchall()
        lexical_rank = {row["chunk_id"]: rank for rank, row in enumerate(lexical_rows, start=1)}

        metadata = index_metadata(connection)
        document_count = int(metadata["document_count"])
        dimensions = int(metadata["vector_dimensions"])
        df = {
            token: int(value)
            for token, value in connection.execute(
                f"SELECT token, df FROM term_df WHERE token IN ({','.join('?' for _ in unique_tokens)})",
                unique_tokens,
            )
        }
        query_vector = hashed_vector(Counter(tokens), df, document_count, dimensions)
        vector_scores: list[tuple[str, float]] = []
        for row in connection.execute("SELECT chunk_id, vector_json FROM vectors"):
            score = cosine(query_vector, load_vector(row["vector_json"]))
            if score > 0:
                vector_scores.append((row["chunk_id"], score))
        vector_scores.sort(key=lambda item: (-item[1], item[0]))
        vector_scores = vector_scores[:vector_k]
        vector_rank = {chunk_id: rank for rank, (chunk_id, _) in enumerate(vector_scores, start=1)}
        vector_score_map = dict(vector_scores)

        candidates = sorted(set(lexical_rank) | set(vector_rank))
        if not candidates:
            return {
                "status": "NOT READY",
                "query": query,
                "index_signature": verification["index_signature"],
                "hits": [],
                "errors": ["no retrieval hits"],
            }
        placeholders = ",".join("?" for _ in candidates)
        rows = connection.execute(
            f"SELECT * FROM chunks WHERE chunk_id IN ({placeholders})", candidates
        ).fetchall()
        requested_features = {item for item in feature_ids if item}
        query_set = set(tokens)
        hits: list[dict[str, Any]] = []
        for row in rows:
            lexical_position = lexical_rank.get(row["chunk_id"])
            vector_position = vector_rank.get(row["chunk_id"])
            rrf = 0.0
            if lexical_position is not None:
                rrf += 1.0 / (rrf_k + lexical_position)
            if vector_position is not None:
                rrf += 1.0 / (rrf_k + vector_position)
            chunk_features = set(split_ids(row["feature_ids"]))
            feature_bonus = 0.0
            if requested_features.intersection(chunk_features):
                feature_bonus = 0.040
            elif "GLOBAL" in chunk_features:
                feature_bonus = 0.015
            chunk_tokens = set(search_tokens(row["content"]))
            overlap = len(query_set.intersection(chunk_tokens)) / max(len(query_set), 1)
            overlap_bonus = min(0.030, overlap * 0.030)
            score = rrf + AUTHORITY_BONUS.get(row["authority"], 0.0) + feature_bonus + overlap_bonus
            hits.append(
                {
                    "chunk_id": row["chunk_id"],
                    "source_id": row["source_id"],
                    "path": row["path"],
                    "locator": row["locator"],
                    "content": row["content"],
                    "authority": row["authority"],
                    "kind": row["kind"],
                    "status": row["status"],
                    "version": row["version"],
                    "owner": row["owner"],
                    "feature_ids": split_ids(row["feature_ids"]),
                    "tags": split_ids(row["tags"]),
                    "sha256": row["sha256"],
                    "lexical_rank": lexical_position,
                    "vector_rank": vector_position,
                    "vector_score": round(vector_score_map.get(row["chunk_id"], 0.0), 8),
                    "overlap": round(overlap, 8),
                    "score": round(score, 8),
                }
            )
        hits.sort(key=lambda item: (-item["score"], item["source_id"], item["chunk_id"]))
        return {
            "status": "READY",
            "query": query,
            "feature_ids": sorted(requested_features),
            "index_signature": verification["index_signature"],
            "embedding_provider": verification["embedding_provider"],
            "reranker": verification["reranker"],
            "hits": hits[:final_k],
        }
    except sqlite3.Error as exc:
        raise RagError(f"retrieval failed: {exc}") from exc
    finally:
        connection.close()


def load_golden_queries(root: Path) -> tuple[list[dict[str, str]], Path]:
    path = root / "knowledge" / "golden_queries.csv"
    columns = ["query_id", "query", "expected_source_ids", "feature_ids", "min_recall_at_k", "k"]
    try:
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            if reader.fieldnames != columns:
                raise RagError("golden_queries.csv columns must exactly match: " + ",".join(columns))
            rows = [{key: str(row.get(key) or "").strip() for key in columns} for row in reader]
    except OSError as exc:
        raise RagError(f"cannot read golden queries: {exc}") from exc
    if not rows:
        raise RagError("golden_queries.csv has no evaluation queries")
    ids: set[str] = set()
    for row_number, row in enumerate(rows, start=2):
        if not row["query_id"] or row["query_id"] in ids:
            raise RagError(f"golden query row {row_number}: missing or duplicate query_id")
        ids.add(row["query_id"])
        if not row["query"] or not split_ids(row["expected_source_ids"]):
            raise RagError(f"golden query row {row_number}: query and expected_source_ids are required")
        try:
            threshold = float(row["min_recall_at_k"])
            cutoff = int(row["k"])
        except ValueError as exc:
            raise RagError(f"golden query row {row_number}: invalid threshold or k") from exc
        if not 0 <= threshold <= 1 or cutoff < 1:
            raise RagError(f"golden query row {row_number}: threshold must be 0..1 and k >= 1")
    return rows, path


def evaluate(root: Path) -> dict[str, Any]:
    verify_index(root)
    config, _ = load_config(root)
    rows, path = load_golden_queries(root)
    results: list[dict[str, Any]] = []
    for row in rows:
        cutoff = int(row["k"] or config["evaluation"].get("default_k", 5))
        expected = split_ids(row["expected_source_ids"])
        response = retrieve(root, row["query"], split_ids(row["feature_ids"]), cutoff)
        returned = [hit["source_id"] for hit in response["hits"]]
        unique_returned = list(dict.fromkeys(returned))
        matched = sorted(set(expected).intersection(unique_returned))
        recall = len(matched) / len(expected)
        first_rank = next(
            (index for index, source_id in enumerate(returned, start=1) if source_id in expected), None
        )
        reciprocal_rank = 1.0 / first_rank if first_rank else 0.0
        threshold = float(row["min_recall_at_k"])
        results.append(
            {
                "query_id": row["query_id"],
                "query": row["query"],
                "k": cutoff,
                "expected_source_ids": expected,
                "returned_source_ids": unique_returned,
                "matched_source_ids": matched,
                "recall_at_k": round(recall, 8),
                "reciprocal_rank": round(reciprocal_rank, 8),
                "min_recall_at_k": threshold,
                "passed": recall >= threshold,
            }
        )
    mean_recall = sum(item["recall_at_k"] for item in results) / len(results)
    pass_rate = sum(1 for item in results if item["passed"]) / len(results)
    policy = config["evaluation"]
    aggregate_pass = (
        mean_recall >= float(policy.get("min_mean_recall_at_k", 0.8))
        and pass_rate >= float(policy.get("min_pass_rate", 1.0))
    )
    if policy.get("require_all_queries", True):
        aggregate_pass = aggregate_pass and all(item["passed"] for item in results)
    return {
        "passed": aggregate_pass,
        "query_count": len(results),
        "mean_recall_at_k": round(mean_recall, 8),
        "pass_rate": round(pass_rate, 8),
        "golden_queries_hash": sha256_file(path),
        "thresholds": policy,
        "queries": results,
    }


def write_gate(root: Path) -> tuple[dict[str, Any], Path]:
    config, _ = load_config(root)
    gate_path = project_path(root, str(config["gate_receipt_path"]))
    try:
        verification = verify_index(root)
        evaluation = evaluate(root)
        status = "READY" if evaluation["passed"] else "NOT READY"
        errors = [] if evaluation["passed"] else ["golden-query evaluation failed"]
        receipt = {
            "schema_version": 1,
            "status": status,
            "reason": None if status == "READY" else "NOT READY: game project RAG",
            "created_at": utc_now(),
            "project_root": str(root.resolve()),
            "fresh": True,
            "index_signature": verification["index_signature"],
            "manifest_hash": verification["manifest_hash"],
            "config_hash": verification["config_hash"],
            "golden_queries_hash": evaluation["golden_queries_hash"],
            "embedding_provider": verification["embedding_provider"],
            "reranker": verification["reranker"],
            "source_count": verification["source_count"],
            "chunk_count": verification["chunk_count"],
            "sources": verification["sources"],
            "evaluation": evaluation,
            "errors": errors,
        }
    except RagError as exc:
        receipt = {
            "schema_version": 1,
            "status": "NOT READY",
            "reason": "NOT READY: game project RAG",
            "created_at": utc_now(),
            "project_root": str(root.resolve()),
            "fresh": False,
            "sources": [],
            "evaluation": {"passed": False},
            "errors": [str(exc)],
        }
    write_json(gate_path, receipt)
    return receipt, gate_path


def verify_gate(root: Path) -> tuple[dict[str, Any], Path]:
    config, _ = load_config(root)
    gate_path = project_path(root, str(config["gate_receipt_path"]))
    if not gate_path.is_file():
        raise RagError(f"gate receipt missing: {rel_posix(gate_path, root)}")
    gate = read_json(gate_path)
    if gate.get("status") != "READY" or gate.get("fresh") is not True:
        raise RagError("gate receipt is not READY and fresh")
    if not isinstance(gate.get("evaluation"), dict) or gate["evaluation"].get("passed") is not True:
        raise RagError("gate evaluation did not pass")
    verification = verify_index(root)
    if gate.get("project_root") != str(root.resolve()):
        raise RagError("gate project_root does not match")
    if gate.get("index_signature") != verification["index_signature"]:
        raise RagError("gate index signature is stale")
    if gate.get("manifest_hash") != verification["manifest_hash"]:
        raise RagError("gate manifest hash is stale")
    if gate.get("config_hash") != verification["config_hash"]:
        raise RagError("gate config hash is stale")
    golden_rows, golden_path = load_golden_queries(root)
    del golden_rows
    if gate.get("golden_queries_hash") != sha256_file(golden_path):
        raise RagError("golden queries changed after gate evaluation")
    gate_sources = {item.get("source_id"): item for item in gate.get("sources", []) if isinstance(item, dict)}
    for source in verification["sources"]:
        current = gate_sources.get(source["source_id"])
        if current is None or current.get("path") != source["path"] or current.get("sha256") != source["sha256"]:
            raise RagError(f"gate source hash is stale: {source['source_id']}")
    return gate, gate_path


def safe_request_id(value: str) -> str:
    normalized = re.sub(r"[^A-Za-z0-9._-]+", "-", value.strip()).strip(".-")
    if not normalized or normalized != value.strip():
        raise RagError("request-id must use only letters, digits, dot, underscore, or hyphen")
    return normalized


def pack_context(
    root: Path,
    request_id: str,
    query: str,
    feature_ids: list[str],
    top_k: int | None,
) -> dict[str, Any]:
    request_id = safe_request_id(request_id)
    gate, gate_path = verify_gate(root)
    config, _ = load_config(root)
    response = retrieve(root, query, feature_ids, top_k)
    hits = response["hits"]
    if not hits:
        raise RagError("task query returned no cited context")
    max_chars = int(config["retrieval"].get("max_context_chars", 18000))
    selected: list[dict[str, Any]] = []
    used = 0
    for hit in hits:
        metadata_cost = 420
        remaining = max_chars - used - metadata_cost
        if remaining <= 0:
            break
        content = hit["content"]
        if len(content) > remaining:
            content = content[:remaining].rstrip() + "\n[chunk truncated by context budget]"
        selected_hit = {**hit, "content": content}
        selected.append(selected_hit)
        used += len(content) + metadata_cost
    if not selected:
        raise RagError("context budget is too small for one cited chunk")

    context_dir = project_path(root, str(config["context_dir"]))
    task_dir = project_path(root, str(config["task_receipt_dir"]))
    context_path = context_dir / f"{request_id}.md"
    task_path = task_dir / f"{request_id}.json"
    context_dir.mkdir(parents=True, exist_ok=True)
    task_dir.mkdir(parents=True, exist_ok=True)
    lines = [
        f"# RAG Context Pack: {request_id}",
        "",
        f"- Query: {query}",
        f"- Feature IDs: {', '.join(feature_ids) if feature_ids else 'GLOBAL'}",
        f"- Index signature: `{response['index_signature']}`",
        f"- Generated: {utc_now()}",
        "",
        "Use these excerpts as grounded project evidence. Resolve conflicts through formal source authority; do not treat this pack as a new approval.",
        "",
    ]
    citations: list[dict[str, Any]] = []
    for index, hit in enumerate(selected, start=1):
        citation = {
            key: hit[key]
            for key in (
                "chunk_id",
                "source_id",
                "path",
                "locator",
                "authority",
                "kind",
                "version",
                "owner",
                "feature_ids",
                "sha256",
                "score",
                "lexical_rank",
                "vector_rank",
            )
        }
        citations.append(citation)
        lines.extend(
            [
                f"## {index}. {hit['source_id']} — {hit['path']}",
                "",
                (
                    f"Citation: `{hit['source_id']}:{hit['locator']}` | "
                    f"authority `{hit['authority']}` | version `{hit['version']}` | "
                    f"SHA-256 `{hit['sha256']}` | chunk `{hit['chunk_id']}`"
                ),
                "",
                hit["content"],
                "",
            ]
        )
    context_path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
    receipt = {
        "schema_version": 1,
        "status": "READY",
        "created_at": utc_now(),
        "project_root": str(root.resolve()),
        "request_id": request_id,
        "query": query,
        "feature_ids": feature_ids or ["GLOBAL"],
        "gate_receipt": rel_posix(gate_path, root),
        "gate_receipt_sha256": sha256_file(gate_path),
        "index_signature": gate["index_signature"],
        "context_pack": rel_posix(context_path, root),
        "context_pack_sha256": sha256_file(context_path),
        "citation_count": len(citations),
        "citations": citations,
    }
    write_json(task_path, receipt)
    return {
        "status": "READY",
        "request_id": request_id,
        "gate_receipt": rel_posix(gate_path, root),
        "task_receipt": rel_posix(task_path, root),
        "context_pack": rel_posix(context_path, root),
        "index_signature": gate["index_signature"],
        "citation_count": len(citations),
        "citations": citations,
    }


def prepare_project(root: Path) -> dict[str, Any]:
    index_result = build_index(root)
    gate, gate_path = write_gate(root)
    return {
        "status": gate["status"],
        "reason": gate.get("reason"),
        "index": index_result,
        "gate_receipt": rel_posix(gate_path, root),
        "evaluation": gate.get("evaluation"),
        "errors": gate.get("errors", []),
    }


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    subparsers = result.add_subparsers(dest="command", required=True)
    for name in ("init", "ingest", "check", "eval", "gate", "prepare"):
        command = subparsers.add_parser(name)
        command.add_argument("--project-root", required=True)
    query = subparsers.add_parser("query")
    query.add_argument("--project-root", required=True)
    query.add_argument("--query", required=True)
    query.add_argument("--feature-id", action="append", default=[])
    query.add_argument("--top-k", type=int)
    pack = subparsers.add_parser("pack")
    pack.add_argument("--project-root", required=True)
    pack.add_argument("--request-id", required=True)
    pack.add_argument("--query", required=True)
    pack.add_argument("--feature-id", action="append", default=[])
    pack.add_argument("--top-k", type=int)
    return result


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    root = Path(args.project_root).resolve()
    try:
        if not root.is_dir():
            raise RagError(f"project root does not exist: {root}")
        if args.command == "init":
            output = initialize_project(root)
        elif args.command == "ingest":
            output = build_index(root)
        elif args.command == "check":
            output = verify_index(root)
        elif args.command == "eval":
            evaluation = evaluate(root)
            output = {"status": "READY" if evaluation["passed"] else "NOT READY", **evaluation}
        elif args.command == "gate":
            gate, path = write_gate(root)
            output = {**gate, "gate_receipt": rel_posix(path, root)}
        elif args.command == "prepare":
            output = prepare_project(root)
        elif args.command == "query":
            output = retrieve(root, args.query, args.feature_id, args.top_k)
        elif args.command == "pack":
            output = pack_context(root, args.request_id, args.query, args.feature_id, args.top_k)
        else:
            raise RagError(f"unsupported command: {args.command}")
    except (RagError, OSError, UnicodeError, ValueError) as exc:
        output = {
            "status": "NOT READY",
            "reason": "NOT READY: game project RAG",
            "errors": [str(exc)],
        }
        print(json.dumps(output, ensure_ascii=False, indent=2, sort_keys=True))
        return 2
    print(json.dumps(output, ensure_ascii=False, indent=2, sort_keys=True))
    return 0 if output.get("status") == "READY" else 2


if __name__ == "__main__":
    raise SystemExit(main())
