#!/bin/bash

ENERGY_METER="/home/cc/bin/cham_monitor"

INPUT=$1
CODEC=$2
PRESET="veryfast"

base_name=$(basename "${INPUT}" .mp4)

OUTPUT_BASE="./output/"       # Root output directory

job_dir="${OUTPUT_BASE}/${base_name}_cvbr/all_rungs_${CODEC}-2"

mkdir -p "${job_dir}"

# Idle baseline window before FFmpeg starts (seconds)
PRE_ENCODE_IDLE_S=60

# Cooldown window after FFmpeg exits before the C program is killed (seconds)
POST_ENCODE_COOLDOWN_S=60

start_energy_meter() {
    local meter_output_file="$1"
    local gpu_log_file="${meter_output_file%/*}/gpu_power_log.csv"

    # RAPL counters via cham_monitor
    "${ENERGY_METER}" "${meter_output_file}" &
    ENERGY_METER_PID=$!
    echo "     [meter] started (PID ${ENERGY_METER_PID}) → ${meter_output_file}"

    # # GPU power via nvidia-smi (1 Hz)
    # nvidia-smi --query-gpu=timestamp,power.draw --format=csv,nounits -l 1 -f "${gpu_log_file}" &
    # GPU_LOGGER_PID=$!
    # echo "     [gpu]   started (PID ${GPU_LOGGER_PID}) → ${gpu_log_file}"
}


kill_energy_meter() {
    # Stop RAPL meter
    if (( ENERGY_METER_PID > 0 )); then
        if kill -0 "${ENERGY_METER_PID}" 2>/dev/null; then
            kill -KILL "${ENERGY_METER_PID}" 2>/dev/null || true
            echo "     [meter] SIGKILL sent to PID ${ENERGY_METER_PID}"
        else
            echo "     [meter] PID ${ENERGY_METER_PID} already exited before SIGKILL"
        fi
        ENERGY_METER_PID=0
    fi

    # # Stop GPU logger — SIGTERM first so nvidia-smi flushes its final line
    # if (( GPU_LOGGER_PID > 0 )); then
    #     if kill -0 "${GPU_LOGGER_PID}" 2>/dev/null; then
    #         kill -TERM "${GPU_LOGGER_PID}" 2>/dev/null || true
    #         sleep 0.3
    #         kill -KILL "${GPU_LOGGER_PID}" 2>/dev/null || true
    #         echo "     [gpu]   stopped PID ${GPU_LOGGER_PID}"
    #     else
    #         echo "     [gpu]   PID ${GPU_LOGGER_PID} already exited"
    #     fi
    #     GPU_LOGGER_PID=0
    # fi
}


# ---------------------------------------------------------------------------
# Fan out the 4 resolution pass-1 stats logs to the 8 stream indices that
# pass-2 will look for. ffmpeg appends "-<output_stream_index>" to whatever
# you give -passlogfile, so pass-1 (4 streams, idx 0..3) produces:
#     pass-360-0.log  pass-720-1.log  pass-1080-2.log  pass-2K-3.log
# while pass-2 (8 streams, idx 0..7) looks for the full 0..7 set. We symlink
# the missing names onto the real log for the same resolution.
#
#   $1 = job_dir
#   $2 = with_mbtree : 1 for libx264 (writes a .mbtree companion),
#                      0 for libvpx-vp9 / libsvtav1 (single .log, no mbtree)
# ---------------------------------------------------------------------------
link_pass_logs() {
    local d="$1" with_mbtree="$2"
    (
        cd "$d" || exit 1
        _fan() {                       # _fan <base> <src_idx> <target_idx...>
            local base="$1" src="$2"; shift 2
            local i
            for i in "$@"; do
                ln -sf "${base}-${src}.log" "${base}-${i}.log"
                [ "$with_mbtree" = "1" ] && \
                    ln -sf "${base}-${src}.log.mbtree" "${base}-${i}.log.mbtree"
            done
        }
        _fan pass-360  0 1        # 360p : src idx 0 -> also 1
        _fan pass-720  1 2 3      # 720p : src idx 1 -> also 2,3
        _fan pass-1080 2 4 5      # 1080p: src idx 2 -> also 4,5
        _fan pass-2K   3 6 7      # 2K   : src idx 3 -> also 6,7
    )
}

# DASH muxer options are identical across codecs (they're codec-agnostic).
DASH_OPTS=(-use_template 1 -use_timeline 0
           -seg_duration 1 -frag_type duration -frag_duration 0.2
           -streaming 1 -ldash 1 -write_prft 1
           -target_latency 1
           -adaptation_sets "id=0,streams=v id=1,streams=a")


