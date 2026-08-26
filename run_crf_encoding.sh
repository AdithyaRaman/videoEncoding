#!/bin/bash
# ===========================================================================
# Capped CRF ladder encoding  (was: two-pass ABR / "cVBR")
#
# WHAT CHANGED vs run_cvbr_encoding.sh
#   - The ladder is now anchored on QUALITY (CRF), not on bitrate. -b:v is
#     gone as a target; the old per-rung -maxrate/-bufsize survive as a
#     VBV *ceiling* that only binds on hard content.
#   - libx264 and libsvtav1 are now SINGLE PASS. Capped CRF is a one-pass
#     mode in both; there is no stats file to produce or consume, so the
#     pass-1 invocation and the log fan-out are dropped for those codecs.
#   - libvpx-vp9 KEEPS two passes. libvpx's constrained-quality mode is
#     markedly better with first-pass stats, so link_pass_logs is still
#     used there. Set VP9_TWO_PASS=0 below if you need pass-count parity
#     across codecs for the energy comparison.
#   - Output sizes will now VARY across clips of differing (E,h). That is
#     the point of the change.
#
# Usage: ./run_ccrf_encoding.sh <input.mp4> <h264|av1|vp9>
# ===========================================================================

ENERGY_METER="/home/cc/bin/cham_monitor"

INPUT=$1
CODEC=$2
PRESET="veryfast"

base_name=$(basename "${INPUT}" .mp4)

OUTPUT_BASE="./output/"       # Root output directory

job_dir="${OUTPUT_BASE}/${base_name}_ccrf/all_rungs_${CODEC}-3"

mkdir -p "${job_dir}"

# Idle baseline window before FFmpeg starts (seconds)
PRE_ENCODE_IDLE_S=60

# Cooldown window after FFmpeg exits before the C program is killed (seconds)
POST_ENCODE_COOLDOWN_S=60

# Keep libvpx on two passes (1) or run it single-pass like the others (0).
VP9_TWO_PASS=0

# ---------------------------------------------------------------------------
# THE LADDER
#
# Each resolution carries two rungs, exactly as before. Previously the two
# rungs differed by target bitrate; now they differ by CRF, and the old
# bitrates become the delivery ceiling for the rung.
#
#   rung "A" = the old lower-bitrate rung  -> higher CRF (cheaper)
#   rung "B" = the old higher-bitrate rung -> lower CRF  (better)
#
# CRF scales are NOT comparable across codecs. x264 is 0-51; SVT-AV1 and
# libvpx-vp9 are both 0-63 but with different operating ranges. The VP9
# values follow Google's per-resolution CQ recommendations.
# ---------------------------------------------------------------------------

# --- H.264 / libx264 (0-51) ---
H264_CRF_360_A=27 ; H264_CRF_360_B=23
H264_CRF_720_A=26 ; H264_CRF_720_B=22
H264_CRF_1080_A=25; H264_CRF_1080_B=21
H264_CRF_2K_A=24  ; H264_CRF_2K_B=20

# --- AV1 / libsvtav1 (0-63) ---
AV1_CRF_360_A=38 ; AV1_CRF_360_B=34
AV1_CRF_720_A=36 ; AV1_CRF_720_B=32
AV1_CRF_1080_A=35; AV1_CRF_1080_B=31
AV1_CRF_2K_A=34  ; AV1_CRF_2K_B=30

# --- VP9 / libvpx-vp9 (0-63) ---
VP9_CRF_360_A=36 ; VP9_CRF_360_B=32
VP9_CRF_720_A=32 ; VP9_CRF_720_B=28
VP9_CRF_1080_A=31; VP9_CRF_1080_B=27
VP9_CRF_2K_A=26  ; VP9_CRF_2K_B=22

# --- VBV ceilings (unchanged from the old -maxrate/-bufsize values) ---
CAP_360_A=980k   ; BUF_360_A=1400k
CAP_360_B=2100k  ; BUF_360_B=3000k
CAP_720_A=3150k  ; BUF_720_A=4500k
CAP_720_B=4900k  ; BUF_720_B=7000k
CAP_1080_A=13300k; BUF_1080_A=19000k
CAP_1080_B=16800k; BUF_1080_B=24000k
CAP_2K_A=21000k  ; BUF_2K_A=30000k
CAP_2K_B=28000k  ; BUF_2K_B=40000k


