#!/usr/bin/env bash
# =============================================================================
# encode_benchmark.sh
# Encodes a directory of 4K MP4 files to LL-DASH at multiple resolutions and
# two CRF levels per resolution, measuring energy cost via an external C program.
#
# Timing model per encode job:
#
#   [C program starts]
#         │
#         ├─── 30 s idle baseline window ───┤
#         │
#   [FFmpeg starts]
#         │
#         ├─── encoding in progress ─────────┤
#         │
#   [FFmpeg exits]
#         │
#         ├─── 15 s cooldown window ─────────┤
#         │
#   [C program SIGKILL'd]
#
# Dependencies: ffmpeg, ffprobe, bc, awk
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# CONFIGURATION — edit these to match your environment
# ---------------------------------------------------------------------------

#INPUT_DIR="/home/cc/workspace/videoDataSet/concat_videos/"          # Directory containing your 10 x 4K MP4s
INPUT_DIR="/home/cc/videoDataSet/horizon_intro"
OUTPUT_BASE="${2:-./output}"       # Root output directory
LOG_FILE="${OUTPUT_BASE}/benchmark_results.csv"

# Path to your compiled C energy measurement binary.
# Override at runtime:  ENERGY_METER=/path/to/binary ./encode_benchmark.sh ...
ENERGY_METER="/home/cc/cham_monitor"

# Optional extra arguments forwarded to the C program on every invocation.
# The per-job output file path is always appended as the final argument.
# Example:  ENERGY_METER_ARGS="--sample-rate 100 --interface pcie"
ENERGY_METER_ARGS="${ENERGY_METER_ARGS:-}"

# Idle baseline window before FFmpeg starts (seconds)
PRE_ENCODE_IDLE_S=30

# Cooldown window after FFmpeg exits before the C program is killed (seconds)
POST_ENCODE_COOLDOWN_S=15

# Segment duration for LL-DASH (seconds)
SEGMENT_DURATION=1

# H.264 preset — slower = better compression, more CPU energy
# Options: ultrafast, superfast, veryfast, faster, fast, medium, slow, slower
PRESET="6"

# CRF ladder: two CRF values per resolution (lower = higher quality, more bits)
# Format: "LABEL WIDTH HEIGHT CRF_HQ CRF_LQ"

declare -a RESOLUTION_LADDER=(
    "480p   854   480   27  35"
    "720p  1280   720   28  36"
    "1080p 1920  1080   29  37"
    "2K    2560  1440   30  38"
    "4K    3840  2160   31  39"
)

# ---------------------------------------------------------------------------
# ENERGY METER LIFECYCLE
# ---------------------------------------------------------------------------

# PID of the currently running C energy meter process (0 = none running)
ENERGY_METER_PID=0

# Start the C energy meter, passing the per-job output file as the last arg.
# Stores the background PID in ENERGY_METER_PID.
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

# Safety net: always kill the meter if the script exits for any reason,
# including unhandled errors, Ctrl-C, or external SIGTERM.
trap 'kill_energy_meter' EXIT INT TERM ERR

# ---------------------------------------------------------------------------
# SINGLE ENCODE JOB
# ---------------------------------------------------------------------------

# encode_job INPUT_FILE OUTPUT_DIR LABEL WIDTH HEIGHT CRF
encode_job() {
    local input_file="$1"
    local output_dir="$2"
    local label="$3"
    local width="$4"
    local height="$5"
    local crf="$6"

    local base_name
    base_name=$(basename "${input_file}" .mp4)

    local job_dir="${output_dir}/${label}_crf${crf}_av2"
    mkdir -p "${job_dir}"

    local manifest="${job_dir}/manifest.mpd"
    local meter_output="${job_dir}/energy.log"   # C program writes its data here

    echo "  → [${label} CRF${crf}] ${base_name}"

    # ------------------------------------------------------------------
    # PHASE 1 — start the C energy meter, then wait 30 s idle baseline
    # ------------------------------------------------------------------
    start_energy_meter "${meter_output}"

    echo "     [meter] idle baseline: sleeping ${PRE_ENCODE_IDLE_S}s ..."
    sleep "${PRE_ENCODE_IDLE_S}"

    # ------------------------------------------------------------------
    # PHASE 2 — run FFmpeg; block until it exits naturally
    # ------------------------------------------------------------------
    echo "     [ffmpeg] encoding started ..."
    local t_start t_end elapsed_s
    t_start=$(date +%s%N)

    # LL-DASH encode
    # Key flags:
    #   -ldash 1            → Low Latency DASH mode
    #   -streaming 1        → chunked streaming output
    #   -seg_duration 1     → 1-second segments
    #   -use_template 1     → SegmentTemplate addressing
    #   -use_timeline 0     → no SegmentTimeline (required for LL-DASH)
    #   -frag_duration 0.1  → 100 ms chunks within each segment
    #   -write_prft 1       → ProducerReferenceTime for latency diagnostics

    ffmpeg -y \
        -i "${input_file}" \
        -c:v libsvtav1 \
        -preset "${PRESET}" \
        -crf "${crf}" \
        -vf "scale=${width}:${height}:flags=lanczos,setsar=1" \
        -g 60 \
        -svtav1-params "keyint=60:scd=0:fast-decode=1" \
        -b:v 0 \
        -c:a libopus \
        -b:a 128k \
        -ar 48000 \
        -f dash \
        -ldash 1 \
        -streaming 1 \
        -seg_duration "${SEGMENT_DURATION}" \
        -frag_duration 0.1 \
        -use_template 1 \
        -use_timeline 0 \
        -write_prft 1 \
        -adaptation_sets "id=0,streams=v id=1,streams=a" \
        "${manifest}" \
        2>"${job_dir}/ffmpeg.log"
        

    t_end=$(date +%s%N)
    elapsed_s=$(echo "scale=4; (${t_end} - ${t_start}) / 1000000000" | bc)
    echo "     [ffmpeg] finished in ${elapsed_s}s"

    # ------------------------------------------------------------------
    # PHASE 3 — cooldown window, then SIGKILL the energy meter
    # ------------------------------------------------------------------
    echo "     [meter] cooldown: sleeping ${POST_ENCODE_COOLDOWN_S}s ..."
    sleep "${POST_ENCODE_COOLDOWN_S}"

    kill_energy_meter

    # ------------------------------------------------------------------
    # BOOKKEEPING — output size, encoded bitrate, CSV row
    # ------------------------------------------------------------------
    local total_bytes
    total_bytes=$(du -sb "${job_dir}" | awk '{print $1}')

    local encoded_bitrate="N/A"
    if grep -q "bitrate:" "${job_dir}/ffmpeg.log" 2>/dev/null; then
        encoded_bitrate=$(grep "bitrate:" "${job_dir}/ffmpeg.log" \
            | tail -1 | sed 's/.*bitrate: //' | awk '{print $1, $2}')
    fi

    # energy_log column records the path so results can be joined with the
    # C program's own output in post-processing
    printf '%s,%s,%s,%s,%d,%s,%s,%s,%d\n' \
        "${base_name}"        \
        "${label}"            \
        "${crf}"              \
        "${PRESET}"           \
        "${SEGMENT_DURATION}" \
        "${elapsed_s}"        \
        "${encoded_bitrate}"  \
        "${meter_output}"     \
        "${total_bytes}"      \
        >> "${LOG_FILE}"

    echo "     energy log → ${meter_output}"
    echo "     output size → $(numfmt --to=iec-i --suffix=B "${total_bytes}")"
}

# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------

main() {
    if [[ ! -d "${INPUT_DIR}" ]]; then
        echo "ERROR: Input directory '${INPUT_DIR}' not found."
        echo "Usage: $0 <input_dir> [output_base_dir]"
        echo "       ENERGY_METER=/path/to/binary $0 ..."
        exit 1
    fi

    if ! command -v ffmpeg &>/dev/null; then
        echo "ERROR: ffmpeg not found in PATH."
        exit 1
    fi

    if [[ ! -x "${ENERGY_METER}" ]]; then
        echo "ERROR: Energy meter binary not found or not executable: '${ENERGY_METER}'"
        echo "Set the ENERGY_METER environment variable to its path, e.g.:"
        echo "  ENERGY_METER=/path/to/energy_meter $0 ..."
        exit 1
    fi

    mkdir -p "${OUTPUT_BASE}"

    # CSV header — energy_log column stores the path to the C program's output
    # file for each job so measurements can be joined in post-processing
    echo "file,resolution,crf,preset,segment_duration_s,encode_time_s,encoded_bitrate,energy_log,output_bytes" \
        > "${LOG_FILE}"

    echo "============================================================="
    echo " LL-DASH Encoding Energy Benchmark"
    echo " Input dir    : ${INPUT_DIR}"
    echo " Output dir   : ${OUTPUT_BASE}"
    echo " Energy meter : ${ENERGY_METER}"
    echo " Pre-encode   : ${PRE_ENCODE_IDLE_S}s idle baseline"
    echo " Post-encode  : ${POST_ENCODE_COOLDOWN_S}s cooldown"
    echo "============================================================="
    echo ""

    mapfile -t INPUT_FILES < <(find "${INPUT_DIR}" -maxdepth 1 -name "*.mp4" | sort | head -10)

    if [[ ${#INPUT_FILES[@]} -eq 0 ]]; then
        echo "ERROR: No .mp4 files found in '${INPUT_DIR}'."
        exit 1
    fi

    echo "Found ${#INPUT_FILES[@]} input file(s)."
    echo ""

    local file_index=0
    for input_file in "${INPUT_FILES[@]}"; do
        file_index=$(( file_index + 1 ))
        local base_name
        base_name=$(basename "${input_file}" .mp4)

        echo "[$file_index/${#INPUT_FILES[@]}] Processing: ${base_name}"

        local file_output_dir="${OUTPUT_BASE}/${base_name}"
        mkdir -p "${file_output_dir}"

        for row in "${RESOLUTION_LADDER[@]}"; do
            read -r label width height crf_hq crf_lq <<< "${row}"

            # Skip resolutions above the source height to avoid measuring
            # upscaling cost as part of the encode ladder.
            # Remove this block if upscaling tests are intentional.
            local source_height
            source_height=$(ffprobe -v error -select_streams v:0 \
                -show_entries stream=height -of csv=p=0 "${input_file}" 2>/dev/null || echo 9999)
            if (( source_height < height )); then
                echo "  → [${label}] Skipped (source ${source_height}p < target ${height}p)"
                continue
            fi

            encode_job "${input_file}" "${file_output_dir}" "${label}" \
                       "${width}" "${height}" "${crf_hq}"

            encode_job "${input_file}" "${file_output_dir}" "${label}" \
                       "${width}" "${height}" "${crf_lq}"
        done

        echo ""
    done

    echo "============================================================="
    echo " Benchmark complete."
    echo " Results CSV : ${LOG_FILE}"
    echo "============================================================="

    echo ""
    echo "Summary (file | resolution | crf | encode_time_s | energy_log):"
    awk -F',' 'NR>1 { printf "  %-30s %-6s CRF%-3s  %8ss  %s\n",
        $1, $2, $3, $6, $8 }' "${LOG_FILE}"
}

main "$@"
