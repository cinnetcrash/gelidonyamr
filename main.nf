nextflow.enable.dsl=2

// ─── Module Imports ───────────────────────────────────────────────────────────
include { SRA_DOWNLOAD  } from './modules/000_sra_download.nf'
include { FASTQC        } from './modules/001_fastqc.nf'
include { ASSEMBLY      } from './modules/002_assembly.nf'
include { ANNOTATION    } from './modules/003_annotation.nf'
include { AMR           } from './modules/004_amr.nf'
include { MLST          } from './modules/005_mlst.nf'
include { CGMLST        } from './modules/006_cgmlst.nf'
include { TRIMMING      } from './modules/007_trimming.nf'
include { KRAKEN2       } from './modules/008_kraken2.nf'
include { MULTIQC       } from './modules/009_multiqc.nf'
include { CLAIR3        } from './modules/010_clair.nf'
include { BUSCO         } from './modules/011_busco.nf'
include { QUAST         } from './modules/012_quast.nf'
include { MOBSUITE      } from './modules/013_mobsuite.nf'
include { AMRFINDER     } from './modules/014_amrfinder.nf'
include { PARSNP        } from './modules/015_parsnp.nf'
include { RACON         } from './modules/016_racon.nf'
include { PLASMIDFINDER } from './modules/017_plasmidfinder.nf'
include { ROARY         } from './modules/018_roary.nf'
include { IQTREE        } from './modules/019_iqtree.nf'
include { POPPUNK       } from './modules/020_poppunk.nf'
include { SNPEFF        } from './modules/021_snpeff.nf'
include { PHASTER       } from './modules/022_phaster.nf'
include { BAKTA         } from './modules/023_bakta.nf'
include { FASTANI       } from './modules/024_fastani.nf'
include { CHECKM        } from './modules/025_checkm.nf'

// ─── Workflow ─────────────────────────────────────────────────────────────────
workflow {

    // ── Input: SRA accession list or local FASTQ folder ──────────────────────
    if (params.sra_list) {
        // Read SRR IDs from TXT file — skip blank lines and # comments
        sra_ids = Channel
            .fromPath(params.sra_list, checkIfExists: true)
            .splitText()
            .map { it.trim() }
            .filter { it != '' && !it.startsWith('#') }

        reads = SRA_DOWNLOAD(sra_ids)

    } else {
        // Read FASTQ files from local folder
        reads = Channel
            .fromPath(params.reads, checkIfExists: true)
            .map { file -> tuple(file.baseName, file) }
    }

    // ── Quality Control ───────────────────────────────────────────────────────
    fastqc_out     = FASTQC(reads)
    trimmed_reads  = TRIMMING(reads)
    kraken_results = KRAKEN2(trimmed_reads)

    // ── Assembly + Polishing ──────────────────────────────────────────────────
    assembled_contigs = ASSEMBLY(trimmed_reads)

    // Join reads and assembly on sample_id for Racon polishing
    racon_input      = trimmed_reads.join(assembled_contigs)
    polished_contigs = RACON(racon_input)

    // ── Assembly Quality Assessment ───────────────────────────────────────────
    quast_results   = QUAST(polished_contigs)
    busco_results   = BUSCO(polished_contigs)
    checkm_results  = CHECKM(polished_contigs)
    fastani_results = FASTANI(polished_contigs)

    // ── Genome Annotation ─────────────────────────────────────────────────────
    annotated_genomes = ANNOTATION(polished_contigs)
    bakta_results     = BAKTA(polished_contigs)

    // ── AMR Analysis ──────────────────────────────────────────────────────────
    amr_ready         = polished_contigs.map { sid, dir -> tuple(sid, file("${dir}/assembly.fasta")) }
    amr_results       = AMR(amr_ready)
    amrfinder_results = AMRFINDER(polished_contigs)

    // ── Plasmid Analysis ──────────────────────────────────────────────────────
    mobsuite_results      = MOBSUITE(polished_contigs)
    plasmidfinder_results = PLASMIDFINDER(polished_contigs)

    // ── Molecular Typing ──────────────────────────────────────────────────────
    mlst_results   = MLST(polished_contigs)
    cgmlst_results = CGMLST(polished_contigs)

    // ── Prophage Detection ────────────────────────────────────────────────────
    phaster_results = PHASTER(polished_contigs)

    // ── Variant Calling + Annotation ──────────────────────────────────────────
    clair3_results = CLAIR3(trimmed_reads)

    snpeff_input   = clair3_results.map { sid, dir ->
        tuple(sid, file("${dir}/merge_output.vcf.gz"))
    }
    snpeff_results = SNPEFF(snpeff_input)

    // ── Phylogenomics (waits for all samples to complete) ─────────────────────
    // Parsnp: core SNP phylogeny from polished assemblies
    parsnp_results = PARSNP(polished_contigs.map { it[1] }.collect())

    // Roary: pan-genome analysis from Prokka GFF files
    gff_files     = annotated_genomes.map { sid, dir -> file("${dir}/${sid}.gff") }.collect()
    roary_results = ROARY(gff_files)

    // IQ-TREE: ML phylogeny from Roary core genome alignment
    iqtree_results = IQTREE(roary_results)

    // PopPUNK: population structure from polished assemblies
    poppunk_results = POPPUNK(polished_contigs.map { it[1] }.collect())

    // ── MultiQC: aggregate all FastQC reports ─────────────────────────────────
    multiqc_out = MULTIQC(fastqc_out.collect())
}

// ─── Completion / Error Handlers ─────────────────────────────────────────────
workflow.onComplete {
    def endTime = new Date()
    println "[${endTime}] Pipeline completed successfully."
    println "[${endTime}] Command line: ${workflow.commandLine}"
    println "[${endTime}] Results: ${params.outdir}"
}

workflow.onError { err ->
    def errorTime = new Date()
    println "[${errorTime}] Pipeline failed — check the logs for details."
    println "[${errorTime}] Error: ${err}"
}