start_energy_meter() {
    local meter_output_file="$1"
    local gpu_log_file="${meter_output_file%/*}/gpu_power_log.csv"

    # RAPL counters via cham_monitor
    "${ENERGY_METER}" "${meter_output_file}" &
    ENERGY_METER_PID=$!
    echo "     [meter] started (PID ${ENERGY_METER_PID}) → ${meter_output_file}"
}


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


# ---------------------------------------------------------------------------
# Still needed for the VP9 two-pass path only. libx264 and libsvtav1 no
# longer produce or consume stats files in capped-CRF mode.
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
        _fan pass-360  0 1
        _fan pass-720  1 2 3
        _fan pass-1080 2 4 5
        _fan pass-2K   3 6 7
    )
}

# Shared split/scale graph for the 8-rung pass.
SPLIT8="[0:v]split=8[v0][v1][v2][v3][v4][v5][v6][v7]; \
        [v0]scale=640:360[v360-1];   [v1]scale=640:360[v360-2]; \
        [v2]scale=1280:720[v720-1];  [v3]scale=1280:720[v720-2]; \
        [v4]scale=1920:1080[v1080-1];[v5]scale=1920:1080[v1080-2]; \
        [v6]scale=2560:1440[v2K-1];  [v7]scale=2560:1440[v2K-2]"

SPLIT4="[0:v]split=4[v0][v2][v4][v6]; \
        [v0]scale=640:360[v360]; \
        [v2]scale=1280:720[v720]; \
        [v4]scale=1920:1080[v1080]; \
        [v6]scale=2560:1440[v2K]"

X264_PARAMS="keyint=60:min-keyint=60:scenecut=0:no-open-gop=1"

DASH_OPTS=(-use_template 1 -use_timeline 0
           -seg_duration 1 -frag_type duration -frag_duration 0.2
           -streaming 1 -ldash 1 -write_prft 1
           -target_latency 1
           -adaptation_sets "id=0,streams=v id=1,streams=a")


start_energy_meter ${job_dir}/energy.csv
echo "Started Energy Logging"
sleep $PRE_ENCODE_IDLE_S


if [ "$CODEC" = "h264" ]; then
    # ===================== H.264 / libx264 — capped CRF, single pass ========
    # -crf sets the quality target; -maxrate/-bufsize impose a VBV ceiling
    # that only engages on segments CRF alone would blow past. Both maxrate
    # and bufsize must be present or x264 ignores the cap.

    ffmpeg -i $INPUT \
	   -filter_complex "${SPLIT8}" \
	   \
	   -map "[v360-1]"  -c:v:0 libx264 -preset ${PRESET} -crf:v:0 ${H264_CRF_360_A}  -maxrate:v:0 ${CAP_360_A}  -bufsize:v:0 ${BUF_360_A}  -x264-params "${X264_PARAMS}" \
	   -map "[v360-2]"  -c:v:1 libx264 -preset ${PRESET} -crf:v:1 ${H264_CRF_360_B}  -maxrate:v:1 ${CAP_360_B}  -bufsize:v:1 ${BUF_360_B}  -x264-params "${X264_PARAMS}" \
	   -map "[v720-1]"  -c:v:2 libx264 -preset ${PRESET} -crf:v:2 ${H264_CRF_720_A}  -maxrate:v:2 ${CAP_720_A}  -bufsize:v:2 ${BUF_720_A}  -x264-params "${X264_PARAMS}" \
	   -map "[v720-2]"  -c:v:3 libx264 -preset ${PRESET} -crf:v:3 ${H264_CRF_720_B}  -maxrate:v:3 ${CAP_720_B}  -bufsize:v:3 ${BUF_720_B}  -x264-params "${X264_PARAMS}" \
	   -map "[v1080-1]" -c:v:4 libx264 -preset ${PRESET} -crf:v:4 ${H264_CRF_1080_A} -maxrate:v:4 ${CAP_1080_A} -bufsize:v:4 ${BUF_1080_A} -x264-params "${X264_PARAMS}" \
	   -map "[v1080-2]" -c:v:5 libx264 -preset ${PRESET} -crf:v:5 ${H264_CRF_1080_B} -maxrate:v:5 ${CAP_1080_B} -bufsize:v:5 ${BUF_1080_B} -x264-params "${X264_PARAMS}" \
	   -map "[v2K-1]"   -c:v:6 libx264 -preset ${PRESET} -crf:v:6 ${H264_CRF_2K_A}   -maxrate:v:6 ${CAP_2K_A}   -bufsize:v:6 ${BUF_2K_A}   -x264-params "${X264_PARAMS}" \
	   -map "[v2K-2]"   -c:v:7 libx264 -preset ${PRESET} -crf:v:7 ${H264_CRF_2K_B}   -maxrate:v:7 ${CAP_2K_B}   -bufsize:v:7 ${BUF_2K_B}   -x264-params "${X264_PARAMS}" \
	   \
	   "${DASH_OPTS[@]}" \
	   -f dash ${job_dir}/output.mpd


