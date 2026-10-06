#!/bin/bash
set -euo pipefail

IN=/home/cc//inter4k_training_videos/
OUT=/home/cc/inter4k_30fps/
mkdir -p "$OUT"

for f in "$IN"/*.mp4; do
    base=$(basename "$f" .mp4)

    ffmpeg -y -i "$f" \
    -vf "select='not(mod(n,2))',setpts=N/30/TB,scale=2560:1440:flags=lanczos,setsar=1" \
    -r 30 -fps_mode cfr \
    -c:v libx264 -crf 16 -preset slow \
    -pix_fmt yuv420p \
    -an \
    "$OUT/${base}.mp4"

done
