#!/usr/bin/env bash
# =============================================================================
# encode_benchmark_simultaneous.sh
# Encodes a directory of 4K MP4 files to LL-DASH with the FULL resolution +
# CRF ladder produced by ONE FFmpeg invocation per input file. All rungs share
# a single decode pass, a single scale-per-resolution, and a single LL-DASH
# manifest — i.e. the way real ABR transcoding pipelines work.
#
# Timing model per input file (NOT per rung):
#
#   [C program starts]
#         │
#         ├─── 30 s idle baseline window ───┤
#         │
#   [FFmpeg starts — encodes all rungs simultaneously]
#         │
#         ├─── encoding in progress ─────────┤
#         │
#   [FFmpeg exits]
#         │
#         ├─── 15 s cooldown window ─────────┤
#         │
#   [C program SIGKILL'd]
#
# Dependencies: ffmpeg (libsvtav1, libopus), ffprobe, bc, awk
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# CONFIGURATION
# ---------------------------------------------------------------------------

INPUT_DIR="/home/cc/videoDataSet/horizon_intro"
OUTPUT_BASE="${2:-./output}"
LOG_FILE="${OUTPUT_BASE}/benchmark_results.csv"

ENERGY_METER="/home/cc/cham_monitor"
ENERGY_METER_ARGS="${ENERGY_METER_ARGS:-}"

PRE_ENCODE_IDLE_S=30
POST_ENCODE_COOLDOWN_S=15
SEGMENT_DURATION=1
PRESET="6"

# Format: "LABEL WIDTH HEIGHT CRF_HQ CRF_LQ"
declare -a RESOLUTION_LADDER=(
    "480p   854   480   27  35"
    "720p  1280   720   28  36"
    "1080p 1920  1080   29  37"
    "2K    2560  1440   30  38"
    "4K    3840  2160   31  39"
)

# ---------------------------------------------------------------------------
# ENERGY METER LIFECYCLE (unchanged)
# ---------------------------------------------------------------------------

ENERGY_METER_PID=0

