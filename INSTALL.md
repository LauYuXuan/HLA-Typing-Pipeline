# Installation

## Prerequisites

This pipeline requires several bioinformatics tools to be installed and configured on your system.

### Core Dependencies

- **HISAT-genotype**: HLA genotyping engine
  - Obtain from the official repository
  - Build or download HLA indices (IPD-IMGT/HLA database)
  
- **HISAT2**: Splice-aware aligner
  - Must be compatible with your HISAT-genotype version
  
- **Python**: Required by HISAT-genotype
  - Version requirements depend on HISAT-genotype release

### System Requirements

- Linux operating system
- Bash shell (version 4.0+)
- `timeout` command (GNU coreutils)
- Sufficient RAM for assembly operations

## Setup

1. Clone this repository:
   ```bash
   git clone https://github.com/[username]/HLA-TypePipe.git
   cd HLA-TypePipe
   ```

2. Set the HISAT-genotype path:
   ```bash
   export HISATGENOTYPE_PATH=/path/to/hisatgenotype
   ```

3. Verify dependencies:
   ```bash
   $HISATGENOTYPE_PATH --help
   hisat2 --version
   ```

4. Make script executable:
   ```bash
   chmod +x hla_typing.sh
   ```

## Index Preparation

HLA indices must be downloaded or built separately. The index directory should contain the appropriate database files for your analysis.

**Note**: Index preparation is beyond the scope of this documentation. Refer to HISAT-genotype documentation or contact us for guidance on index builds used in our published analyses.

## Troubleshooting

If you encounter issues with specific software versions or index compatibility, please open an issue with:
- Your operating system and version
- Error messages from run.log files
- General description of your dataset

We will respond to academic collaborators on a best-effort basis.