elif [ "$CODEC" = "av1" ]; then
    # ===================== AV1 / libsvtav1 — capped CRF, single pass =======
    # SVT-AV1 gained capped CRF in 1.7 (--crf + --mbr). ffmpeg's wrapper maps
    # -maxrate onto mbr, but only on reasonably recent builds. Check the SVT
    # config banner in the ffmpeg log for a BRC mode of CRF and a non-zero
    # max bitrate. If max bitrate reads 0, append mbr explicitly, e.g.
    #     -svtav1-params:v:0 scd=0:mbr=21000000
    # (mbr is in bits/sec). -b:v 0 is required to stay out of VBR mode.
    AV1_PRESET=8

    ffmpeg -i $INPUT \
	   -filter_complex "${SPLIT8}" \
	   \
	   -map "[v360-1]"  -c:v:0 libsvtav1 -preset:v:0 ${AV1_PRESET} -crf:v:0 ${AV1_CRF_360_A}  -b:v:0 0 -maxrate:v:0 ${CAP_360_A}  -bufsize:v:0 ${BUF_360_A}  -g:v:0 60 -svtav1-params:v:0 scd=0 \
	   -map "[v360-2]"  -c:v:1 libsvtav1 -preset:v:1 ${AV1_PRESET} -crf:v:1 ${AV1_CRF_360_B}  -b:v:1 0 -maxrate:v:1 ${CAP_360_B}  -bufsize:v:1 ${BUF_360_B}  -g:v:1 60 -svtav1-params:v:1 scd=0 \
	   -map "[v720-1]"  -c:v:2 libsvtav1 -preset:v:2 ${AV1_PRESET} -crf:v:2 ${AV1_CRF_720_A}  -b:v:2 0 -maxrate:v:2 ${CAP_720_A}  -bufsize:v:2 ${BUF_720_A}  -g:v:2 60 -svtav1-params:v:2 scd=0 \
	   -map "[v720-2]"  -c:v:3 libsvtav1 -preset:v:3 ${AV1_PRESET} -crf:v:3 ${AV1_CRF_720_B}  -b:v:3 0 -maxrate:v:3 ${CAP_720_B}  -bufsize:v:3 ${BUF_720_B}  -g:v:3 60 -svtav1-params:v:3 scd=0 \
	   -map "[v1080-1]" -c:v:4 libsvtav1 -preset:v:4 ${AV1_PRESET} -crf:v:4 ${AV1_CRF_1080_A} -b:v:4 0 -maxrate:v:4 ${CAP_1080_A} -bufsize:v:4 ${BUF_1080_A} -g:v:4 60 -svtav1-params:v:4 scd=0 \
	   -map "[v1080-2]" -c:v:5 libsvtav1 -preset:v:5 ${AV1_PRESET} -crf:v:5 ${AV1_CRF_1080_B} -b:v:5 0 -maxrate:v:5 ${CAP_1080_B} -bufsize:v:5 ${BUF_1080_B} -g:v:5 60 -svtav1-params:v:5 scd=0 \
	   -map "[v2K-1]"   -c:v:6 libsvtav1 -preset:v:6 ${AV1_PRESET} -crf:v:6 ${AV1_CRF_2K_A}   -b:v:6 0 -maxrate:v:6 ${CAP_2K_A}   -bufsize:v:6 ${BUF_2K_A}   -g:v:6 60 -svtav1-params:v:6 scd=0 \
	   -map "[v2K-2]"   -c:v:7 libsvtav1 -preset:v:7 ${AV1_PRESET} -crf:v:7 ${AV1_CRF_2K_B}   -b:v:7 0 -maxrate:v:7 ${CAP_2K_B}   -bufsize:v:7 ${BUF_2K_B}   -g:v:7 60 -svtav1-params:v:7 scd=0 \
	   \
	   "${DASH_OPTS[@]}" \
	   -f dash ${job_dir}/output.mpd


