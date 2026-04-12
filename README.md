![GelidonyAMR Header](/visuals/gelindonyAMR.png)

# gelidonyAMR

**Oxford Nanopore-based *Salmonella Infantis* Genomic Epidemiology Pipeline**

---

The name **GelidonyAMR** is inspired by the **Gelidonya Lighthouse**, a historic maritime landmark on the southern coast of Türkiye, near Finike. Just as the lighthouse has guided sailors for centuries, GelidonyAMR serves as a bioinformatics beacon for detecting antimicrobial resistance genes in *Salmonella Infantis* and other foodborne pathogens.

> **PhD Project:** *"Determination of Evolutionary Structure and Antimicrobial Resistance Profile of Salmonella Infantis"*

---

## Pipeline Overview

```
INPUT  (SRA accession list  OR  local FASTQ folder)
        │
        ▼
┌───────────────────────────────────┐
│  Quality Control                  │
│  FastQC · fastp · Kraken2         │
└────────────────┬──────────────────┘
                 │
                 ▼
┌───────────────────────────────────┐
│  Assembly                         │
│  Flye (Nano-raw)                  │
└────────────────┬──────────────────┘
                 │
                 ▼
┌───────────────────────────────────┐
│  Polishing & Assembly QC          │
│  Minimap2 + Racon (4x) · Clair3  │
│  QUAST · BUSCO · CheckM           │
└────────────────┬──────────────────┘
                 │
        ┌────────┴────────┐
        ▼                 ▼
┌──────────────┐  ┌────────────────┐
│  Annotation  │  │ Species Check  │
│  Prokka      │  │ FastANI        │
│  Bakta       │  └────────────────┘
└──────┬───────┘
       │
       ├── AMR Analysis ────── AMRFinderPlus · Abricate (7 databases)
       │
       ├── Plasmid Analysis ── PlasmidFinder · MobSuite
       │
       ├── Molecular Typing ── MLST · cgMLST · PopPUNK
       │
       ├── Phylogenomics ────── Parsnp · Roary → IQ-TREE
       │
       ├── Prophage ──────────── PHASTER
       │
       └── Variant Annotation ── Clair3 → snpEff
```

---

## Requirements

- **Operating System:** Linux (Ubuntu 20.04+ recommended)
- **Conda / Mamba:** for environment management
- **Nextflow:** >= 23.10.0
- **Java:** 11 or higher (required by Nextflow)

