#!/bin/bash

# HLA-TypePipe: High-resolution HLA genotyping from RNA-seq
# See README.md for usage

set -euo pipefail

# Default values
THREADS=8
TIMEOUT=600
HLA_GENES=("A" "B" "C" "DQA1" "DQB1" "DRB1" "DRA" "DPA1" "DPB1")

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Required:
    --input-dir DIR      Directory containing paired FASTQ files
    --index-dir DIR      HISAT-genotype index directory
    --output-dir DIR     Output directory for results

Optional:
    --threads N          Threads per gene (default: 8)
    --timeout N          Timeout per gene in seconds (default: 600)
    --genes LIST         Comma-separated gene list (default: A,B,C,DQA1,DQB1,DRB1,DRA,DPA1,DPB1)
    --help               Show this message

EOF
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --input-dir)
            INPUT_DIR="$2"
            shift 2
            ;;
        --index-dir)
            INDEX_DIR="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --threads)
            THREADS="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --genes)
            IFS=',' read -ra HLA_GENES <<< "$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [[ -z "${INPUT_DIR:-}" ]] || [[ -z "${INDEX_DIR:-}" ]] || [[ -z "${OUTPUT_DIR:-}" ]]; then
    echo "Error: Missing required arguments"
    usage
fi

# Locate hisatgenotype executable (user must configure)
HISATGENOTYPE="${HISATGENOTYPE_PATH:-hisatgenotype}"
if ! command -v "$HISATGENOTYPE" &> /dev/null; then
    echo "Error: hisatgenotype not found. Set HISATGENOTYPE_PATH or add to PATH."
    exit 1
fi

echo "=========================================="
echo "HLA-TypePipe"
echo "=========================================="
echo "Started: $(date)"
echo "Input: ${INPUT_DIR}"
echo "Output: ${OUTPUT_DIR}"
echo "Genes: ${HLA_GENES[*]}"
echo ""

mkdir -p "$OUTPUT_DIR"

TOTAL_PROCESSED=0
TOTAL_FAILED=0
TOTAL_SKIPPED=0

for R1_FILE in ${INPUT_DIR}/*_mapped_1.fastq.gz ${INPUT_DIR}/*_1.fastq.gz ${INPUT_DIR}/*_R1.fastq.gz 2>/dev/null; do
    [[ -f "$R1_FILE" ]] || continue

    # Extract sample ID (handles multiple naming conventions)
    BASENAME=$(basename "$R1_FILE")
    SAMPLE_ID=$(echo "$BASENAME" | sed -E 's/(_mapped)?(_R)?_?1\.f(ast)?q\.gz$//')

    # Find corresponding R2
    R2_FILE=""
    for pattern in "_mapped_2.fastq.gz" "_2.fastq.gz" "_R2.fastq.gz"; do
        CANDIDATE="${INPUT_DIR}/${SAMPLE_ID}${pattern}"
        if [[ -f "$CANDIDATE" ]]; then
            R2_FILE="$CANDIDATE"
            break
        fi
    done

    if [[ -z "$R2_FILE" ]]; then
        echo "[WARN] No R2 file found for ${SAMPLE_ID}, skipping"
        continue
    fi

    echo ""
    echo "=========================================="
    echo "Sample: ${SAMPLE_ID}"
    echo "=========================================="

    # Check if all genes already processed
    ALL_DONE=true
    for GENE in "${HLA_GENES[@]}"; do
        GENE_OUT="${OUTPUT_DIR}/${SAMPLE_ID}/${GENE}"
        if ! ls "${GENE_OUT}/${SAMPLE_ID}_${GENE}-hla."*".report" >/dev/null 2>&1; then
            ALL_DONE=false
            break
        fi
    done

    if [[ "$ALL_DONE" == true ]]; then
        echo "[SKIP] All genes already processed"
        TOTAL_SKIPPED=$((TOTAL_SKIPPED + 1))
        continue
    fi

    # Create isolated temp directory
    TEMP_DIR=$(mktemp -d -p "${INPUT_DIR}" "temp_${SAMPLE_ID}_XXXXXX")
    trap "rm -rf '$TEMP_DIR'" EXIT

    # Prepare input symlinks
    ln -sf "$R1_FILE" "${TEMP_DIR}/${SAMPLE_ID}_R1.fq.gz"
    ln -sf "$R2_FILE" "${TEMP_DIR}/${SAMPLE_ID}_R2.fq.gz"

    pushd "$TEMP_DIR" > /dev/null

    SAMPLE_SUCCESS=0
    SAMPLE_FAILED=0

    for GENE in "${HLA_GENES[@]}"; do
        GENE_OUT="${OUTPUT_DIR}/${SAMPLE_ID}/${GENE}"

        # Skip if already done
        if ls "${GENE_OUT}/${SAMPLE_ID}_${GENE}-hla."*".report" >/dev/null 2>&1; then
            echo "[${GENE}] Already processed"
            SAMPLE_SUCCESS=$((SAMPLE_SUCCESS + 1))
            continue
        fi

        echo "[${GENE}] Processing..."
        mkdir -p "$GENE_OUT"

        set +e
        timeout "$TIMEOUT" "$HISATGENOTYPE" \
            --base hla \
            --locus-list "${GENE}" \
            -1 "${SAMPLE_ID}_R1.fq.gz" \
            -2 "${SAMPLE_ID}_R2.fq.gz" \
            --index_dir "$INDEX_DIR" \
            --keep-alignment \
            --aligner hisat2 \
            --threads "$THREADS" \
            --assembly \
            --assembly-verbose \
            --assembly-name "${SAMPLE_ID}_${GENE}" \
            --output-allele-counts \
            --out-dir "$GENE_OUT" > "${GENE_OUT}/run.log" 2>&1
        EXIT_CODE=$?
        set -e

        if [[ $EXIT_CODE -eq 124 ]]; then
            echo "[${GENE}] TIMEOUT (${TIMEOUT}s)"
            SAMPLE_FAILED=$((SAMPLE_FAILED + 1))
        elif [[ $EXIT_CODE -ne 0 ]]; then
            echo "[${GENE}] FAILED (exit: $EXIT_CODE)"
            SAMPLE_FAILED=$((SAMPLE_FAILED + 1))
        elif ls "${GENE_OUT}"/*.report >/dev/null 2>&1; then
            echo "[${GENE}] SUCCESS"
            SAMPLE_SUCCESS=$((SAMPLE_SUCCESS + 1))
        else
            echo "[${GENE}] FAILED (no report)"
            SAMPLE_FAILED=$((SAMPLE_FAILED + 1))
        fi
    done

    popd > /dev/null
    rm -rf "$TEMP_DIR"
    trap - EXIT

    echo "Sample ${SAMPLE_ID}: ${SAMPLE_SUCCESS} success, ${SAMPLE_FAILED} failed"

    [[ $SAMPLE_SUCCESS -gt 0 ]] && TOTAL_PROCESSED=$((TOTAL_PROCESSED + 1))
    [[ $SAMPLE_FAILED -gt 0 ]] && TOTAL_FAILED=$((TOTAL_FAILED + 1))
done

echo ""
echo "=========================================="
echo "SUMMARY"
echo "=========================================="
echo "Completed: $(date)"
echo "Samples processed: ${TOTAL_PROCESSED}"
echo "Samples with failures: ${TOTAL_FAILED}"
echo "Samples skipped: ${TOTAL_SKIPPED}"
echo "Output: ${OUTPUT_DIR}"
