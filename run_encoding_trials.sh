#!/bin/bash

ENERGY_METER="/home/cc/bin/cham_monitor"

INPUT=$1
CODEC=$2
PRESET="veryfast"

base_name=$(basename "${INPUT}" .mp4)

OUTPUT_BASE="./output/"       # Root output directory
# Idle baseline window before FFmpeg starts (seconds)

job_dir="${OUTPUT_BASE}/${base_name}/all_rungs_${CODEC}"

mkdir -p "${job_dir}"

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


start_energy_meter ${job_dir}/energy.csv
echo "Started Energy Logging"
sleep $PRE_ENCODE_IDLE_S

if [ "$CODEC" = "h264" ]; then
    ffmpeg -re -i $INPUT \
	   -filter_complex "[0:v]split=8[v0][v1][v2][v3][v4][v5][v6][v7]; \
                   [v0]scale=640:360[v360-1]; \
		   [v1]scale=640:360[v360-2]; \
                   [v2]scale=1280:720[v720-1]; \
		   [v3]scale=1280:720[v720-2]; \
		   [v4]scale=1920:1080[v1080-1]; \
		   [v5]scale=1920:1080[v1080-2]; \
		   [v6]scale=2560:1440[v2K-1]; \
                   [v7]scale=2560:1440[v2K-2]" \
	   \
	   -map "[v360-1]"  -c:v:0 libx264 -preset veryfast -tune zerolatency \
	   -b:v:0 700k  -minrate:v:0 700k  -maxrate:v:0 700k  -bufsize:v:0 700k \
	   -x264-params "nal-hrd=cbr:force-cfr=1:keyint=60:min-keyint=60:scenecut=0:no-open-gop=1" \
	   \
	   -map "[v360-2]"  -c:v:1 libx264 -preset veryfast -tune zerolatency \
	   -b:v:1 1500k  -minrate:v:1 1500k  -maxrate:v:1 1500k  -bufsize:v:1 1500k \
	   -x264-params "nal-hrd=cbr:force-cfr=1:keyint=60:min-keyint=60:scenecut=0:no-open-gop=1" \
	   \
	   -map "[v720-1]"  -c:v:2 libx264 -preset veryfast -tune zerolatency \
	   -b:v:2 2250k  -minrate:v:2 2250k  -maxrate:v:2 2250k  -bufsize:v:2 2250k \
	   -x264-params "nal-hrd=cbr:force-cfr=1:keyint=60:min-keyint=60:scenecut=0:no-open-gop=1" \
	   \
	   -map "[v720-2]"  -c:v:3 libx264 -preset veryfast -tune zerolatency \
	   -b:v:3 3500k  -minrate:v:3 3500k  -maxrate:v:3 3500k  -bufsize:v:3 3500k \
	   -x264-params "nal-hrd=cbr:force-cfr=1:keyint=60:min-keyint=60:scenecut=0:no-open-gop=1" \
	   \
	   -map "[v1080-1]"  -c:v:4 libx264 -preset veryfast -tune zerolatency \
	   -b:v:4 9500k  -minrate:v:4 9500k  -maxrate:v:4 9500k  -bufsize:v:4 9500k \
	   -x264-params "nal-hrd=cbr:force-cfr=1:keyint=60:min-keyint=60:scenecut=0:no-open-gop=1" \
	   \
	   -map "[v1080-2]"  -c:v:5 libx264 -preset veryfast -tune zerolatency \
	   -b:v:5 12000k  -minrate:v:5 12000k  -maxrate:v:5 12000k  -bufsize:v:5 12000k \
	   -x264-params "nal-hrd=cbr:force-cfr=1:keyint=60:min-keyint=60:scenecut=0:no-open-gop=1" \
	   \
	   -map "[v2K-1]"  -c:v:6 libx264 -preset veryfast -tune zerolatency \
	   -b:v:6 15000k  -minrate:v:6 15000k  -maxrate:v:6 15000k  -bufsize:v:6 15000k \
	   -x264-params "nal-hrd=cbr:force-cfr=1:keyint=60:min-keyint=60:scenecut=0:no-open-gop=1" \
	   \
	   -map "[v2K-2]"  -c:v:7 libx264 -preset veryfast -tune zerolatency \
	   -b:v:7 20000k  -minrate:v:7 20000k  -maxrate:v:7 20000k  -bufsize:v:7 20000k \
	   -x264-params "nal-hrd=cbr:force-cfr=1:keyint=60:min-keyint=60:scenecut=0:no-open-gop=1" \
	   \
	   -use_template 1 -use_timeline 0 \
	   -seg_duration 1 -frag_type duration -frag_duration 0.2 \
	   -streaming 1 -ldash 1 -write_prft 1 \
	   -target_latency 1 \
	   -window_size 5 -extra_window_size 10 \
	   -adaptation_sets "id=0,streams=v id=1,streams=a" \
	   -f dash ${job_dir}/output.mpd
