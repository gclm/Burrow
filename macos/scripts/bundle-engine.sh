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
#    that prebuilt ones already exist in the source bin/. Harden the build so it can NEVER
#    silently block the release: GOTOOLCHAIN=local uses the installed Go and fails fast if
#    it's too old, instead of auto-downloading a newer toolchain mid-build (that download
#    hung the first 0.9.0 build); GIT_TERMINAL_PROMPT=0 + </dev/null prevent any wait on an
#    interactive prompt. Release CI pins a Go >= go.mod's requirement via actions/setup-go.
export GOTOOLCHAIN=auto
export GIT_TERMINAL_PROMPT=0
if command -v go >/dev/null 2>&1; then
  # Build UNIVERSAL (arm64 + x86_64) binaries so the engine runs on BOTH Apple
  # Silicon and Intel Macs. The CI runner is Apple Silicon, so a plain `go build`
  # emits arm64-only binaries — and on an Intel Mac the universal app then hangs
  # at init trying to exec an engine it can't run (issue #221). macOS clang is a
  # universal toolchain, so we cross-compile each slice (`clang -arch <arch>`,
  # CGO kept on to preserve gopsutil's native sensors) and lipo them together.
  ( cd "$ENGINE_SRC"
    for pair in status:status-go analyze:analyze-go; do
      cmd="${pair%%:*}"; out="${pair##*:}"
      GOOS=darwin GOARCH=arm64 CGO_ENABLED=1 CC="clang -arch arm64" \
        go build -ldflags="-s -w" -o "bin/$out.arm64" "./cmd/$cmd" </dev/null
      GOOS=darwin GOARCH=amd64 CGO_ENABLED=1 CC="clang -arch x86_64" \
        go build -ldflags="-s -w" -o "bin/$out.amd64" "./cmd/$cmd" </dev/null
      lipo -create -output "bin/$out" "bin/$out.arm64" "bin/$out.amd64"
      rm -f "bin/$out.arm64" "bin/$out.amd64"
    done )
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

# 3. Code-sign the nested Mach-O binaries so the app's own signature validates (--deep).
#    Uses the build's resolved identity when run as a build phase, else ad-hoc ('-').
IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:--}"
for b in status-go analyze-go; do
  codesign --force --sign "$IDENTITY" --timestamp=none "$OUT/bin/$b" 2>/dev/null \
    || codesign --force --sign - --timestamp=none "$OUT/bin/$b" || true
done

echo "bundled engine -> $OUT ($(du -sh "$OUT" 2>/dev/null | awk '{print $1}'); signed with '${IDENTITY}')"
