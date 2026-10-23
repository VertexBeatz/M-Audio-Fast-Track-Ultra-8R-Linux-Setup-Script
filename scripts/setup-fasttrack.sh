#!/usr/bin/env bash
set -euo pipefail

CARD="${FASTTRACK_CARD:-F8R}"
BACKUP_DIR="${FASTTRACK_BACKUP_DIR:-$HOME/.local/share/fasttrack-ultra-8r/backups}"

for bin in amixer alsactl; do
  command -v "$bin" >/dev/null || { echo "Missing $bin (install alsa-utils)" >&2; exit 1; }
done

if ! amixer -c "$CARD" info >/dev/null 2>&1; then
  echo "ALSA card '$CARD' not found. Check: aplay -l; cat /proc/asound/cards" >&2
  echo "Override with: FASTTRACK_CARD=<card-id-or-number> $0" >&2
  exit 1
fi

for control in \
  'DIn1 - Out1 Playback Volume' \
  'DIn8 - Out8 Playback Volume' \
  'AIn1 - Out1 Capture Volume' \
  'AIn8 - Out8 Capture Volume' \
  'Effect Send AIn1 Volume' \
  'Effect Send DIn8 Volume' \
  'Effect Return 4 Volume'; do
  if ! amixer -c "$CARD" cget "name=$control" >/dev/null 2>&1; then
    echo "Missing expected mixer control: $control" >&2
    echo "No settings changed. Verify Fast Track Ultra 8R ALSA controls." >&2
    exit 1
  fi
done

mkdir -p "$BACKUP_DIR"
backup="$BACKUP_DIR/fasttrack-before-$(date +%Y%m%d-%H%M%S)-$$.state"
alsactl -f "$backup" store "$CARD"
echo "Existing mixer state backed up: $backup"
echo "WARNING: Changing mixer routes may change speaker levels abruptly."
if [[ "${1:-}" != "--yes" ]]; then
  read -r -p 'Turn monitors down. Press Enter to apply, Ctrl+C to cancel: '
fi

# Host playback: one-to-one routing
for input in {1..8}; do
  for output in {1..8}; do
    level=0
    if (( input == output )); then level=32768; fi
    amixer -q -c "$CARD" cset "name=DIn${input} - Out${output} Playback Volume" "$level"
  done
done

# Turn off analog hardware direct monitoring
for input in {1..8}; do
  for output in {1..8}; do
    amixer -q -c "$CARD" cset "name=AIn${input} - Out${output} Capture Volume" 0
  done
done

# Turn off DSP effects sends and returns
for type in AIn DIn; do
  for input in {1..8}; do
    amixer -q -c "$CARD" cset "name=Effect Send ${type}${input} Volume" 0
  done
done
for output in {1..4}; do
  amixer -q -c "$CARD" cset "name=Effect Return ${output} Volume" 0
done

echo 'Applied 1:1 digital outputs; disabled analog monitoring and DSP effects.'
echo 'Capture inputs remain available to JACK/PipeWire. Enable monitoring in Renoise.'
echo "Persist with: sudo alsactl store"
echo "Rollback with: alsactl -f '$backup' restore '$CARD'"