start_energy_meter ${job_dir}/energy.csv
echo "Started Energy Logging"
sleep $PRE_ENCODE_IDLE_S


if [ "$CODEC" = "h264" ]; then
    # ===================== H.264 / libx264 =====================
    # Pass 1: only 4 streams, one per resolution
    ffmpeg -i $INPUT \
	   -filter_complex "[0:v]split=4[v0][v2][v4][v6]; \
                   [v0]scale=640:360[v360]; \
                   [v2]scale=1280:720[v720]; \
                   [v4]scale=1920:1080[v1080]; \
                   [v6]scale=2560:1440[v2K]" \
	   -map "[v360]"  -c:v:0 libx264 -preset fast -b:v:0 700k   -pass 1 -passlogfile:v:0 ${job_dir}/pass-360  -x264-params "keyint=60:min-keyint=60:scenecut=0:no-open-gop=1" \
	   -map "[v720]"  -c:v:1 libx264 -preset fast -b:v:1 2250k  -pass 1 -passlogfile:v:1 ${job_dir}/pass-720  -x264-params "keyint=60:min-keyint=60:scenecut=0:no-open-gop=1" \
	   -map "[v1080]" -c:v:2 libx264 -preset fast -b:v:2 9500k  -pass 1 -passlogfile:v:2 ${job_dir}/pass-1080 -x264-params "keyint=60:min-keyint=60:scenecut=0:no-open-gop=1" \
	   -map "[v2K]"   -c:v:3 libx264 -preset fast -b:v:3 15000k -pass 1 -passlogfile:v:3 ${job_dir}/pass-2K   -x264-params "keyint=60:min-keyint=60:scenecut=0:no-open-gop=1" \
	   -an -f null /dev/null

    echo "Done with Pass 1"

    link_pass_logs "${job_dir}" 1        # libx264 -> also fan out .mbtree

    ffmpeg -i $INPUT \
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
	   -map "[v360-1]"  -c:v:0 libx264 -preset veryfast -b:v:0 700k   -maxrate:v:0 980k   -bufsize:v:0 1400k  -pass 2 -passlogfile:v:0 ${job_dir}/pass-360 -x264-params "keyint=60:min-keyint=60:scenecut=0:no-open-gop=1" \
	   -map "[v360-2]"  -c:v:1 libx264 -preset veryfast -b:v:1 1500k  -maxrate:v:1 2100k  -bufsize:v:1 3000k  -pass 2 -passlogfile:v:1 ${job_dir}/pass-360 -x264-params "keyint=60:min-keyint=60:scenecut=0:no-open-gop=1" \
	   -map "[v720-1]"  -c:v:2 libx264 -preset veryfast -b:v:2 2250k  -maxrate:v:2 3150k  -bufsize:v:2 4500k  -pass 2 -passlogfile:v:2 ${job_dir}/pass-720 -x264-params "keyint=60:min-keyint=60:scenecut=0:no-open-gop=1" \
	   -map "[v720-2]"  -c:v:3 libx264 -preset veryfast -b:v:3 3500k  -maxrate:v:3 4900k  -bufsize:v:3 7000k  -pass 2 -passlogfile:v:3 ${job_dir}/pass-720 -x264-params "keyint=60:min-keyint=60:scenecut=0:no-open-gop=1" \
	   -map "[v1080-1]" -c:v:4 libx264 -preset veryfast -b:v:4 9500k  -maxrate:v:4 13300k -bufsize:v:4 19000k -pass 2 -passlogfile:v:4 ${job_dir}/pass-1080 -x264-params "keyint=60:min-keyint=60:scenecut=0:no-open-gop=1" \
	   -map "[v1080-2]" -c:v:5 libx264 -preset veryfast -b:v:5 12000k -maxrate:v:5 16800k -bufsize:v:5 24000k -pass 2 -passlogfile:v:5 ${job_dir}/pass-1080 -x264-params "keyint=60:min-keyint=60:scenecut=0:no-open-gop=1" \
	   -map "[v2K-1]"   -c:v:6 libx264 -preset veryfast -b:v:6 15000k -maxrate:v:6 21000k -bufsize:v:6 30000k -pass 2 -passlogfile:v:6 ${job_dir}/pass-2K -x264-params "keyint=60:min-keyint=60:scenecut=0:no-open-gop=1" \
	   -map "[v2K-2]"   -c:v:7 libx264 -preset veryfast -b:v:7 20000k -maxrate:v:7 28000k -bufsize:v:7 40000k -pass 2 -passlogfile:v:7 ${job_dir}/pass-2K -x264-params "keyint=60:min-keyint=60:scenecut=0:no-open-gop=1" \
	   \
	   "${DASH_OPTS[@]}" \
	   -f dash ${job_dir}/output.mpd


