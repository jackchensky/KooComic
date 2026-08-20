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
PLUGIN_DIR="$PROJECT_DIR/koobone.koplugin"
ARCHIVE_NAME="koobone.koplugin-v${VERSION}.zip"
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

mkdir -p "$RELEASE_DIR" "$PAGES_DIR" "$TEMP_DIR/koobone.koplugin"
cp -R "$PLUGIN_DIR/." "$TEMP_DIR/koobone.koplugin/"
find "$TEMP_DIR/koobone.koplugin" -name '.DS_Store' -delete
find "$TEMP_DIR/koobone.koplugin" -type f \( -name '*.log' -o -name '*.part' -o -name '*.tmp' \) -delete

(
    cd "$TEMP_DIR"
    zip -q -r "$RELEASE_DIR/$ARCHIVE_NAME" koobone.koplugin
)

SHA256="$(shasum -a 256 "$RELEASE_DIR/$ARCHIVE_NAME" | awk '{print $1}')"
SIZE="$(wc -c < "$RELEASE_DIR/$ARCHIVE_NAME" | tr -d ' ')"
PACKAGE_URL="https://github.com/${REPOSITORY}/releases/download/v${VERSION}/${ARCHIVE_NAME}"

printf '%s  %s\n' "$SHA256" "$ARCHIVE_NAME" > "$RELEASE_DIR/$ARCHIVE_NAME.sha256"
printf '{\n  "version": "%s",\n  "channel": "stable",\n  "package_type": "full",\n  "package_url": "%s",\n  "size": %s,\n  "sha256": "%s",\n  "published_at": "%s",\n  "summary": "KOOBONE for KOReader v%s",\n  "notes": ["请在 GitHub Release 页面查看完整更新说明。"]\n}\n' \
    "$VERSION" "$PACKAGE_URL" "$SIZE" "$SHA256" "$(date -u +%Y-%m-%d)" "$VERSION" \
    > "$PAGES_DIR/update.json"

cp "$PAGES_DIR/update.json" "$RELEASE_DIR/update.json"

echo "Created $RELEASE_DIR/$ARCHIVE_NAME"
echo "SHA-256 $SHA256"