elif [ "$CODEC" = "h265" ]; then

    ffmpeg -re -i $INPUT \
	   -filter_complex "[0:v]split=8[v0][v1][v2][v3][v4][v5][v6][v7]; \
                   [v0]scale=640:360[v360-1]; \
		   [v1]scale=640:360[v360-2]; \
                   [v2]scale=1280:720[v720-1]; \
		   [v3]scale=1280:720[v720-2]; \
		   [v4]scale=1920:1080[v1080-1]; \
		   [v5]scale=1920:1080[v1080-2]; \
		   [v6]scale=2560:1440[v2K-1]; \
                   [v7]scale=2560:1440[v2K-2]" \
	   \
	   -map "[v360-1]" -c:v:0 libx265 -preset veryfast -tune zerolatency \
	   -b:v:0 420k -minrate:v:0 420k -maxrate:v:0 420k -bufsize:v:0 420k \
	   -x265-params "hrd=1:vbv-bufsize=420:vbv-maxrate=420:vbv-minrate=420:\
	   keyint=60:min-keyint=60:scenecut=0:no-open-gop=1:repeat-headers=1" \
	   \
	   -map "[v360-2]" -c:v:1 libx265 -preset veryfast -tune zerolatency \
	   -b:v:1 900k -minrate:v:1 900k -maxrate:v:1 900k -bufsize:v:1 900k \
	   -x265-params "hrd=1:vbv-bufsize=900:vbv-maxrate=900:vbv-minrate=900:\
	   keyint=60:min-keyint=60:scenecut=0:no-open-gop=1:repeat-headers=1" \
	   \
	   -map "[v720-1]" -c:v:2 libx265 -preset veryfast -tune zerolatency \
	   -b:v:2 1350k -minrate:v:2 1350k -maxrate:v:2 1350k -bufsize:v:2 1350k \
	   -x265-params "hrd=1:vbv-bufsize=1350:vbv-maxrate=1350:vbv-minrate=1350:\
	   keyint=60:min-keyint=60:scenecut=0:no-open-gop=1:repeat-headers=1" \
	   \
	   -map "[v720-2]" -c:v:3 libx265 -preset veryfast -tune zerolatency \
	   -b:v:3 2100k -minrate:v:3 2100k -maxrate:v:3 2100k -bufsize:v:3 2100k \
	   -x265-params "hrd=1:vbv-bufsize=2100:vbv-maxrate=2100:vbv-minrate=2100:\
	   keyint=60:min-keyint=60:scenecut=0:no-open-gop=1:repeat-headers=1" \
	   \
	   -map "[v1080-1]" -c:v:4 libx265 -preset veryfast -tune zerolatency \
	   -b:v:4 5700k -minrate:v:4 5700k -maxrate:v:4 5700k -bufsize:v:4 5700k \
	   -x265-params "hrd=1:vbv-bufsize=5700:vbv-maxrate=5700:vbv-minrate=5700:\
	   keyint=60:min-keyint=60:scenecut=0:no-open-gop=1:repeat-headers=1" \
	   \
	   -map "[v1080-2]" -c:v:5 libx265 -preset veryfast -tune zerolatency \
	   -b:v:5 7200k -minrate:v:5 7200k -maxrate:v:5 7200k -bufsize:v:5 7200k \
	   -x265-params "hrd=1:vbv-bufsize=7200:vbv-maxrate=7200:vbv-minrate=7200:\
	   keyint=60:min-keyint=60:scenecut=0:no-open-gop=1:repeat-headers=1" \
	   \
	   -map "[v2K-1]" -c:v:6 libx265 -preset veryfast -tune zerolatency \
	   -b:v:6 9000k -minrate:v:6 9000k -maxrate:v:6 9000k -bufsize:v:6 9000k \
	   -x265-params "hrd=1:vbv-bufsize=9000:vbv-maxrate=9000:vbv-minrate=9000:\
	   keyint=60:min-keyint=60:scenecut=0:no-open-gop=1:repeat-headers=1" \
	   \
	   -map "[v2K-2]" -c:v:7 libx265 -preset veryfast -tune zerolatency \
	   -b:v:7 12000k -minrate:v:7 12000k -maxrate:v:7 12000k -bufsize:v:7 12000k \
	   -x265-params "hrd=1:vbv-bufsize=12000:vbv-maxrate=12000:vbv-minrate=12000:\
	   keyint=60:min-keyint=60:scenecut=0:no-open-gop=1:repeat-headers=1" \
	   \
	   -use_template 1 -use_timeline 0 \
	   -seg_duration 1 -frag_type duration -frag_duration 0.2 \
	   -streaming 1 -ldash 1 -write_prft 1 \
	   -target_latency 1 \
	   -window_size 5 -extra_window_size 10 \
	   -adaptation_sets "id=0,streams=v id=1,streams=a" \
	   -f dash ${job_dir}/output.mpd
    