elif [ "$CODEC" = "vp9" ]; then
    # ===================== VP9 / libvpx-vp9 — constrained quality ==========
    # libvpx's capped-CRF equivalent is constrained quality: -crf N together
    # with a non-zero -b:v, where -b:v acts as the ceiling rather than a
    # target. -maxrate/-bufsize add the VBV constraint on top.
    #
    # Two passes are retained because libvpx's CQ rate control is much
    # better informed by first-pass stats. Reusing one resolution's stats
    # for both of its CRF rungs is safe here: libvpx's first pass is a
    # fixed-quantizer complexity analysis and ignores the rate-control
    # settings almost entirely.
    VP9_PASS1_CPU=4
    VP9_PASS2_CPU=4

    VP9_COMMON1="-deadline good -cpu-used ${VP9_PASS1_CPU} -g 60 -keyint_min 60 -row-mt 1 -tile-columns 2 -auto-alt-ref 1 -lag-in-frames 25"

    if [ "$VP9_TWO_PASS" = "1" ]; then
        ffmpeg -i $INPUT \
	       -filter_complex "${SPLIT4}" \
	       -map "[v360]"  -c:v:0 libvpx-vp9 -crf:v:0 ${VP9_CRF_360_A}  -b:v:0 ${CAP_360_A}  -deadline:v:0 good -cpu-used:v:0 ${VP9_PASS1_CPU} -g:v:0 60 -keyint_min:v:0 60 -row-mt:v:0 1 -tile-columns:v:0 2 -auto-alt-ref:v:0 1 -lag-in-frames:v:0 25 -pass 1 -passlogfile:v:0 ${job_dir}/pass-360  \
	       -map "[v720]"  -c:v:1 libvpx-vp9 -crf:v:1 ${VP9_CRF_720_A}  -b:v:1 ${CAP_720_A}  -deadline:v:1 good -cpu-used:v:1 ${VP9_PASS1_CPU} -g:v:1 60 -keyint_min:v:1 60 -row-mt:v:1 1 -tile-columns:v:1 2 -auto-alt-ref:v:1 1 -lag-in-frames:v:1 25 -pass 1 -passlogfile:v:1 ${job_dir}/pass-720  \
	       -map "[v1080]" -c:v:2 libvpx-vp9 -crf:v:2 ${VP9_CRF_1080_A} -b:v:2 ${CAP_1080_A} -deadline:v:2 good -cpu-used:v:2 ${VP9_PASS1_CPU} -g:v:2 60 -keyint_min:v:2 60 -row-mt:v:2 1 -tile-columns:v:2 2 -auto-alt-ref:v:2 1 -lag-in-frames:v:2 25 -pass 1 -passlogfile:v:2 ${job_dir}/pass-1080 \
	       -map "[v2K]"   -c:v:3 libvpx-vp9 -crf:v:3 ${VP9_CRF_2K_A}   -b:v:3 ${CAP_2K_A}   -deadline:v:3 good -cpu-used:v:3 ${VP9_PASS1_CPU} -g:v:3 60 -keyint_min:v:3 60 -row-mt:v:3 1 -tile-columns:v:3 2 -auto-alt-ref:v:3 1 -lag-in-frames:v:3 25 -pass 1 -passlogfile:v:3 ${job_dir}/pass-2K   \
	       -an -f null /dev/null

        echo "Done with Pass 1"
        link_pass_logs "${job_dir}" 0
        VP9_PASSOPT_PREFIX="-pass 2"
    else
        VP9_PASSOPT_PREFIX=""
    fi

    # Pass-2 (or single-pass) options per rung. When VP9_TWO_PASS=0 the
    # -pass/-passlogfile flags collapse away and this is a one-pass CQ run.
    _vp9_pass2() {   # $1 = stream idx, $2 = passlog basename
        if [ "$VP9_TWO_PASS" = "1" ]; then
            echo "-pass 2 -passlogfile:v:$1 ${job_dir}/$2"
        fi
    }

    ffmpeg -i $INPUT \
	   -filter_complex "${SPLIT8}" \
	   \
	   -map "[v360-1]"  -c:v:0 libvpx-vp9 -crf:v:0 ${VP9_CRF_360_A}  -b:v:0 ${CAP_360_A}  -maxrate:v:0 ${CAP_360_A}  -bufsize:v:0 ${BUF_360_A}  -deadline:v:0 good -cpu-used:v:0 ${VP9_PASS2_CPU} -g:v:0 60 -keyint_min:v:0 60 -row-mt:v:0 1 -tile-columns:v:0 2 -auto-alt-ref:v:0 1 -lag-in-frames:v:0 25 $(_vp9_pass2 0 pass-360) \
	   -map "[v360-2]"  -c:v:1 libvpx-vp9 -crf:v:1 ${VP9_CRF_360_B}  -b:v:1 ${CAP_360_B}  -maxrate:v:1 ${CAP_360_B}  -bufsize:v:1 ${BUF_360_B}  -deadline:v:1 good -cpu-used:v:1 ${VP9_PASS2_CPU} -g:v:1 60 -keyint_min:v:1 60 -row-mt:v:1 1 -tile-columns:v:1 2 -auto-alt-ref:v:1 1 -lag-in-frames:v:1 25 $(_vp9_pass2 1 pass-360) \
	   -map "[v720-1]"  -c:v:2 libvpx-vp9 -crf:v:2 ${VP9_CRF_720_A}  -b:v:2 ${CAP_720_A}  -maxrate:v:2 ${CAP_720_A}  -bufsize:v:2 ${BUF_720_A}  -deadline:v:2 good -cpu-used:v:2 ${VP9_PASS2_CPU} -g:v:2 60 -keyint_min:v:2 60 -row-mt:v:2 1 -tile-columns:v:2 2 -auto-alt-ref:v:2 1 -lag-in-frames:v:2 25 $(_vp9_pass2 2 pass-720) \
	   -map "[v720-2]"  -c:v:3 libvpx-vp9 -crf:v:3 ${VP9_CRF_720_B}  -b:v:3 ${CAP_720_B}  -maxrate:v:3 ${CAP_720_B}  -bufsize:v:3 ${BUF_720_B}  -deadline:v:3 good -cpu-used:v:3 ${VP9_PASS2_CPU} -g:v:3 60 -keyint_min:v:3 60 -row-mt:v:3 1 -tile-columns:v:3 2 -auto-alt-ref:v:3 1 -lag-in-frames:v:3 25 $(_vp9_pass2 3 pass-720) \
	   -map "[v1080-1]" -c:v:4 libvpx-vp9 -crf:v:4 ${VP9_CRF_1080_A} -b:v:4 ${CAP_1080_A} -maxrate:v:4 ${CAP_1080_A} -bufsize:v:4 ${BUF_1080_A} -deadline:v:4 good -cpu-used:v:4 ${VP9_PASS2_CPU} -g:v:4 60 -keyint_min:v:4 60 -row-mt:v:4 1 -tile-columns:v:4 2 -auto-alt-ref:v:4 1 -lag-in-frames:v:4 25 $(_vp9_pass2 4 pass-1080) \
	   -map "[v1080-2]" -c:v:5 libvpx-vp9 -crf:v:5 ${VP9_CRF_1080_B} -b:v:5 ${CAP_1080_B} -maxrate:v:5 ${CAP_1080_B} -bufsize:v:5 ${BUF_1080_B} -deadline:v:5 good -cpu-used:v:5 ${VP9_PASS2_CPU} -g:v:5 60 -keyint_min:v:5 60 -row-mt:v:5 1 -tile-columns:v:5 2 -auto-alt-ref:v:5 1 -lag-in-frames:v:5 25 $(_vp9_pass2 5 pass-1080) \
	   -map "[v2K-1]"   -c:v:6 libvpx-vp9 -crf:v:6 ${VP9_CRF_2K_A}   -b:v:6 ${CAP_2K_A}   -maxrate:v:6 ${CAP_2K_A}   -bufsize:v:6 ${BUF_2K_A}   -deadline:v:6 good -cpu-used:v:6 ${VP9_PASS2_CPU} -g:v:6 60 -keyint_min:v:6 60 -row-mt:v:6 1 -tile-columns:v:6 2 -auto-alt-ref:v:6 1 -lag-in-frames:v:6 25 $(_vp9_pass2 6 pass-2K) \
	   -map "[v2K-2]"   -c:v:7 libvpx-vp9 -crf:v:7 ${VP9_CRF_2K_B}   -b:v:7 ${CAP_2K_B}   -maxrate:v:7 ${CAP_2K_B}   -bufsize:v:7 ${BUF_2K_B}   -deadline:v:7 good -cpu-used:v:7 ${VP9_PASS2_CPU} -g:v:7 60 -keyint_min:v:7 60 -row-mt:v:7 1 -tile-columns:v:7 2 -auto-alt-ref:v:7 1 -lag-in-frames:v:7 25 $(_vp9_pass2 7 pass-2K) \
	   \
	   "${DASH_OPTS[@]}" \
	   -f dash ${job_dir}/output.mpd


else
    echo "Unknown CODEC '${CODEC}'. Supported: h264, av1, vp9" >&2
fi


sleep $POST_ENCODE_COOLDOWN_S
kill_energy_meter

echo "Killed Energy Logging"
