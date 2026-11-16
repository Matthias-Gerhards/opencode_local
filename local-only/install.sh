#!/usr/bin/env bash
# local-only: Testfassung von install.bat (gleiche Abläufe, auf macOS/Linux ausführbar). Nicht Teil der ZIP.
# Fragt Organisations_Name, Model_Name, Model_Url und Windows_Username ab, erzeugt opencode.jsonc aus der Vorlage
# opencode.jsonc_template neben dem Skript und kopiert sie nach <USERS_DIR>/<Windows_Username>/.config/opencode/
# (install.bat: C:\Users). Die Vorlage wird nie geändert; eine vorhandene opencode.jsonc wird an beiden Orten
# vorher als opencode.jsonc.bak gesichert (überschreibt die Sicherung des vorigen Laufs).
# USERS_DIR (Standard: Elternordner von $HOME) zum Testen umbiegen, damit die eigene Config unberührt bleibt.
set -euo pipefail

cd "$(dirname "$0")"
template=opencode.jsonc_template
config=opencode.jsonc
backup=opencode.jsonc.bak

if [ ! -f "$template" ]; then
  echo "Error: $template not found next to install script." >&2
  exit 1
fi

ask() {
  local value=""
  while [ -z "$value" ]; do read -r -p "$1: " value; done
  printf '%s' "$value"
}

Organisations_Name="$(ask Organisations_Name)"
Model_Name="$(ask Model_Name)"
Model_Url="$(ask Model_Url)"
# Enter = angemeldeter Benutzer
read -r -p "Windows_Username [$USER]: " Windows_Username
Windows_Username="${Windows_Username:-$USER}"
users_dir="${USERS_DIR:-$(dirname "$HOME")}"

# Werte landen in JSON-Strings: " und \ würden die Datei zerstören
for value in "$Organisations_Name" "$Model_Name" "$Model_Url"; do
  case "$value" in
    *\"* | *\\*) echo "Error: values must not contain \" or \\." >&2; exit 1 ;;
  esac
done
case "$Model_Url" in
  http://* | https://*) ;;
  *) echo "Error: Model_Url must start with http:// or https://." >&2; exit 1 ;;
esac
# In Windows verbotene Zeichen ablehnen (verhindert auch Pfade wie ../x); Benutzerordner muss existieren
# (wird nie angelegt, sonst entstünde bei Tippfehlern still ein falscher Ordner)
case "$Windows_Username" in
  *[\\/:*?\<\>\|\[\]\;=,+\"]* | . | ..) echo "Error: invalid Windows_Username." >&2; exit 1 ;;
esac
if [ ! -d "$users_dir/$Windows_Username" ]; then
  echo "Error: $users_dir/$Windows_Username does not exist." >&2
  exit 1
fi

if [ -f "$config" ]; then
  cp "$config" "$backup"
  echo "Backup: $backup"
fi

# Wörtlich ersetzen (index() statt Regex, Werte über ENVIRON, damit & / \ nichts bedeuten).
# Nicht ${var//…}: Bash 3.2 (macOS) behandelt Quotes darin falsch.
export Organisations_Name Model_Name Model_Url
awk '
  function replace(s, from, to,   out, i) {
    out = ""
    while ((i = index(s, from)) > 0) { out = out substr(s, 1, i - 1) to; s = substr(s, i + length(from)) }
    return out s
  }
  {
    line = replace($0, "Organisation LLM", ENVIRON["Organisations_Name"])
    line = replace(line, "model-id", ENVIRON["Model_Name"])
    print replace(line, "http://llm.intern:8000/v1", ENVIRON["Model_Url"])
  }
' "$template" > "$config"

echo "Written: $config"

# Nur .config/opencode bei Bedarf anlegen
target_dir="$users_dir/$Windows_Username/.config/opencode"
mkdir -p "$target_dir"
if [ -f "$target_dir/opencode.jsonc" ]; then
  cp "$target_dir/opencode.jsonc" "$target_dir/opencode.jsonc.bak"
  echo "Backup: $target_dir/opencode.jsonc.bak"
fi
cp "$config" "$target_dir/opencode.jsonc"
echo "Copied to: $target_dir/opencode.jsonc"