start_energy_meter() {
    local meter_output_file="$1"
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

trap 'kill_energy_meter' EXIT INT TERM ERR

# ---------------------------------------------------------------------------
# SIMULTANEOUS LADDER ENCODE — one FFmpeg per input file
# ---------------------------------------------------------------------------

# encode_all_rungs INPUT_FILE OUTPUT_DIR
encode_all_rungs() {
    local input_file="$1"
    local output_dir="$2"

    local base_name
    base_name=$(basename "${input_file}" .mp4)

    local job_dir="${output_dir}/all_rungs_av1"
    mkdir -p "${job_dir}"

    local manifest="${job_dir}/manifest.mpd"
    local meter_output="${job_dir}/energy.log"

    # Probe source height once so we can skip rungs above the source resolution.
    local source_height
    source_height=$(ffprobe -v error -select_streams v:0 \
        -show_entries stream=height -of csv=p=0 "${input_file}" 2>/dev/null || echo 9999)

    # Collect resolutions that fit. Each entry carries both CRFs (HQ + LQ).
    local -a applicable_resolutions=()
    for row in "${RESOLUTION_LADDER[@]}"; do
        read -r label width height crf_hq crf_lq <<< "${row}"
        if (( source_height < height )); then
            echo "  → [${label}] Skipped (source ${source_height}p < target ${height}p)"
            continue
        fi
        applicable_resolutions+=("${label}|${width}|${height}|${crf_hq}|${crf_lq}")
    done

    local n_res=${#applicable_resolutions[@]}
    if (( n_res == 0 )); then
        echo "  → No applicable rungs for ${base_name}; skipping."
        return
    fi
    local n_rungs=$(( n_res * 2 ))
    echo "  → ${base_name}: encoding ${n_rungs} rungs (${n_res} resolutions × 2 CRFs) simultaneously"

    # ----------------------------------------------------------------------
    # BUILD FILTERGRAPH
    #   1. split source into N copies (decode once, fan out)
    #   2. scale each copy to its target resolution
    #   3. split each scaled copy into 2 (HQ + LQ share the scale work)
    # ----------------------------------------------------------------------
    local filter_complex="[0:v]split=${n_res}"
    for ((i=0; i<n_res; i++)); do
        filter_complex+="[v${i}]"
    done
    filter_complex+=";"

    for ((i=0; i<n_res; i++)); do
        IFS='|' read -r label width height crf_hq crf_lq <<< "${applicable_resolutions[$i]}"
        filter_complex+="[v${i}]scale=${width}:${height}:flags=lanczos,setsar=1,split=2[r${i}_hq][r${i}_lq]"
        if (( i < n_res - 1 )); then
            filter_complex+=";"
        fi
    done

    # ----------------------------------------------------------------------
    # BUILD PER-OUTPUT -map AND CODEC ARGS
    # Output stream order:  r0_hq, r0_lq, r1_hq, r1_lq, ...
    # ----------------------------------------------------------------------
    local -a output_args=()
    local stream_idx=0
    for ((i=0; i<n_res; i++)); do
        IFS='|' read -r label width height crf_hq crf_lq <<< "${applicable_resolutions[$i]}"
        for tier in hq lq; do
            local crf
            if [[ "$tier" == "hq" ]]; then crf="${crf_hq}"; else crf="${crf_lq}"; fi
            output_args+=(
                -map "[r${i}_${tier}]"
                -c:v:"${stream_idx}"            libsvtav1
                -preset:v:"${stream_idx}"       "${PRESET}"
                -crf:v:"${stream_idx}"          "${crf}"
                -svtav1-params:v:"${stream_idx}" "keyint=60:scd=0:fast-decode=1"
                -b:v:"${stream_idx}"            0
                -g:v:"${stream_idx}"            60
            )
            echo "     · stream ${stream_idx}: ${label} ${width}x${height} CRF${crf}"
            stream_idx=$(( stream_idx + 1 ))
        done
    done

    # One shared audio track across the whole DASH presentation.
    output_args+=(
        -map 0:a
        -c:a libopus
        -b:a 128k
        -ar 48000
    )

    # ----------------------------------------------------------------------
    # PHASE 1 — energy meter + idle baseline
    # ----------------------------------------------------------------------
    start_energy_meter "${meter_output}"
    echo "     [meter] idle baseline: sleeping ${PRE_ENCODE_IDLE_S}s ..."
    sleep "${PRE_ENCODE_IDLE_S}"

    # ----------------------------------------------------------------------
    # PHASE 2 — single FFmpeg invocation, all rungs at once
    # ----------------------------------------------------------------------
    echo "     [ffmpeg] encoding ${n_rungs} rungs in parallel ..."
    local t_start t_end elapsed_s
    t_start=$(date +%s%N)

    ffmpeg -y \
        -i "${input_file}" \
        -filter_complex "${filter_complex}" \
        "${output_args[@]}" \
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

    # ----------------------------------------------------------------------
    # PHASE 3 — cooldown + meter kill
    # ----------------------------------------------------------------------
    echo "     [meter] cooldown: sleeping ${POST_ENCODE_COOLDOWN_S}s ..."
    sleep "${POST_ENCODE_COOLDOWN_S}"
    kill_energy_meter

    # ----------------------------------------------------------------------
    # BOOKKEEPING
    # One CSV row per rung; all rows for a given input file share the same
    # energy_log and encode_time_s because they were measured as one job.
    # ----------------------------------------------------------------------
    local total_bytes
    total_bytes=$(du -sb "${job_dir}" | awk '{print $1}')

    stream_idx=0
    for ((i=0; i<n_res; i++)); do
        IFS='|' read -r label width height crf_hq crf_lq <<< "${applicable_resolutions[$i]}"
        for tier in hq lq; do
            local crf
            if [[ "$tier" == "hq" ]]; then crf="${crf_hq}"; else crf="${crf_lq}"; fi
            printf '%s,%s,%s,%s,%d,%s,%d,%s,%d\n' \
                "${base_name}"        \
                "${label}"            \
                "${crf}"              \
                "${PRESET}"           \
                "${SEGMENT_DURATION}" \
                "${elapsed_s}"        \
                "${stream_idx}"       \
                "${meter_output}"     \
                "${total_bytes}"      \
                >> "${LOG_FILE}"
            stream_idx=$(( stream_idx + 1 ))
        done
    done

    echo "     energy log     → ${meter_output}"
    echo "     manifest       → ${manifest}"
    echo "     total output   → $(numfmt --to=iec-i --suffix=B "${total_bytes}")"
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
        exit 1
    fi

    mkdir -p "${OUTPUT_BASE}"

    # CSV header. Note: with simultaneous encoding, every rung of a given
    # input file shares the same energy_log, encode_time_s, total_output_bytes.
    echo "file,resolution,crf,preset,segment_duration_s,encode_time_s,stream_index,energy_log,total_output_bytes" \
        > "${LOG_FILE}"

    echo "============================================================="
    echo " LL-DASH Simultaneous-Ladder Encoding Energy Benchmark (AV1)"
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

        encode_all_rungs "${input_file}" "${file_output_dir}"
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
