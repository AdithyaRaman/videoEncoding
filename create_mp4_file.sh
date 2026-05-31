#!/bin/bash
set -euo pipefail

INPUT=$1
CODEC=$2

ENERGY_METER="/home/cc/bin/cham_monitor"
# Idle baseline window before FFmpeg starts (seconds)
PRE_ENCODE_IDLE_S=30

# Cooldown window after FFmpeg exits before the C program is killed (seconds)
POST_ENCODE_COOLDOWN_S=15

start_energy_meter() {
    local meter_output_file="$1"

    # shellcheck disable=SC2086
    "${ENERGY_METER}" "${meter_output_file}" &
    ENERGY_METER_PID=$!

    echo "     [meter] started (PID ${ENERGY_METER_PID}) → ${meter_output_file}"
}

# SIGKILL the energy meter and reset the PID tracker.
kill_energy_meter() {
    if (( ENERGY_METER_PID > 0 )); then
        if kill -0 "${ENERGY_METER_PID}" 2>/dev/null; then
            kill -KILL "${ENERGY_METER_PID}" 2>/dev/null || true
            echo "     [meter] SIGKILL sent to PID ${ENERGY_METER_PID}"
        else
            echo "     [meter] PID ${ENERGY_METER_PID} already exited before SIGKILL"
        fi
        ENERGY_METER_PID=0
    fi
}

encode_h264() {
    local input=$1 output=$2 w=$3 h=$4 br=$5
    ffmpeg -y -i "$input" \
        -vf "scale=${w}:${h},setsar=1" \
        -c:v libx264 -preset veryfast -tune zerolatency \
        -b:v "${br}k" -minrate "${br}k" -maxrate "${br}k" -bufsize "${br}k" \
        -x264-params "nal-hrd=cbr:force-cfr=1:keyint=60:min-keyint=60:scenecut=0:no-open-gop=1" \
        -movflags +faststart \
        "$output"
}

encode_h265() {
    local input=$1 output=$2 w=$3 h=$4 br=$5
    ffmpeg -y -i "$input" \
        -vf "scale=${w}:${h},setsar=1" \
        -c:v libx265 -preset veryfast -tune zerolatency \
        -b:v "${br}k" -minrate "${br}k" -maxrate "${br}k" -bufsize "${br}k" \
        -x265-params "hrd=1:vbv-bufsize=${br}:vbv-maxrate=${br}:vbv-minrate=${br}:keyint=60:min-keyint=60:scenecut=0:no-open-gop=1:repeat-headers=1" \
        -tag:v hvc1 \
        -movflags +faststart \
        "$output"
}

encode_vp9() {
    local input=$1 output=$2 w=$3 h=$4 br=$5
    ffmpeg -y -i "$input" \
        -vf "scale=${w}:${h},setsar=1" \
        -c:v libvpx-vp9 -deadline realtime -cpu-used 5 -row-mt 1 \
        -b:v "${br}k" -minrate "${br}k" -maxrate "${br}k" -bufsize "${br}k" \
        -g 60 -keyint_min 60 \
        -error-resilient 1 -lag-in-frames 0 -auto-alt-ref 0 \
        "$output"
}

encode_av1() {
    local input=$1 output=$2 w=$3 h=$4 br=$5
    ffmpeg -y -i "$input" \
        -vf "scale=${w}:${h},setsar=1" \
        -c:v libsvtav1 -preset 8 \
        -b:v "${br}k" \
        -svtav1-params "rc=2:tbr=${br}:mbr=${br}:bufsz=${br}:keyint=60:scd=0:pred-struct=1:lookahead=0:enable-overlays=0" \
        -movflags +faststart \
        "$output"
}

base_name=$(basename "${INPUT}" .mp4)

OUTPUT_BASE="./output/"       # Root output directory
# Idle baseline window before FFmpeg starts (seconds)

job_dir="${OUTPUT_BASE}/${base_name}/all_mp4_${CODEC}/"

mkdir -p "${job_dir}"

# Bitrate ladder: width, height, bitrate (in kbps)
WIDTHS=(640  640  1280 1280 1920 1920  2560  2560)
HEIGHTS=(360 360  720  720  1080 1080  1440  1440)

BITRATES_h264=(700 1500 2250 3500 9500  12000 15000 20000)
BITRATES_h265=(420 900  1350 2100 5700  7200  9000  12000)
BITRATES_vp9=(450  975  1450 2275 6175  7800  9750  13000)
BITRATES_av1=(350  750  1125 1750 4750  6000  7500  10000)

# Select the ladder for the requested codec
case "$CODEC" in
    h264) BITRATES=("${BITRATES_h264[@]}") ;;
    h265) BITRATES=("${BITRATES_h265[@]}") ;;
    vp9)  BITRATES=("${BITRATES_vp9[@]}")  ;;
    av1)  BITRATES=("${BITRATES_av1[@]}")  ;;
    *)    echo "Unknown codec: $CODEC" >&2; exit 1 ;;
esac


for i in "${!BITRATES[@]}"; do
    W="${WIDTHS[$i]}"
    H="${HEIGHTS[$i]}"
    BR="${BITRATES[$i]}"
    OUT="${job_dir}/video_${W}x${H}_${BR}k.mp4"
    start_energy_meter ${job_dir}/energy_${W}x${H}_${BR}k.csv
    sleep $PRE_ENCODE_IDLE_S
    
    echo "Encoding rung $((i+1))/${#BITRATES[@]}: ${W}x${H} @ ${BR}k -> $OUT"

    case "$CODEC" in
        h264) encode_h264 "$INPUT" "$OUT" "$W" "$H" "$BR" ;;
        h265) encode_h265 "$INPUT" "$OUT" "$W" "$H" "$BR" ;;
        vp9)  encode_vp9  "$INPUT" "$OUT" "$W" "$H" "$BR" ;;
        av1)  encode_av1  "$INPUT" "$OUT" "$W" "$H" "$BR" ;;
        *)    echo "Unknown codec: $CODEC" >&2; kill_energy_meter; exit 1 ;;
    esac

    sleep $POST_ENCODE_COOLDOWN_S
    kill_energy_meter
done

sleep 10

for i in "${!BITRATES[@]}"; do

    W="${WIDTHS[$i]}"
    H="${HEIGHTS[$i]}"
    BR="${BITRATES[$i]}"
    OUT="${job_dir}/video_${W}x${H}_${BR}k.mp4"

    nohup ffmpeg-quality-metrics $OUT $INPUT --metrics psnr ssim vmaf --vmaf-features motion float_ssim -p -of csv >> "${job_dir}/quality_${W}x${H}_${BR}k.csv" &
done

echo "Done. ${#BITRATES[@]} files in $OUTPUT_DIR"
