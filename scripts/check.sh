#!/usr/bin/env bash
# Vérification compacte : n'affiche que les erreurs et un résumé.
# Usage : scripts/check.sh [chemin_paquet] [--integration]
set -uo pipefail

TARGET="."
INTEGRATION=0
for arg in "$@"; do
  case "$arg" in
    --integration) INTEGRATION=1 ;;
    *) TARGET="$arg" ;;
  esac
done

cd "$(git rev-parse --show-toplevel)" || exit 1
STATUS=0
MAX_LINES=60

section() { printf '\n== %s ==\n' "$1"; }

# 1. Format
FMT_OUT=$(dart format --output=none --set-exit-if-changed "$TARGET" 2>&1)
if [ $? -ne 0 ]; then
  section "FORMAT"
  echo "$FMT_OUT" | grep -E '^Changed' | head -n 20
  echo "-> lancer: dart format $TARGET"
  STATUS=1
fi

# 2. Analyse
ANA_OUT=$(dart analyze --fatal-infos "$TARGET" 2>&1)
if [ $? -ne 0 ]; then
  section "ANALYZE"
  echo "$ANA_OUT" | grep -E '(error|warning|info) -' | head -n "$MAX_LINES"
  STATUS=1
fi

# 3. Tests (paquets contenant un dossier test/)
run_tests() {
  local pkg="$1"
  [ -d "$pkg/test" ] || return 0
  local args=(--reporter=failures-only)
  if [ "$INTEGRATION" -eq 1 ]; then args+=(-t integration); else args+=(-x integration); fi
  local runner="dart"
  grep -q 'sdk: flutter' "$pkg/pubspec.yaml" 2>/dev/null && runner="flutter"
  local out
  out=$(cd "$pkg" && $runner test "${args[@]}" 2>&1)
  if [ $? -ne 0 ]; then
    section "TEST $pkg"
    echo "$out" | tail -n "$MAX_LINES"
    STATUS=1
  fi
}

if [ -f "$TARGET/pubspec.yaml" ] && [ "$TARGET" != "." ]; then
  run_tests "$TARGET"
else
  for p in packages/* apps/* server/*; do
    [ -f "$p/pubspec.yaml" ] && run_tests "$p"
  done
fi

if [ "$STATUS" -eq 0 ]; then echo "OK ($TARGET$([ $INTEGRATION -eq 1 ] && echo ', integration'))"; else echo; echo "FAIL"; fi
exit "$STATUS"