> **Note:** The PHASTER step requires an internet connection — it submits assemblies to the PHASTER web API (https://phaster.ca).

---

## Installation

### 1. Create the Conda Environment

This pipeline includes many tools. Using **mamba** instead of standard `conda` is **strongly recommended** — it resolves dependencies 10-20x faster:

```bash
conda install -n base -c conda-forge mamba
mamba env create -f environment.yaml
conda activate gelidonyamr
```

> **Dependency note:** `chewBBACA`, `clair3`, and `poppunk` can occasionally conflict with each other's Python requirements. If the environment fails to solve, try installing these in a separate environment and use Nextflow's `conda` process directive to assign them individually.

### 2. Set Up Databases

#### Kraken2
```bash
kraken2-build --standard --db /home/analysis/kraken2_db --threads 8
```

#### Abricate
```bash
abricate --setupdb
abricate --list     # Verify installed databases
```

#### chewBBACA cgMLST Schema
Downloaded automatically at runtime. To download manually:
```bash
chewBBACA.py DownloadSchema -sp 8 -sc 1 -o data/cgmlst/
```

#### Bakta
```bash
bakta_db download --output /home/analysis/bakta_db --type full
```

#### PlasmidFinder
```bash
git clone https://bitbucket.org/genomicepidemiology/plasmidfinder_db.git /home/analysis/plasmidfinder_db
```

#### snpEff — Salmonella Database
```bash
snpEff download Salmonella_enterica
```

#### SRA Toolkit Configuration *(optional — improves download speed)*
```bash
vdb-config --interactive
# Configure cache directory and cloud endpoint
```

---

## Running the Pipeline

### Mode 1 — Local FASTQ Folder

Place your Nanopore FASTQ files in a folder:

```
input_folder/
├── sample1.fastq
├── sample2.fastq
└── sample3.fastq
```

```bash
nextflow run main.nf \
  --reads "input_folder/*.fastq" \
  --outdir Results \
  -c config/nextflow.config
```

### Mode 2 — NCBI SRA Accession List

Create a plain text file with one accession per line:

```
# sra_accessions.txt
SRR12345678
SRR12345679
SRR12345680
ERR9876543
```

- Accepts SRR, ERR, and DRR prefixes
- Lines starting with `#` are treated as comments and ignored
- Blank lines are skipped automatically

```bash
nextflow run main.nf \
  --sra_list sra_accessions.txt \
  --outdir Results \
  -c config/nextflow.config
```

> `--reads` and `--sra_list` cannot be used together. If `--sra_list` is provided, `--reads` is ignored.

### Additional Run Options

```bash
# Resume a pipeline that was interrupted
nextflow run main.nf -resume --reads "input_folder/*.fastq" -c config/nextflow.config

# Generate HTML execution report and timeline
nextflow run main.nf --reads "input_folder/*.fastq" -c config/nextflow.config \
  -with-report pipeline_report.html \
  -with-timeline pipeline_timeline.html
```

---

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--reads` | `input_folder/*.fastq` | Path to FASTQ files (glob patterns supported) |
| `--sra_list` | `null` | Path to TXT file containing SRA accession numbers |
| `--outdir` | `Results` | Directory where all results will be written |
| `--ref_genome` | `data/ref_genome.fna` | Reference genome (used by Clair3, FastANI, Parsnp) |
| `--kraken2_db` | `/home/analysis/kraken2_db` | Kraken2 database directory |
| `--clair3_model` | `/opt/models/r941_prom_hac_g360+g422` | Clair3 ONT chemistry model path |
| `--bakta_db` | `/home/analysis/bakta_db` | Bakta database directory |
| `--plasmidfinder_db` | `/home/analysis/plasmidfinder_db` | PlasmidFinder database directory |
| `--snpeff_db` | `Salmonella_enterica` | snpEff organism database name |
| `--max_cpu` | `14` | Maximum CPU threads |
| `--max_memory` | `14GB` | Maximum memory |
| `--max_time` | `24h` | Maximum run time |

---

## Output Directory Structure

```
Results/
├── raw_reads/          # FASTQ files downloaded from SRA (SRA mode only)
├── fastqc/             # Per-sample FastQC HTML reports
├── trimmed/            # fastp-trimmed reads
├── kraken2/            # Taxonomic classification reports
├── assembly/           # Raw Flye assembly output
├── polished/           # Final polished genomes (Minimap2 + Racon 4x)
├── quast/              # Assembly quality metrics (N50, contigs, etc.)
├── busco/              # Genome completeness scores
├── checkm/             # Contamination and completeness assessment
├── fastani/            # Species verification (ANI values vs. reference)
├── annotation/         # Prokka output (.gff, .gbk, .faa, .ffn)
├── bakta/              # Bakta annotation output
├── amr/                # Abricate results across 7 databases
├── amrfinder/          # NCBI AMRFinder Plus results
├── mobsuite/           # Plasmid reconstruction and mobility typing
├── plasmidfinder/      # Replicon-based plasmid typing
├── mlst/               # 7-gene MLST profiles
├── cgmlst/             # chewBBACA cgMLST / wgMLST allele calls
├── clair3/             # Variant calls (VCF)
├── snpeff/             # Annotated VCF files
├── phaster/            # Prophage detection results (JSON)
├── roary/              # Pan-genome analysis (core / accessory genes)
├── iqtree/             # Maximum likelihood phylogenetic tree
├── parsnp/             # Core SNP alignment and tree
├── poppunk/            # Population structure clusters
├── multiqc/            # Aggregated QC report across all samples
└── pipeline_info/      # Nextflow execution timeline and report
```

---

## Tool Reference

| Step | Tool | Version |
|------|------|---------|
| SRA Download | SRA Toolkit (fasterq-dump) | ≥3.0 |
| Quality Control | FastQC | 0.12.1 |
| Read Trimming | fastp | 0.24.0 |
| Taxonomic Classification | Kraken2 | 2.1.3 |
| Genome Assembly | Flye | 2.9 |
| Polishing | Minimap2 + Racon | ≥2.26 / ≥1.5 |
| Variant Calling | Clair3 | ≥1.0 |
| Assembly Quality | QUAST | 5.3.0 |
| Genome Completeness | BUSCO | 5.7.1 |
| Quality Assessment | CheckM | ≥1.2 |
| Species Verification | FastANI | ≥1.34 |
| Annotation | Prokka + Bakta | ≥1.14 / ≥1.9 |
| AMR Detection | AMRFinder Plus | ≥3.12 |
| AMR Detection | Abricate | 1.0.1 |
| Plasmid Typing | PlasmidFinder | ≥2.1 |
| Plasmid Reconstruction | MobSuite | ≥3.1 |
| MLST | mlst | 2.23.0 |
| cgMLST / wgMLST | chewBBACA | 3.3.6 |
| Prophage Detection | PHASTER | Web API |
| Variant Annotation | snpEff | ≥5.2 |
| Pan-Genome | Roary | ≥3.13 |
| ML Phylogeny | IQ-TREE2 | ≥2.3 |
| Core SNP Phylogeny | Parsnp | ≥2.0 |
| Population Structure | PopPUNK | ≥2.6 |
| QC Aggregation | MultiQC | 1.27 |

---

## Reference Genome

- **Organism:** *Salmonella enterica* subsp. *enterica* serovar Infantis
- **Accession:** `LN649235.1`
- **NCBI Assembly:** `GCA_000953495.1`

Download the reference genome:
```bash
datasets download genome accession GCA_000953495.1 --include genome
```

---

## Frequently Asked Questions

**Q: Do I need to configure anything extra for the SRA mode?**

No. Simply pass `--sra_list` with the path to your accession file — the pipeline handles the rest.
The only requirement is that `sra-tools` is installed (included in `environment.yaml`).
Optionally, run `vdb-config --interactive` to configure AWS/GCP cloud endpoints for faster downloads.

**Q: Do all tools run inside a single conda environment?**

Most tools are available through the `bioconda` channel and can be installed via conda.
However, `chewBBACA`, `clair3`, and `poppunk` can produce Python dependency conflicts.
Use **mamba** instead of `conda` for significantly better dependency resolution.
PHASTER requires no local installation — it runs entirely through the web API.

**Q: The pipeline stopped midway. How do I resume it?**

```bash
nextflow run main.nf -resume --reads "input_folder/*.fastq" -c config/nextflow.config
```

The `-resume` flag tells Nextflow to reuse cached results from completed steps.

**Q: Can I run only specific steps?**

Comment out the steps you don't need in `main.nf` using `//` and re-run. Nextflow's `-resume` flag ensures previously completed steps are not repeated.

---

## Issues & Contact

For bug reports or feature requests, please open a GitHub issue.

---

**Pipeline Developer:** Gültekin Ünal

*Inspired by the Gelidonya Lighthouse — Finike, Türkiye*
