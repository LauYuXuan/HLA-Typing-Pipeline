# HLA-TypePipe

High-resolution HLA genotyping pipeline for paired-end RNA-seq data.

## Overview

This pipeline performs HLA typing across multiple loci (HLA-A, B, C, DQA1, DQB1, DRB1, DRA, DPA1, DPB1) from host-mapped RNA-seq reads. It implements batch processing with automatic resume capability and per-sample isolation.

## Requirements

- Linux environment (tested on institutional HPC clusters)
- HISAT-genotype with HLA indices
- HISAT2 aligner
- Standard Unix utilities (bash, timeout, etc.)
- Sufficient memory for assembly (varies by dataset)

**Note:** Specific software versions and index builds used in our analyses are available upon reasonable request for academic collaborations.

## Usage

```bash
./hla_typing.sh \
    --input-dir /path/to/fastq/files \
    --index-dir /path/to/hisatgenotype/indices \
    --output-dir /path/to/output \
    --threads 8 \
    --timeout 600
```

### Input Format

Paired-end FASTQ files with naming convention:
```
{SAMPLE_ID}_mapped_1.fastq.gz
{SAMPLE_ID}_mapped_2.fastq.gz
```

### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `--input-dir` | Directory containing paired FASTQ files | Required |
| `--index-dir` | HISAT-genotype index directory | Required |
| `--output-dir` | Output directory for results | Required |
| `--threads` | Number of threads per gene | 8 |
| `--timeout` | Timeout per gene in seconds | 600 |
| `--genes` | Comma-separated gene list | A,B,C,DQA1,DQB1,DRB1,DRA,DPA1,DPB1 |

### Output Structure

```
output_dir/
├── {SAMPLE_ID}/
│   ├── A/
│   │   ├── {SAMPLE_ID}_A-hla.*.report
│   │   ├── run.log
│   │   └── ...
│   ├── B/
│   └── ...
```

## Features

- **Batch processing**: Automatically processes all samples in input directory
- **Resume capability**: Skips already-completed genes/samples
- **Isolated execution**: Per-sample temporary directories prevent conflicts
- **Timeout handling**: Prevents hanging on problematic samples

## Citation

If you use this pipeline, please cite:

> [Publication pending]

For questions regarding specific configurations used in published analyses, please contact the corresponding author.

## License

Academic use only. Commercial licensing available upon request.
