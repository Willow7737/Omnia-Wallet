#!/usr/bin/env bash
# Render the preview screenshots one screen at a time.
#
# `golden_preview_test.dart` writes each PNG a few seconds into its test body,
# but on a machine with no GPU the test then stalls in teardown until the
# per-test timeout. Rather than pay ten minutes per screen, this driver runs
# each preview on its own and kills it as soon as its file appears.
#
# Usage: tool/shoot_previews.sh [light|dim] [max-parallel]
set -u

THEME="${1:-light}"
PARALLEL="${2:-4}"
OUT="build/preview"
SCREENS=(home activity news notifications profile send receive settings
         contacts governance network safety transaction about)

mkdir -p "$OUT"

shoot() {
  local screen="$1"
  local file="$OUT/${THEME}_${screen}.png"
  rm -f "$file"

  flutter test --tags preview --run-skipped \
    --plain-name "preview ${screen} (${THEME})" \
    test/golden_preview_test.dart >/dev/null 2>&1 &
  local pid=$!

  # Give it up to 3 minutes to produce the file, then stop the run either way.
  for _ in $(seq 1 180); do
    [ -s "$file" ] && break
    kill -0 "$pid" 2>/dev/null || break
    sleep 1
  done

  kill "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null

  if [ -s "$file" ]; then echo "ok   $screen"; else echo "MISS $screen"; fi
}

running=0
for screen in "${SCREENS[@]}"; do
  shoot "$screen" &
  running=$((running + 1))
  if [ "$running" -ge "$PARALLEL" ]; then
    wait -n 2>/dev/null || wait
    running=$((running - 1))
  fi
done
wait

echo "--- ${THEME}: $(ls "$OUT" | grep -c "^${THEME}_") of ${#SCREENS[@]} rendered"