elif [ "$CODEC" = "av1" ]; then
    # ===================== AV1 / libsvtav1 =====================
    # SVT-AV1 speed: -preset 0 (slowest/best) .. 13 (fastest). scd=0 disables
    # scene-change detection so keyframes stay on the fixed 60-frame GOP grid
    # (important for DASH segment alignment). -g 60 sets the intra period.
    # NOTE: SVT-AV1 rejects -maxrate/-bufsize in bitrate-target mode
    # ("Max Bitrate only supported with CRF mode"), so this is plain target
    # VBR (-b:v only). For a hard cap you'd switch to capped-CRF:
    # -crf N -b:v 0 -maxrate <cap> -bufsize <buf>, which changes the ladder
    # from bitrate-anchored to quality-anchored.
    AV1_PASS1_PRESET=10      # faster analysis pass
    AV1_PASS2_PRESET=8       # quality pass

    # Pass 1: only 4 streams, one per resolution
    ffmpeg -i $INPUT \
	   -filter_complex "[0:v]split=4[v0][v2][v4][v6]; \
                   [v0]scale=640:360[v360]; \
                   [v2]scale=1280:720[v720]; \
                   [v4]scale=1920:1080[v1080]; \
                   [v6]scale=2560:1440[v2K]" \
	   -map "[v360]"  -c:v:0 libsvtav1 -preset:v:0 ${AV1_PASS1_PRESET} -b:v:0 700k   -g:v:0 60 -svtav1-params:v:0 scd=0 -pass 1 -passlogfile:v:0 ${job_dir}/pass-360  \
	   -map "[v720]"  -c:v:1 libsvtav1 -preset:v:1 ${AV1_PASS1_PRESET} -b:v:1 2250k  -g:v:1 60 -svtav1-params:v:1 scd=0 -pass 1 -passlogfile:v:1 ${job_dir}/pass-720  \
	   -map "[v1080]" -c:v:2 libsvtav1 -preset:v:2 ${AV1_PASS1_PRESET} -b:v:2 9500k  -g:v:2 60 -svtav1-params:v:2 scd=0 -pass 1 -passlogfile:v:2 ${job_dir}/pass-1080 \
	   -map "[v2K]"   -c:v:3 libsvtav1 -preset:v:3 ${AV1_PASS1_PRESET} -b:v:3 15000k -g:v:3 60 -svtav1-params:v:3 scd=0 -pass 1 -passlogfile:v:3 ${job_dir}/pass-2K   \
	   -an -f null /dev/null

    echo "Done with Pass 1"

    link_pass_logs "${job_dir}" 0        # libsvtav1 -> single .log, no mbtree

    ffmpeg -i $INPUT \
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
	   -map "[v360-1]"  -c:v:0 libsvtav1 -preset:v:0 ${AV1_PASS2_PRESET} -b:v:0 700k   -g:v:0 60 -svtav1-params:v:0 scd=0 -pass 2 -passlogfile:v:0 ${job_dir}/pass-360 \
	   -map "[v360-2]"  -c:v:1 libsvtav1 -preset:v:1 ${AV1_PASS2_PRESET} -b:v:1 1500k  -g:v:1 60 -svtav1-params:v:1 scd=0 -pass 2 -passlogfile:v:1 ${job_dir}/pass-360 \
	   -map "[v720-1]"  -c:v:2 libsvtav1 -preset:v:2 ${AV1_PASS2_PRESET} -b:v:2 2250k  -g:v:2 60 -svtav1-params:v:2 scd=0 -pass 2 -passlogfile:v:2 ${job_dir}/pass-720 \
	   -map "[v720-2]"  -c:v:3 libsvtav1 -preset:v:3 ${AV1_PASS2_PRESET} -b:v:3 3500k  -g:v:3 60 -svtav1-params:v:3 scd=0 -pass 2 -passlogfile:v:3 ${job_dir}/pass-720 \
	   -map "[v1080-1]" -c:v:4 libsvtav1 -preset:v:4 ${AV1_PASS2_PRESET} -b:v:4 9500k  -g:v:4 60 -svtav1-params:v:4 scd=0 -pass 2 -passlogfile:v:4 ${job_dir}/pass-1080 \
	   -map "[v1080-2]" -c:v:5 libsvtav1 -preset:v:5 ${AV1_PASS2_PRESET} -b:v:5 12000k -g:v:5 60 -svtav1-params:v:5 scd=0 -pass 2 -passlogfile:v:5 ${job_dir}/pass-1080 \
	   -map "[v2K-1]"   -c:v:6 libsvtav1 -preset:v:6 ${AV1_PASS2_PRESET} -b:v:6 15000k -g:v:6 60 -svtav1-params:v:6 scd=0 -pass 2 -passlogfile:v:6 ${job_dir}/pass-2K \
	   -map "[v2K-2]"   -c:v:7 libsvtav1 -preset:v:7 ${AV1_PASS2_PRESET} -b:v:7 20000k -g:v:7 60 -svtav1-params:v:7 scd=0 -pass 2 -passlogfile:v:7 ${job_dir}/pass-2K \
	   \
	   "${DASH_OPTS[@]}" \
	   -f dash ${job_dir}/output.mpd