elif [ "$CODEC" = "vp9" ]; then
    ffmpeg -re -i $INPUT \
	   -filter_complex "[0:v]split=8[v0][v1][v2][v3][v4][v5][v6][v7]; \
                   [v0]scale=640:360[v360-1]; \
		   [v1]scale=640:360[v360-2]; \
                   [v2]scale=1280:720[v720-1]; \
		   [v3]scale=1280:720[v720-2]; \
		   [v4]scale=1920:1080[v1080-1]; \
		   [v5]scale=1920:1080[v1080-2]; \
		   [v6]scale=2560:1440[v2K-1]; \
                   [v7]scale=2560:1440[v2K-2]" \
	   \
	   -map "[v360-1]" -c:v:0 libvpx-vp9 -deadline realtime -cpu-used 5 -row-mt 1 \
	   -b:v:0 450k -minrate:v:0 450k -maxrate:v:0 450k -bufsize:v:0 450k \
	   -g 60 -keyint_min 60 -error-resilient 1 -lag-in-frames 0 -auto-alt-ref 0 \
	   \
	   -map "[v360-2]" -c:v:1 libvpx-vp9 -deadline realtime -cpu-used 5 -row-mt 1 \
	   -b:v:1 975k -minrate:v:1 975k -maxrate:v:1 975k -bufsize:v:1 975k \
	   -g 60 -keyint_min 60 -error-resilient 1 -lag-in-frames 0 -auto-alt-ref 0 \
	   \
	   -map "[v720-1]" -c:v:2 libvpx-vp9 -deadline realtime -cpu-used 5 -row-mt 1 \
	   -b:v:2 1450k -minrate:v:2 1450k -maxrate:v:2 1450k -bufsize:v:2 1450k \
	   -g 60 -keyint_min 60 -error-resilient 1 -lag-in-frames 0 -auto-alt-ref 0 \
	   \
	   -map "[v720-2]" -c:v:3 libvpx-vp9 -deadline realtime -cpu-used 5 -row-mt 1 \
	   -b:v:3 2275k -minrate:v:3 2275k -maxrate:v:3 2275k -bufsize:v:3 2275k \
	   -g 60 -keyint_min 60 -error-resilient 1 -lag-in-frames 0 -auto-alt-ref 0 \
	   \
	   -map "[v1080-1]" -c:v:4 libvpx-vp9 -deadline realtime -cpu-used 5 -row-mt 1 \
	   -b:v:4 6175k -minrate:v:4 6175k -maxrate:v:4 6175k -bufsize:v:4 6175k \
	   -g 60 -keyint_min 60 -error-resilient 1 -lag-in-frames 0 -auto-alt-ref 0 \
	   \
	   -map "[v1080-2]" -c:v:5 libvpx-vp9 -deadline realtime -cpu-used 5 -row-mt 1 \
	   -b:v:5 7800k -minrate:v:5 7800k -maxrate:v:5 7800k -bufsize:v:5 7800k \
	   -g 60 -keyint_min 60 -error-resilient 1 -lag-in-frames 0 -auto-alt-ref 0 \
	   \
	   -map "[v2K-1]" -c:v:6 libvpx-vp9 -deadline realtime -cpu-used 5 -row-mt 1 \
	   -b:v:6 9750k -minrate:v:6 9750k -maxrate:v:6 9750k -bufsize:v:6 9750k \
	   -g 60 -keyint_min 60 -error-resilient 1 -lag-in-frames 0 -auto-alt-ref 0 \
	   \
	   -map "[v2K-2]" -c:v:7 libvpx-vp9 -deadline realtime -cpu-used 5 -row-mt 1 \
	   -b:v:7 13000k -minrate:v:7 13000k -maxrate:v:7 13000k -bufsize:v:7 13000k \
	   -g 60 -keyint_min 60 -error-resilient 1 -lag-in-frames 0 -auto-alt-ref 0 \
	   \
	   -use_template 1 -use_timeline 0 \
	   -seg_duration 1 -frag_type duration -frag_duration 0.2 \
	   -streaming 1 -ldash 1 -write_prft 1 \
	   -target_latency 1 \
	   -window_size 5 -extra_window_size 10 \
	   -adaptation_sets "id=0,streams=v id=1,streams=a" \
	   -f dash ${job_dir}/output.mpd
    
