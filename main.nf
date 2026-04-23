nextflow.enable.dsl=2

// ─── Module Imports ───────────────────────────────────────────────────────────
include { SRA_DOWNLOAD    } from './modules/000_sra_download.nf'
include { FASTQC          } from './modules/001_fastqc.nf'
include { ASSEMBLY        } from './modules/002_assembly.nf'
include { ANNOTATION      } from './modules/003_annotation.nf'
include { AMR             } from './modules/004_amr.nf'
include { MLST            } from './modules/005_mlst.nf'
include { CGMLST          } from './modules/006_cgmlst.nf'
include { TRIMMING        } from './modules/007_trimming.nf'
include { KRAKEN2         } from './modules/008_kraken2.nf'
include { MULTIQC         } from './modules/009_multiqc.nf'
include { CLAIR3          } from './modules/010_clair.nf'
include { BUSCO           } from './modules/011_busco.nf'
include { QUAST           } from './modules/012_quast.nf'
include { MOBSUITE        } from './modules/013_mobsuite.nf'
include { AMRFINDER       } from './modules/014_amrfinder.nf'
include { PARSNP          } from './modules/015_parsnp.nf'
include { RACON           } from './modules/016_racon.nf'
include { PLASMIDFINDER   } from './modules/017_plasmidfinder.nf'
include { ROARY           } from './modules/018_roary.nf'
include { IQTREE          } from './modules/019_iqtree.nf'
include { POPPUNK         } from './modules/020_poppunk.nf'
include { SNPEFF          } from './modules/021_snpeff.nf'
include { PHASTER         } from './modules/022_phaster.nf'
include { BAKTA           } from './modules/023_bakta.nf'
include { FASTANI         } from './modules/024_fastani.nf'
include { CHECKM          } from './modules/025_checkm.nf'
include { FETCH_REFERENCE } from './modules/026_fetch_reference.nf'

// ─── Workflow ─────────────────────────────────────────────────────────────────
workflow {

    // ── Reference genome resolution ───────────────────────────────────────────
    // Priority: local file → auto-download from serovar map → error
    if (params.ref_genome && file(params.ref_genome).exists()) {
        // User supplied a local FASTA file
        ref_genome_ch = Channel.fromPath(params.ref_genome, checkIfExists: true)
        log.info "Using local reference genome: ${params.ref_genome}"

    } else {
        // Resolve NCBI accession from serovar name
        def accession = params.serovar_refs[params.serovar]
        if (!accession) {
            error "Unknown serovar '${params.serovar}'. " +
                  "Set --serovar to one of: ${params.serovar_refs.keySet().join(', ')}. " +
                  "Or provide a local file with --ref_genome /path/to/ref.fna"
        }
        log.info "Downloading reference genome for Salmonella ${params.serovar} (${accession})…"
        ref_genome_ch = FETCH_REFERENCE(
            Channel.of(accession),
            Channel.of(params.serovar)
        )
    }

    // ── snpEff database resolution ─────────────────────────────────────────────
    // Use a serovar-specific database when available; fall back to species level.
    def snpeff_db = params.snpeff_db
                 ?: params.serovar_snpeff[params.serovar]
                 ?: 'Salmonella_enterica'

    log.info "Salmonella serovar : ${params.serovar ?: '(custom reference)'}"
    log.info "snpEff database    : ${snpeff_db}"
    log.info "Genome size hint   : ${params.genome_size}"
    log.info "cgMLST species/schema: ${params.cgmlst_species_id}/${params.cgmlst_schema_id}"

    // ── Input: SRA accession list or local FASTQ folder ──────────────────────
    if (params.sra_list) {
        sra_ids = Channel
            .fromPath(params.sra_list, checkIfExists: true)
            .splitText()
            .map { it.trim() }
            .filter { it != '' && !it.startsWith('#') }

        reads = SRA_DOWNLOAD(sra_ids)

    } else {
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

    racon_input      = trimmed_reads.join(assembled_contigs)
    polished_contigs = RACON(racon_input)

    // ── Assembly Quality Assessment ───────────────────────────────────────────
    quast_results   = QUAST(polished_contigs)
    busco_results   = BUSCO(polished_contigs)
    checkm_results  = CHECKM(polished_contigs)
    fastani_results = FASTANI(polished_contigs, ref_genome_ch.first())

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
    clair3_results = CLAIR3(trimmed_reads, ref_genome_ch.first())

    snpeff_input   = clair3_results.map { sid, dir ->
        tuple(sid, file("${dir}/merge_output.vcf.gz"))
    }
    snpeff_results = SNPEFF(snpeff_input, snpeff_db)

    // ── Phylogenomics ─────────────────────────────────────────────────────────
    parsnp_results  = PARSNP(polished_contigs.map { it[1] }.collect(), ref_genome_ch.first())

    gff_files      = annotated_genomes.map { sid, dir -> file("${dir}/${sid}.gff") }.collect()
    roary_results  = ROARY(gff_files)
    iqtree_results = IQTREE(roary_results)

    poppunk_results = POPPUNK(polished_contigs.map { it[1] }.collect())

    // ── MultiQC ───────────────────────────────────────────────────────────────
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
