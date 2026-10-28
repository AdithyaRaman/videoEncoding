#!/bin/bash
# ===========================================================================
# Capped CRF ladder encoding — FULL ladder (SD + HD + UHD) in one ffmpeg run
#
# Usage: ./run_crf_full.sh <input.mp4> <h264|av1|vp9>
#
# One decode, one filtergraph, N encoders, one DASH manifest:
#
#   H.264 : 12 rungs — 144/240/360/480/720/1080, two rungs each (A + B)
#   AV1   :  8 rungs — one rung (A) per resolution
#   VP9   :  8 rungs — one rung (A) per resolution
#
# ffmpeg arguments are assembled into a bash array rather than one long
# backslash-continued command: a stray blank line or trailing space after a
# "\" silently truncates a continued command, and at 14 rungs that failure
# is essentially impossible to spot by eye.
# ===========================================================================

ENERGY_METER="/home/cc/bin/cham_monitor"

INPUT="$1"
CODEC="$2"
PRESET="medium"

if [[ -z "${INPUT}" || -z "${CODEC}" ]]; then
    echo "Usage: $0 <input.mp4> <h264|av1|vp9>" >&2
    exit 1
fi

base_name=$(basename "${INPUT}" .mp4)

OUTPUT_BASE="./output"        # Root output directory
job_dir="${OUTPUT_BASE}/${base_name}/FULL_${CODEC}"
mkdir -p "${job_dir}"

# Idle baseline window before FFmpeg starts (seconds)
PRE_ENCODE_IDLE_S=10

# Cooldown window after FFmpeg exits before the C program is killed (seconds)
POST_ENCODE_COOLDOWN_S=10

ENERGY_METER_PID=0

# ---------------------------------------------------------------------------
# THE LADDER
#
#   rung "A" = cheaper rung  -> higher CRF, lower ceiling
#   rung "B" = better rung   -> lower  CRF, higher ceiling
#
# CRF is held constant across resolutions so the ceiling is the only thing
# that varies down the ladder. CRF scales are NOT comparable across codecs:
# x264 is 0-51; SVT-AV1 and libvpx-vp9 are both 0-63 with different operating
# ranges. Google's per-resolution VP9 CQ table would suggest 37/36/33/32/31/24
# for 240/360/480/720/1080/1440 — substitute below if you want that instead.
# ---------------------------------------------------------------------------

# --- H.264 / libx264 (0-51) ---
H264_CRF_A=30
H264_CRF_B=24

# --- AV1 / libsvtav1 (0-63) ---
AV1_CRF_A=42

# --- VP9 / libvpx-vp9 (0-63) ---
VP9_CRF_A=42

# --- H.264 ceilings (cap / bufsize, bufsize = 2x cap) ---
H264_CAP_144_A=50k    ; H264_BUF_144_A=100k
H264_CAP_144_B=120k   ; H264_BUF_144_B=240k
H264_CAP_240_A=140k   ; H264_BUF_240_A=280k
H264_CAP_240_B=200k   ; H264_BUF_240_B=400k
H264_CAP_360_A=250k   ; H264_BUF_360_A=500k
H264_CAP_360_B=400k   ; H264_BUF_360_B=800k
H264_CAP_480_A=550k   ; H264_BUF_480_A=1100k
H264_CAP_480_B=700k   ; H264_BUF_480_B=1400k
H264_CAP_720_A=1000k  ; H264_BUF_720_A=2000k
H264_CAP_720_B=1500k  ; H264_BUF_720_B=3000k
H264_CAP_1080_A=2000k ; H264_BUF_1080_A=4000k
H264_CAP_1080_B=3000k ; H264_BUF_1080_B=6000k
#H264_CAP_1440_A=4000k ; H264_BUF_1440_A=8000k
#H264_CAP_1440_B=6000k ; H264_BUF_1440_B=12000k

# --- VP9 ceilings ---
VP9_CAP_144_A=40k     ; VP9_BUF_144_A=80k
VP9_CAP_240_A=135k    ; VP9_BUF_240_A=270k
VP9_CAP_360_A=280k    ; VP9_BUF_360_A=560k
VP9_CAP_480_A=500k    ; VP9_BUF_480_A=1000k
VP9_CAP_720_A=900k    ; VP9_BUF_720_A=1800k
VP9_CAP_1080_A=1800k  ; VP9_BUF_1080_A=3600k
VP9_CAP_1440_A=3600k  ; VP9_BUF_1440_A=7200k
VP9_CAP_2160_A=7600k  ; VP9_BUF_2160_A=14000k

