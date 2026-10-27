#!/usr/bin/env bash
# Static checks for the whole repo (also run by CI):
#   QML (qmllint, against Quickshell's type info), shell scripts (sh -n /
#   ShellCheck errors), the Hyprland Lua config, and translation files.
#   ./scripts/lint.sh [path-to-quickshell-qml-imports]
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
QS_IMPORTS=${1:-/usr/lib/qt6/qml}
QMLLINT=$(command -v qmllint6 || command -v qmllint || echo /usr/lib/qt6/bin/qmllint)
fail=0
note() { printf '\033[1m:: %s\033[0m\n' "$*"; }

note "QML"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/qs"
cp -r shell/* "$tmp/qs/"
for d in services components modules windows settings; do
    (cd "$tmp/qs/$d" && { echo "module qs.$d"; for f in *.qml; do
        n=${f%.qml}
        if grep -q "pragma Singleton" "$f"; then echo "singleton $n 1.0 $f"; else echo "$n 1.0 $f"; fi
    done; } > qmldir)
done
# Syntax errors and undefined names fail; type-info gaps in Quickshell's
# dynamic types are expected and ignored.
out=$("$QMLLINT" -I "$tmp" -I "$QS_IMPORTS" "$tmp"/qs/shell.qml "$tmp"/qs/*/*.qml 2>&1 \
      | grep -E "^(Error|Warning)" | grep -E "SyntaxError|Expected token|Unexpected token|is not defined|Unterminated|Duplicate" || true)
if [ -n "$out" ]; then echo "$out" | sed "s|$tmp/||g"; fail=1; else echo "ok"; fi

note "Shell scripts"
for f in bin/* scripts/*.sh system/usr/lib/foxtail/*; do
    [ -f "$f" ] || continue
    head -1 "$f" | grep -qE '^#!.*(ba)?sh' || continue
    if head -1 "$f" | grep -q bash; then bash -n "$f" || fail=1; else sh -n "$f" || fail=1; fi
    if command -v shellcheck >/dev/null; then shellcheck -S error "$f" || fail=1; fi
done
echo "ok"

note "Hyprland config (Lua)"
if command -v luac >/dev/null; then luac -p hypr/*.lua && echo ok || fail=1; else echo "luac not installed, skipped"; fi

note "Translations"
python3 - "$ROOT" <<'PY' || fail=1
import json, re, glob, sys
root = sys.argv[1]
keys = set()
for f in glob.glob(f"{root}/shell/**/*.qml", recursive=True):
    keys |= set(re.findall(r'I18n\.tr\("((?:[^"\\]|\\.)*)"\)', open(f, encoding="utf-8").read()))
bad = False
for f in sorted(glob.glob(f"{root}/shell/i18n/*.json")):
    t = json.load(open(f, encoding="utf-8"))
    for k, v in t.items():
        if k.count("%1") != v.count("%1"):
            print(f"{f}: placeholder mismatch in {k!r}"); bad = True
    missing = [k for k in keys if k.replace("\\n", "\n") not in t and len(k) > 1]
    print(f"{f.split('/')[-1]}: {len(t)} strings, {len(missing)} untranslated")
sys.exit(1 if bad else 0)
PY

[ $fail = 0 ] && note "All checks passed" || note "Some checks failed"
exit $fail
