#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <version> <github-owner/repo> <output-dir>" >&2
    exit 2
fi

VERSION="${1#v}"
REPOSITORY="$2"
OUTPUT_DIR="$3"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
PLUGIN_DIR="$PROJECT_DIR/koocomic.koplugin"
RELEASE_NOTES_FILE="$PROJECT_DIR/release-notes/v${VERSION}.json"
ARCHIVE_NAME="koocomic.koplugin-v${VERSION}.zip"
RELEASE_DIR="$OUTPUT_DIR/release"
PAGES_DIR="$OUTPUT_DIR/pages"
TEMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

META_VERSION="$(sed -n 's/^[[:space:]]*version[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$PLUGIN_DIR/_meta.lua")"
CODE_VERSION="$(sed -n 's/^[[:space:]]*version[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$PLUGIN_DIR/koobone/plugin_version.lua")"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Version must use X.Y.Z format" >&2
    exit 1
fi
if [[ "$META_VERSION" != "$VERSION" || "$CODE_VERSION" != "$VERSION" ]]; then
    echo "Version mismatch: tag=$VERSION meta=$META_VERSION code=$CODE_VERSION" >&2
    exit 1
fi
if [[ ! -f "$PLUGIN_DIR/main.lua" || ! -f "$PLUGIN_DIR/_meta.lua" ]]; then
    echo "Plugin entry files are missing" >&2
    exit 1
fi
if [[ ! -f "$RELEASE_NOTES_FILE" ]]; then
    echo "Release notes are missing: $RELEASE_NOTES_FILE" >&2
    exit 1
fi

mkdir -p "$RELEASE_DIR" "$PAGES_DIR" "$TEMP_DIR/koocomic.koplugin"
cp -R "$PLUGIN_DIR/." "$TEMP_DIR/koocomic.koplugin/"
find "$TEMP_DIR/koocomic.koplugin" -name '.DS_Store' -delete
find "$TEMP_DIR/koocomic.koplugin" -type f \( -name '*.log' -o -name '*.part' -o -name '*.tmp' \) -delete
rm -f "$RELEASE_DIR/$ARCHIVE_NAME" "$RELEASE_DIR/$ARCHIVE_NAME.sha256"

(
    cd "$TEMP_DIR"
    zip -q -r "$RELEASE_DIR/$ARCHIVE_NAME" koocomic.koplugin
)

SHA256="$(shasum -a 256 "$RELEASE_DIR/$ARCHIVE_NAME" | awk '{print $1}')"
SIZE="$(wc -c < "$RELEASE_DIR/$ARCHIVE_NAME" | tr -d ' ')"
URL_REPOSITORY="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe="/"))' "$REPOSITORY")"
PACKAGE_URL="https://github.com/${URL_REPOSITORY}/releases/download/v${VERSION}/${ARCHIVE_NAME}"

printf '%s  %s\n' "$SHA256" "$ARCHIVE_NAME" > "$RELEASE_DIR/$ARCHIVE_NAME.sha256"
python3 - "$VERSION" "$PACKAGE_URL" "$SIZE" "$SHA256" \
    "$(TZ=Asia/Shanghai date +%Y-%m-%d)" "$RELEASE_NOTES_FILE" "$PAGES_DIR/update.json" \
    "$RELEASE_DIR/release-notes.md" <<'PY'
import json
import pathlib
import sys

version, package_url, size, sha256, published_at, notes_path, output_path, markdown_path = sys.argv[1:]
with open(notes_path, "r", encoding="utf-8") as handle:
    release_notes = json.load(handle)

if release_notes.get("version") != version:
    raise SystemExit("Release notes version does not match package version")
summary = release_notes.get("summary")
notes = release_notes.get("notes")
if not isinstance(summary, str) or not summary.strip():
    raise SystemExit("Release notes summary is required")
if not isinstance(notes, list) or not notes or not all(isinstance(note, str) and note.strip() for note in notes):
    raise SystemExit("Release notes must contain at least one non-empty note")

manifest = {
    "version": version,
    "channel": "stable",
    "package_type": "full",
    "package_url": package_url,
    "size": int(size),
    "sha256": sha256,
    "published_at": published_at,
    "summary": summary.strip(),
    "notes": [note.strip() for note in notes],
}
pathlib.Path(output_path).write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
markdown = [summary.strip(), ""]
markdown.extend(f"- {note.strip()}" for note in notes)
pathlib.Path(markdown_path).write_text("\n".join(markdown) + "\n", encoding="utf-8")
PY

cp "$PAGES_DIR/update.json" "$RELEASE_DIR/update.json"

echo "Created $RELEASE_DIR/$ARCHIVE_NAME"
echo "SHA-256 $SHA256"