# --- AV1 ceilings ---
AV1_CAP_144_A=20k     ; AV1_BUF_144_A=40k
AV1_CAP_240_A=85k    ; AV1_BUF_240_A=170k
AV1_CAP_360_A=150k    ; AV1_BUF_360_A=300k
AV1_CAP_480_A=200k    ; AV1_BUF_480_A=500k
AV1_CAP_720_A=500k    ; AV1_BUF_720_A=1400k
AV1_CAP_1080_A=1000k  ; AV1_BUF_1080_A=2300k
AV1_CAP_1440_A=2600k  ; AV1_BUF_1440_A=5200k
AV1_CAP_2160_A=5600k  ; AV1_BUF_2160_A=10000k

# --- Encoder speed knobs ---
AV1_PRESET=3
VP9_CPU=1

X264_PARAMS="keyint=60:min-keyint=60:scenecut=0:no-open-gop=1"

# With 14 concurrent encoders feeding one muxer the default muxing queue can
# overflow on bursty inputs. Raise it rather than debugging it later.
MUX_QUEUE=4096

# ---------------------------------------------------------------------------
# Energy meter
# ---------------------------------------------------------------------------
start_energy_meter() {
    local meter_output_file="$1"
    "${ENERGY_METER}" "${meter_output_file}" &
    ENERGY_METER_PID=$!
    echo "     [meter] started (PID ${ENERGY_METER_PID}) -> ${meter_output_file}"
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

# Make sure the meter never outlives the script, even on Ctrl-C or an error.
trap kill_energy_meter EXIT INT TERM

# ---------------------------------------------------------------------------
# Rung builders — stream-index bookkeeping happens here, once
# ---------------------------------------------------------------------------
IDX=0   # auto-incrementing output video stream index

h264_rung() {   # label  crf  cap  buf
    FF_ARGS+=(-map "[$1]"
              -c:v:"${IDX}" libx264
              -preset:v:"${IDX}" "${PRESET}"
              -crf:v:"${IDX}" "$2"
              -maxrate:v:"${IDX}" "$3"
              -bufsize:v:"${IDX}" "$4"
              -x264-params:v:"${IDX}" "${X264_PARAMS}")
    (( IDX++ ))
}

av1_rung() {    # label  crf  cap  buf
    # -b:v 0 is mandatory or SVT-AV1 drops out of CRF mode into VBR.
    FF_ARGS+=(-map "[$1]"
              -c:v:"${IDX}" libsvtav1
              -preset:v:"${IDX}" "${AV1_PRESET}"
              -crf:v:"${IDX}" "$2"
              -b:v:"${IDX}" 0
              -maxrate:v:"${IDX}" "$3"
              -bufsize:v:"${IDX}" "$4"
              -g:v:"${IDX}" 60
              -svtav1-params:v:"${IDX}" scd=0)
    (( IDX++ ))
}

vp9_rung() {    # label  crf  cap  buf  tile_columns
    # libvpx constrained quality: -crf with a non-zero -b:v acting as ceiling.
    # tile-columns is log2(columns) and each column needs >=256px, so it is
    # passed per-rung rather than pinned at one value for the whole ladder.
    FF_ARGS+=(-map "[$1]"
              -c:v:"${IDX}" libvpx-vp9
              -crf:v:"${IDX}" "$2"
              -b:v:"${IDX}" "$3"
              -maxrate:v:"${IDX}" "$3"
              -bufsize:v:"${IDX}" "$4"
              -deadline:v:"${IDX}" good
              -cpu-used:v:"${IDX}" "${VP9_CPU}"
              -g:v:"${IDX}" 60
              -keyint_min:v:"${IDX}" 60
              -row-mt:v:"${IDX}" 1
              -tile-columns:v:"${IDX}" "$5"
              -auto-alt-ref:v:"${IDX}" 1
              -lag-in-frames:v:"${IDX}" 25)
    (( IDX++ ))
}

# ---------------------------------------------------------------------------
# Audio: only declare an audio adaptation set if the source actually has one.
# ---------------------------------------------------------------------------
if ffprobe -v error -select_streams a:0 -show_entries stream=index \
           -of csv=p=0 "${INPUT}" 2>/dev/null | grep -q .; then
    AUDIO_ARGS=(-map 0:a:0 -c:a aac -b:a 128k)
    ADAPTATION_SETS="id=0,streams=v id=1,streams=a"
else
    AUDIO_ARGS=()
    ADAPTATION_SETS="id=0,streams=v"
fi

DASH_OPTS=(-use_template 1
           -use_timeline 0
           -seg_duration 4
           -streaming 1
           -write_prft 1
           -adaptation_sets "${ADAPTATION_SETS}")

# ---------------------------------------------------------------------------
# Filtergraphs — one decode, split N ways, scale each branch once
# ---------------------------------------------------------------------------
SPLIT14_H264="[0:v]split=12[s0][s1][s2][s3][s4][s5][s6][s7][s8][s9][s10][s11]; \
              [s0]scale=256:144[v144-1];    [s1]scale=256:144[v144-2]; \
              [s2]scale=426:240[v240-1];    [s3]scale=426:240[v240-2]; \
              [s4]scale=640:360[v360-1];    [s5]scale=640:360[v360-2]; \
              [s6]scale=854:480[v480-1];    [s7]scale=854:480[v480-2]; \
              [s8]scale=1280:720[v720-1];   [s9]scale=1280:720[v720-2]; \
              [s10]scale=1920:1080[v1080-1];[s11]scale=1920:1080[v1080-2]"

SPLIT7_AV1_VP9="[0:v]split=8[s0][s1][s2][s3][s4][s5][s6][s7]; \
                [s0]scale=256:144[v144-1]; \
                [s1]scale=426:240[v240-1]; \
                [s2]scale=640:360[v360-1]; \
                [s3]scale=854:480[v480-1]; \
                [s4]scale=1280:720[v720-1]; \
                [s5]scale=1920:1080[v1080-1]; \
                [s6]scale=2560:1440[v1440-1]; \
		[s7]scale=3840:2160[v2160-1]"

# ---------------------------------------------------------------------------
# Build the job
# ---------------------------------------------------------------------------
FF_ARGS=(-hide_banner -i "${INPUT}")

case "${CODEC}" in
    h264)
        # Capped CRF: -crf sets quality, -maxrate/-bufsize impose a VBV
        # ceiling that engages only where CRF alone would overshoot. Both
        # maxrate and bufsize must be present or x264 ignores the cap.
        FF_ARGS+=(-filter_complex "${SPLIT14_H264}")
        h264_rung v144-1  "${H264_CRF_A}" "${H264_CAP_144_A}"  "${H264_BUF_144_A}"
        h264_rung v144-2  "${H264_CRF_B}" "${H264_CAP_144_B}"  "${H264_BUF_144_B}"
        h264_rung v240-1  "${H264_CRF_A}" "${H264_CAP_240_A}"  "${H264_BUF_240_A}"
        h264_rung v240-2  "${H264_CRF_B}" "${H264_CAP_240_B}"  "${H264_BUF_240_B}"
        h264_rung v360-1  "${H264_CRF_A}" "${H264_CAP_360_A}"  "${H264_BUF_360_A}"
        h264_rung v360-2  "${H264_CRF_B}" "${H264_CAP_360_B}"  "${H264_BUF_360_B}"
        h264_rung v480-1  "${H264_CRF_A}" "${H264_CAP_480_A}"  "${H264_BUF_480_A}"
        h264_rung v480-2  "${H264_CRF_B}" "${H264_CAP_480_B}"  "${H264_BUF_480_B}"
        h264_rung v720-1  "${H264_CRF_A}" "${H264_CAP_720_A}"  "${H264_BUF_720_A}"
        h264_rung v720-2  "${H264_CRF_B}" "${H264_CAP_720_B}"  "${H264_BUF_720_B}"
        h264_rung v1080-1 "${H264_CRF_A}" "${H264_CAP_1080_A}" "${H264_BUF_1080_A}"
        h264_rung v1080-2 "${H264_CRF_B}" "${H264_CAP_1080_B}" "${H264_BUF_1080_B}"
        #h264_rung v1440-1 "${H264_CRF_A}" "${H264_CAP_1440_A}" "${H264_BUF_1440_A}"
        #h264_rung v1440-2 "${H264_CRF_B}" "${H264_CAP_1440_B}" "${H264_BUF_1440_B}"
        ;;
    av1)
        # SVT-AV1 capped CRF (--crf + --mbr) landed in 1.7. ffmpeg maps
        # -maxrate onto mbr on recent builds only. Check the SVT config
        # banner for BRC mode CRF and a non-zero max bitrate; if it reads 0,
        # append it explicitly, e.g. -svtav1-params:v:0 scd=0:mbr=40000
        FF_ARGS+=(-filter_complex "${SPLIT7_AV1_VP9}")
        av1_rung v144-1  "${AV1_CRF_A}" "${AV1_CAP_144_A}"  "${AV1_BUF_144_A}"
        av1_rung v240-1  "${AV1_CRF_A}" "${AV1_CAP_240_A}"  "${AV1_BUF_240_A}"
        av1_rung v360-1  "${AV1_CRF_A}" "${AV1_CAP_360_A}"  "${AV1_BUF_360_A}"
        av1_rung v480-1  "${AV1_CRF_A}" "${AV1_CAP_480_A}"  "${AV1_BUF_480_A}"
        av1_rung v720-1  "${AV1_CRF_A}" "${AV1_CAP_720_A}"  "${AV1_BUF_720_A}"
        av1_rung v1080-1 "${AV1_CRF_A}" "${AV1_CAP_1080_A}" "${AV1_BUF_1080_A}"
        av1_rung v1440-1 "${AV1_CRF_A}" "${AV1_CAP_1440_A}" "${AV1_BUF_1440_A}"
	av1_rung v2160-1 "${AV1_CRF_A}" "${AV1_CAP_2160_A}" "${AV1_BUF_2160_A}"
        ;;
    vp9)
        FF_ARGS+=(-filter_complex "${SPLIT7_AV1_VP9}")
        #         label     crf              cap                 buf                 tile-cols
        vp9_rung  v144-1  "${VP9_CRF_A}" "${VP9_CAP_144_A}"  "${VP9_BUF_144_A}"  0
        vp9_rung  v240-1  "${VP9_CRF_A}" "${VP9_CAP_240_A}"  "${VP9_BUF_240_A}"  0
        vp9_rung  v360-1  "${VP9_CRF_A}" "${VP9_CAP_360_A}"  "${VP9_BUF_360_A}"  1
        vp9_rung  v480-1  "${VP9_CRF_A}" "${VP9_CAP_480_A}"  "${VP9_BUF_480_A}"  1
        vp9_rung  v720-1  "${VP9_CRF_A}" "${VP9_CAP_720_A}"  "${VP9_BUF_720_A}"  2
        vp9_rung  v1080-1 "${VP9_CRF_A}" "${VP9_CAP_1080_A}" "${VP9_BUF_1080_A}" 2
        vp9_rung  v1440-1 "${VP9_CRF_A}" "${VP9_CAP_1440_A}" "${VP9_BUF_1440_A}" 3
	vp9_rung  v2160-1 "${VP9_CRF_A}" "${VP9_CAP_2160_A}" "${VP9_BUF_2160_A}" 3
        ;;
    *)
        echo "Unknown CODEC '${CODEC}'. Supported: h264, av1, vp9" >&2
        exit 1
        ;;
esac

FF_ARGS+=("${AUDIO_ARGS[@]}"
          -max_muxing_queue_size "${MUX_QUEUE}"
          "${DASH_OPTS[@]}"
          -f dash "${job_dir}/output.mpd")

echo "Ladder: ${IDX} video rungs (${CODEC})"

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
start_energy_meter "${job_dir}/energy.csv"
echo "Started Energy Logging"
sleep "${PRE_ENCODE_IDLE_S}"

ffmpeg "${FF_ARGS[@]}"
ff_status=$?
echo "ffmpeg exited with status ${ff_status}"

sleep "${POST_ENCODE_COOLDOWN_S}"
kill_energy_meter
# trap - EXIT INT TERM

echo "Killed Energy Logging"
exit "${ff_status}"