elif [ "$CODEC" = "vp9" ]; then
    # ===================== VP9 / libvpx-vp9 =====================
    # VP9 speed: -deadline good + -cpu-used N (0 slowest/best .. 5 fastest here).
    # Setting -keyint_min == -g (60) forces a fixed GOP and stops scene-cut
    # keyframes, keeping DASH segment boundaries aligned. -row-mt/-tile-columns
    # help intra-frame threading. -auto-alt-ref/-lag-in-frames must match
    # between passes; VBR is target -b:v with a -maxrate/-bufsize cap.
    VP9_PASS1_CPU=4          # faster analysis pass
    VP9_PASS2_CPU=4          # quality pass

    # Pass 1: only 4 streams, one per resolution
    ffmpeg -i $INPUT \
	   -filter_complex "[0:v]split=4[v0][v2][v4][v6]; \
                   [v0]scale=640:360[v360]; \
                   [v2]scale=1280:720[v720]; \
                   [v4]scale=1920:1080[v1080]; \
                   [v6]scale=2560:1440[v2K]" \
	   -map "[v360]"  -c:v:0 libvpx-vp9 -b:v:0 700k   -deadline:v:0 good -cpu-used:v:0 ${VP9_PASS1_CPU} -g:v:0 60 -keyint_min:v:0 60 -row-mt:v:0 1 -tile-columns:v:0 2 -auto-alt-ref:v:0 1 -lag-in-frames:v:0 25 -pass 1 -passlogfile:v:0 ${job_dir}/pass-360  \
	   -map "[v720]"  -c:v:1 libvpx-vp9 -b:v:1 2250k  -deadline:v:1 good -cpu-used:v:1 ${VP9_PASS1_CPU} -g:v:1 60 -keyint_min:v:1 60 -row-mt:v:1 1 -tile-columns:v:1 2 -auto-alt-ref:v:1 1 -lag-in-frames:v:1 25 -pass 1 -passlogfile:v:1 ${job_dir}/pass-720  \
	   -map "[v1080]" -c:v:2 libvpx-vp9 -b:v:2 9500k  -deadline:v:2 good -cpu-used:v:2 ${VP9_PASS1_CPU} -g:v:2 60 -keyint_min:v:2 60 -row-mt:v:2 1 -tile-columns:v:2 2 -auto-alt-ref:v:2 1 -lag-in-frames:v:2 25 -pass 1 -passlogfile:v:2 ${job_dir}/pass-1080 \
	   -map "[v2K]"   -c:v:3 libvpx-vp9 -b:v:3 15000k -deadline:v:3 good -cpu-used:v:3 ${VP9_PASS1_CPU} -g:v:3 60 -keyint_min:v:3 60 -row-mt:v:3 1 -tile-columns:v:3 2 -auto-alt-ref:v:3 1 -lag-in-frames:v:3 25 -pass 1 -passlogfile:v:3 ${job_dir}/pass-2K   \
	   -an -f null /dev/null

    echo "Done with Pass 1"

    link_pass_logs "${job_dir}" 0        # libvpx-vp9 -> single .log, no mbtree

    ffmpeg -i $INPUT \
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
	   -map "[v360-1]"  -c:v:0 libvpx-vp9 -b:v:0 700k   -maxrate:v:0 980k   -bufsize:v:0 1400k  -deadline:v:0 good -cpu-used:v:0 ${VP9_PASS2_CPU} -g:v:0 60 -keyint_min:v:0 60 -row-mt:v:0 1 -tile-columns:v:0 2 -auto-alt-ref:v:0 1 -lag-in-frames:v:0 25 -pass 2 -passlogfile:v:0 ${job_dir}/pass-360 \
	   -map "[v360-2]"  -c:v:1 libvpx-vp9 -b:v:1 1500k  -maxrate:v:1 2100k  -bufsize:v:1 3000k  -deadline:v:1 good -cpu-used:v:1 ${VP9_PASS2_CPU} -g:v:1 60 -keyint_min:v:1 60 -row-mt:v:1 1 -tile-columns:v:1 2 -auto-alt-ref:v:1 1 -lag-in-frames:v:1 25 -pass 2 -passlogfile:v:1 ${job_dir}/pass-360 \
	   -map "[v720-1]"  -c:v:2 libvpx-vp9 -b:v:2 2250k  -maxrate:v:2 3150k  -bufsize:v:2 4500k  -deadline:v:2 good -cpu-used:v:2 ${VP9_PASS2_CPU} -g:v:2 60 -keyint_min:v:2 60 -row-mt:v:2 1 -tile-columns:v:2 2 -auto-alt-ref:v:2 1 -lag-in-frames:v:2 25 -pass 2 -passlogfile:v:2 ${job_dir}/pass-720 \
	   -map "[v720-2]"  -c:v:3 libvpx-vp9 -b:v:3 3500k  -maxrate:v:3 4900k  -bufsize:v:3 7000k  -deadline:v:3 good -cpu-used:v:3 ${VP9_PASS2_CPU} -g:v:3 60 -keyint_min:v:3 60 -row-mt:v:3 1 -tile-columns:v:3 2 -auto-alt-ref:v:3 1 -lag-in-frames:v:3 25 -pass 2 -passlogfile:v:3 ${job_dir}/pass-720 \
	   -map "[v1080-1]" -c:v:4 libvpx-vp9 -b:v:4 9500k  -maxrate:v:4 13300k -bufsize:v:4 19000k -deadline:v:4 good -cpu-used:v:4 ${VP9_PASS2_CPU} -g:v:4 60 -keyint_min:v:4 60 -row-mt:v:4 1 -tile-columns:v:4 2 -auto-alt-ref:v:4 1 -lag-in-frames:v:4 25 -pass 2 -passlogfile:v:4 ${job_dir}/pass-1080 \
	   -map "[v1080-2]" -c:v:5 libvpx-vp9 -b:v:5 12000k -maxrate:v:5 16800k -bufsize:v:5 24000k -deadline:v:5 good -cpu-used:v:5 ${VP9_PASS2_CPU} -g:v:5 60 -keyint_min:v:5 60 -row-mt:v:5 1 -tile-columns:v:5 2 -auto-alt-ref:v:5 1 -lag-in-frames:v:5 25 -pass 2 -passlogfile:v:5 ${job_dir}/pass-1080 \
	   -map "[v2K-1]"   -c:v:6 libvpx-vp9 -b:v:6 15000k -maxrate:v:6 21000k -bufsize:v:6 30000k -deadline:v:6 good -cpu-used:v:6 ${VP9_PASS2_CPU} -g:v:6 60 -keyint_min:v:6 60 -row-mt:v:6 1 -tile-columns:v:6 2 -auto-alt-ref:v:6 1 -lag-in-frames:v:6 25 -pass 2 -passlogfile:v:6 ${job_dir}/pass-2K \
	   -map "[v2K-2]"   -c:v:7 libvpx-vp9 -b:v:7 20000k -maxrate:v:7 28000k -bufsize:v:7 40000k -deadline:v:7 good -cpu-used:v:7 ${VP9_PASS2_CPU} -g:v:7 60 -keyint_min:v:7 60 -row-mt:v:7 1 -tile-columns:v:7 2 -auto-alt-ref:v:7 1 -lag-in-frames:v:7 25 -pass 2 -passlogfile:v:7 ${job_dir}/pass-2K \
	   \
	   "${DASH_OPTS[@]}" \
	   -f dash ${job_dir}/output.mpd


else
    echo "Unknown CODEC '${CODEC}'. Supported: h264, av1, vp9" >&2
fi


sleep $POST_ENCODE_COOLDOWN_S
kill_energy_meter

echo "Killed Energy Logging"
