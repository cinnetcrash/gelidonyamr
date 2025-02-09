# **Salmoline: Salmonella Infantis Nextflow Pipeline**

## 📝 Overview
This Nextflow pipeline, **Salmoline**, has been developed for analyzing *Salmonella Infantis* genomes, including **genome assembly, antimicrobial resistance (AMR) profiling, and cgMLST typing**. It is designed for use in a **Conda environment** and is part of the PhD project:

> **"Determination of Evolutionary Structure and Antimicrobial Resistance Profile of *Salmonella Infantis*"**

## 🔧 Installation
### 📦 Required Dependencies
Ensure that **Conda** is installed and up to date before proceeding. The following **Conda packages** must be installed to run the pipeline:

#### **Create the Conda Environment**
To create and activate the Conda environment for Salmoline, use:

```bash
conda env create -f environment.yaml
conda activate salmoline
```

If the environment is already created, simply activate it:

```bash
conda activate salmoline
```

### 📂 Additional Requirements
#### **Abricate Databases**
Ensure that the necessary **AMR databases** are installed:
```bash
abricate --setupdb
abricate --list
```
List all the required **databases** that have been used in this pipeline.

#### **ChewBBACA Database**
```bash
chewBBACA_downloadDB -sp "Salmonella" -o INNUENDO_salmonella
```

## 📌 Reference Genome
The **reference genome** used in this pipeline:
- **Organism**: *Salmonella Infantis*
- **Reference Accession**: `LN649235.1`
- **NCBI Assembly**: `GCA_000953495.1`

## 🚀 Running the Pipeline
To execute the pipeline, use the following command:

```bash
nextflow run main.nf --reads "../input_folder/*.fastq" --outdir Results -c config/nextflow.config
```

## ⚠️ Environment Considerations
- This pipeline **currently works only in a Conda environment**.
- **Docker support is planned** for future releases.
- A similar pipeline is planned for *Enterohemorrhagic Escherichia coli* (**EHEC**).

## 📖 Citation
The publication associated with this pipeline is **not yet available**. Updates will be provided when the citation is published.

## ❓ Issues & Contact
If you encounter any **issues** while running the pipeline, please let me know.

---
Pipeline developed by **Gültekin Ünal**
