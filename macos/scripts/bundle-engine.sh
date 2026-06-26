#!/usr/bin/env bash
#
# bundle-engine.sh — stage the burrow-engine RUNTIME into the app's Resources/engine.
#
# Bundling the MIT engine inside Burrow.app means users run our engine with zero install and
# never touch upstream (GPL) mo. Only runtime files travel (entrypoint + lib + the two Go
# binaries + LICENSE) — no Go source.
#
# Usage: bundle-engine.sh <ENGINE_SRC> <RESOURCES_DIR>
#   ENGINE_SRC     a burrow-engine checkout (has mole, lib/, cmd/, go.mod)
#   RESOURCES_DIR  the app bundle's Resources dir (engine/ is created inside it)
set -euo pipefail

ENGINE_SRC="${1:?engine source dir required}"
RESOURCES="${2:?resources dir required}"
OUT="$RESOURCES/engine"

# 1. Build the Go binaries (status-go, analyze-go) if Go is available; otherwise require
#    that prebuilt ones already exist in the source bin/.
if command -v go >/dev/null 2>&1; then
  ( cd "$ENGINE_SRC" \
      && go build -ldflags="-s -w" -o bin/status-go ./cmd/status \
      && go build -ldflags="-s -w" -o bin/analyze-go ./cmd/analyze )
fi
for b in status-go analyze-go; do
  [ -x "$ENGINE_SRC/bin/$b" ] || { echo "error: $ENGINE_SRC/bin/$b missing (need Go to build)"; exit 1; }
done

# 2. Copy only the runtime: entrypoint, shell libs, the two binaries, and the MIT LICENSE.
rm -rf "$OUT"
mkdir -p "$OUT/bin"
cp "$ENGINE_SRC/mole" "$OUT/"
[ -f "$ENGINE_SRC/mo" ] && cp "$ENGINE_SRC/mo" "$OUT/"
cp -R "$ENGINE_SRC/lib" "$OUT/"
cp "$ENGINE_SRC"/bin/*.sh "$OUT/bin/" 2>/dev/null || true
cp "$ENGINE_SRC/bin/status-go" "$ENGINE_SRC/bin/analyze-go" "$OUT/bin/"
cp "$ENGINE_SRC/LICENSE" "$OUT/LICENSE"
chmod +x "$OUT/mole" "$OUT/bin/"* 2>/dev/null || true
[ -f "$OUT/mo" ] && chmod +x "$OUT/mo"

echo "bundled engine -> $OUT ($(du -sh "$OUT" 2>/dev/null | awk '{print $1}'))"
