#!/bin/bash
# Benchmark: how smooth is the Mission Control animation, with the border running or not.
#
#   scripts/bench-mission-control.sh [runs]            (default 3 runs)
#
# Run it once with dotborder running and once without it (`launchctl bootout gui/$(id -u)/<your label>`, or
# `pkill -f dotborder.app/Contents/MacOS/dotborder`), then compare. It records the screen with `screencapture -v` (the
# terminal needs the Screen Recording permission), opens Mission Control 1.2 s into the recording, closes it again, and
# measures the motion with ffmpeg's signalstats: a frame "moves" when its YDIF (mean luma change from the previous frame)
# is above 0.4. Per run it prints the span from the first moving frame until a 250 ms gap, the number of moving frames, and
# the number of frames of the whole recording. A smooth animation has many moving frames; dropped frames show as few
# moving frames, a short span, or a recording with fewer frames than the others.
#
# Needs: ffmpeg, and the "Mission Control" app (`open -a "Mission Control"` toggles it).
set -u

runs="${1:-3}"
duration=5
trigger=1.2
dir="$(mktemp -d)"
trap 'rm -rf "$dir"' EXIT   # the recording shows the whole screen: do not leave it behind
file="$dir/mc.mov"

command -v ffmpeg >/dev/null || { echo "ffmpeg is needed" >&2; exit 1; }

# Mission Control is open when the WindowManager owns a "Spaces Bar" window.
mc_open() {
  swift - <<'EOF' 2>/dev/null
import CoreGraphics
let list = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]) ?? []
let open = list.contains { ($0[kCGWindowName as String] as? String) == "Spaces Bar" }
print(open ? "open" : "closed")
EOF
}

for run in $(seq 1 "$runs"); do
  if [ "$(mc_open)" = open ]; then open -a "Mission Control"; sleep 1.5; fi
  rm -f "$file"
  screencapture -v -V "$duration" "$file" &
  capture=$!
  sleep "$trigger"
  open -a "Mission Control"
  sleep 2
  open -a "Mission Control"
  wait "$capture"
  sleep 1

  ffmpeg -hide_banner -loglevel error -i "$file" -vf "signalstats,metadata=print:key=lavfi.signalstats.YDIF:file=-" -f null - 2>/dev/null |
    awk -v trigger="$trigger" -v run="$run" '
      /pts_time:/ { split($0, a, "pts_time:"); t = a[2] + 0; frames++ }
      /YDIF=/ {
        split($0, b, "="); y = b[2] + 0
        if (t < trigger) next
        if (started && !ended && t - last > 0.25) ended = 1
        if (!ended && y > 0.4) {
          if (!started) { started = 1; first = t }
          last = t; moving++
        }
      }
      END {
        if (!started) { printf "run %d: no motion found\n", run; exit }
        printf "run %d: %d ms span, %d moving frames, %d frames in the recording\n", run, (last - first) * 1000, moving, frames
      }'
done