elif [ "$CODEC" = "av1" ]; then
    echo "AV1 Encoding"
    ffmpeg -re -i $INPUT \
	   -filter_complex "[0:v]split=8[v0][v1][v2][v3][v4][v5][v6][v7]; \
                   [v0]scale=640:360[v360-1]; \
		   [v1]scale=640:360[v360-2]; \
                   [v2]scale=1280:720[v720-1]; \
		   [v3]scale=1280:720[v720-2]; \
		   [v4]scale=1920:1080[v1080-1]; \
		   [v5]scale=1920:1080[v1080-2]; \
		   [v6]scale=2560:1440[v2K-1]; \
                   [v7]scale=2560:1440[v2K-2]" \
	   \
	   -map "[v360-1]" -c:v:0 libsvtav1 -deadline realtime -cpu-used 5 -row-mt 1 \
           -b:v:0 350k \
           -svtav1-params "rc=2:tbr=350:mbr=350:bufsz=350:\
            keyint=60:scd=0:pred-struct=1:lookahead=0:enable-overlays=0" \
	   \
	   -map "[v360-2]" -c:v:1 libsvtav1 -preset 8 \
	   -b:v:1 750k  \
           -svtav1-params "rc=2:tbr=750:mbr=750:bufsz=750:\
            keyint=60:scd=0:pred-struct=1:lookahead=0:enable-overlays=0" \
	   \
	   -map "[v720-1]" -c:v:2 libsvtav1 -preset 8 \
	   -b:v:2 1125k \
           -svtav1-params "rc=2:tbr=1125:mbr=1125:bufsz=1125:\
            keyint=60:scd=0:pred-struct=1:lookahead=0:enable-overlays=0" \
	   \
	   -map "[v720-2]" -c:v:3 libsvtav1 -preset 8 \
	   -b:v:3 1750k \
           -svtav1-params "rc=2:tbr=1750:mbr=1750:bufsz=1750:\
            keyint=60:scd=0:pred-struct=1:lookahead=0:enable-overlays=0" \
	   \
	   -map "[v1080-1]" -c:v:4 libsvtav1 -preset 8 \
	   -b:v:4 4750k \
           -svtav1-params "rc=2:tbr=4750:mbr=4750:bufsz=4750:\
            keyint=60:scd=0:pred-struct=1:lookahead=0:enable-overlays=0" \
	   \
	   -map "[v1080-2]" -c:v:5 libsvtav1 -preset 8 \
	   -b:v:5 6000k \
           -svtav1-params "rc=2:tbr=6000:mbr=6000:bufsz=6000:\
            keyint=60:scd=0:pred-struct=1:lookahead=0:enable-overlays=0" \
	   \
	   -map "[v2K-1]" -c:v:6 libsvtav1 -preset 8 \
	   -b:v:6 7500k \
           -svtav1-params "rc=2:tbr=7500:mbr=7500:bufsz=7500:\
            keyint=60:scd=0:pred-struct=1:lookahead=0:enable-overlays=0" \
	   \
	   -map "[v2K-2]" -c:v:7 libsvtav1 -preset 8 \
	   -b:v:7 9000k \
           -svtav1-params "rc=2:tbr=9000:mbr=9000:bufsz=9000:\
            keyint=60:scd=0:pred-struct=1:lookahead=0:enable-overlays=0" \
	   \
	   -use_template 1 -use_timeline 0 \
	   -seg_duration 1 -frag_type duration -frag_duration 0.2 \
	   -streaming 1 -ldash 1 -write_prft 1 \
	   -target_latency 1 \
	   -window_size 5 -extra_window_size 10 \
	   -adaptation_sets "id=0,streams=v id=1,streams=a" \
	   -f dash ${job_dir}/output.mpd

elif [ "$CODEC" = "h266" ]; then
    echo "H266 Encoding"
fi

sleep $POST_ENCODE_COOLDOWN_S
kill_energy_meter

echo "Killed Energy Logging"
