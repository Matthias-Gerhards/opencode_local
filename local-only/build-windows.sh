#!/usr/bin/env bash
# local-only: Baut die Windows-Distribution opencode-windows-x64.zip (siehe local-only/FORK-CHANGES.md, Abschnitt 7).
# Läuft auf macOS/Linux, opencode.exe wird per Bun cross-kompiliert. Lädt nichts herunter außer dem, was
# `bun run build` selbst braucht. Aufruf aus beliebigem Verzeichnis:
#
#   local-only/build-windows.sh <pfad/zu/rg.exe> [ausgabeordner]
#
# rg.exe: ripgrep 15.1.0, x86_64-pc-windows-msvc (aus ripgrep-15.1.0-x86_64-pc-windows-msvc.zip,
# Release-Seite von BurntSushi/ripgrep). Die Prüfsumme unten verhindert, dass versehentlich eine andere
# Version oder Architektur in die ZIP gelangt.
set -euo pipefail

RG_SHA256=decdd4992f3f1b9a5ef9898f1b40ab16886d579d6516b4efd3d5eaa19364e408
RG_VERSION=15.1.0

repo="$(cd "$(dirname "$0")/.." && pwd)"
[ -d "$HOME/.bun/bin" ] && PATH="$HOME/.bun/bin:$PATH"

rg_exe="${1:-}"
out="$(mkdir -p "${2:-$repo/local-only/dist}" && cd "${2:-$repo/local-only/dist}" && pwd)"
if [ -z "$rg_exe" ] || [ ! -f "$rg_exe" ]; then
  echo "Aufruf: $0 <pfad/zu/rg.exe> [ausgabeordner]" >&2
  echo "rg.exe: ripgrep $RG_VERSION, ripgrep-$RG_VERSION-x86_64-pc-windows-msvc.zip" >&2
  exit 1
fi
actual="$(shasum -a 256 "$rg_exe" | cut -d' ' -f1)"
if [ "$actual" != "$RG_SHA256" ]; then
  echo "rg.exe hat die falsche Prüfsumme ($actual), erwartet ripgrep $RG_VERSION x86_64-pc-windows-msvc ($RG_SHA256)." >&2
  echo "Bei einer neuen ripgrep-Version RG_SHA256/RG_VERSION hier und rg-Version in local-only/Readme.md anpassen." >&2
  exit 1
fi

cd "$repo"
commit="$(git rev-parse --short HEAD)"
branch="$(git rev-parse --abbrev-ref HEAD)"
dirty=""
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  dirty=" (mit nicht committeten Änderungen)"
  echo "WARNUNG: Arbeitsverzeichnis hat nicht committete Änderungen, sie landen im Build." >&2
fi

build="$(mktemp -d)"
trap 'rm -rf "$build"' EXIT

echo "==> opencode.exe bauen (Branch $branch, Commit $commit$dirty)"
(cd packages/cli && OPENCODE_TARGET=windows-x64 bun run script/build.ts --outdir="$build/cli")

dist="$build/opencode-windows"
mkdir -p "$dist"
cp "$build/cli/cli-windows-x64/bin/opencode.exe" "$dist/"
cp "$rg_exe" "$dist/rg.exe"
# Textdateien mit Windows-Zeilenenden (im Repo LF)
for f in opencode-offline.cmd opencode.jsonc Readme.md; do
  tr -d '\r' < "local-only/$f" | sed 's/$/\r/' > "$dist/$f"
done

echo "==> ZIP packen"
rm -f "$out/opencode-windows-x64.zip"
(cd "$build" && zip -q -r -9 -X "$out/opencode-windows-x64.zip" opencode-windows)
unzip -l "$out/opencode-windows-x64.zip"

echo
echo "Fertig: $out/opencode-windows-x64.zip"
echo "SHA-256: $(shasum -a 256 "$out/opencode-windows-x64.zip" | cut -d' ' -f1)"
echo "Gebaut aus Branch $branch, Commit $commit$dirty"
echo
echo "Veröffentlichen (Branch vorher pushen, Release-Text in notes.md):"
echo "  gh release create local-windows-\$(date +%Y-%m-%d) \"$out/opencode-windows-x64.zip\" \\"
echo "    -R Matthias-Gerhards/opencode_local --target $branch --prerelease \\"
echo "    --title \"opencode local-only für Windows x64 (\$(date +%Y-%m-%d))\" --notes-file notes.md"
