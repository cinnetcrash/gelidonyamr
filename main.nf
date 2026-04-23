nextflow.enable.dsl=2

// ─── Module Imports ───────────────────────────────────────────────────────────
include { SRA_DOWNLOAD       } from './modules/000_sra_download.nf'
include { MERGE_BARCODES     } from './modules/027_merge_barcodes.nf'
include { FASTQC             } from './modules/001_fastqc.nf'
include { TRIMMING           } from './modules/007_trimming.nf'
include { TRIMMING_ILLUMINA  } from './modules/030_trimming_illumina.nf'
include { KRAKEN2            } from './modules/008_kraken2.nf'
include { ASSEMBLY           } from './modules/002_assembly.nf'
include { ASSEMBLY_ILLUMINA  } from './modules/028_assembly_illumina.nf'
include { RACON              } from './modules/016_racon.nf'
include { ANNOTATION         } from './modules/003_annotation.nf'
include { BAKTA              } from './modules/023_bakta.nf'
include { AMR                } from './modules/004_amr.nf'
include { AMRFINDER          } from './modules/014_amrfinder.nf'
include { MOBSUITE           } from './modules/013_mobsuite.nf'
include { PLASMIDFINDER      } from './modules/017_plasmidfinder.nf'
include { MLST               } from './modules/005_mlst.nf'
include { CGMLST             } from './modules/006_cgmlst.nf'
include { PHASTER            } from './modules/022_phaster.nf'
include { CLAIR3             } from './modules/010_clair.nf'
include { SNPEFF             } from './modules/021_snpeff.nf'
include { SNIPPY             } from './modules/029_snippy.nf'
include { QUAST              } from './modules/012_quast.nf'
include { BUSCO              } from './modules/011_busco.nf'
include { CHECKM             } from './modules/025_checkm.nf'
include { FASTANI            } from './modules/024_fastani.nf'
include { PARSNP             } from './modules/015_parsnp.nf'
include { ROARY              } from './modules/018_roary.nf'
include { IQTREE             } from './modules/019_iqtree.nf'
include { POPPUNK            } from './modules/020_poppunk.nf'
include { MULTIQC            } from './modules/009_multiqc.nf'
include { FETCH_REFERENCE    } from './modules/026_fetch_reference.nf'

// ─── Workflow ─────────────────────────────────────────────────────────────────
workflow {

    // ── Platform validation ───────────────────────────────────────────────────
    def platform = params.platform?.toLowerCase() ?: 'ont'
    if (!['ont', 'illumina'].contains(platform)) {
        error "Unknown --platform '${params.platform}'. Use 'ont' or 'illumina'."
    }
    log.info "Platform: ${platform.toUpperCase()}"

    // ── Reference genome ──────────────────────────────────────────────────────
    if (params.ref_genome && file(params.ref_genome).exists()) {
        ref_genome_ch = Channel.fromPath(params.ref_genome, checkIfExists: true)
        log.info "Reference genome : ${params.ref_genome} (local)"
    } else {
        def accession = params.serovar_refs[params.serovar]
        if (!accession) {
            error "Unknown serovar '${params.serovar}'. " +
                  "Supported: ${params.serovar_refs.keySet().join(', ')}. " +
                  "Or provide a local file with --ref_genome."
        }
        log.info "Reference genome : downloading ${params.serovar} (${accession})…"
        ref_genome_ch = FETCH_REFERENCE(Channel.of(accession), Channel.of(params.serovar))
    }

    // ── snpEff DB ─────────────────────────────────────────────────────────────
    def snpeff_db = params.snpeff_db
                 ?: params.serovar_snpeff[params.serovar]
                 ?: 'Salmonella_enterica'

    log.info "Serovar        : ${params.serovar ?: '(custom ref)'}"
    log.info "snpEff DB      : ${snpeff_db}"

    // ─────────────────────────────────────────────────────────────────────────
    // ── ONT workflow ──────────────────────────────────────────────────────────
    // ─────────────────────────────────────────────────────────────────────────
    if (platform == 'ont') {

        // ── Input channel ─────────────────────────────────────────────────────
        if (params.barcode_dir) {
            // Discover barcode subdirectories (barcode01/, barcode02/, …)
            barcode_dirs = Channel
                .fromPath("${params.barcode_dir}/barcode*/", type: 'dir', checkIfExists: true)
                .map { dir -> tuple(dir.name, dir) }

            // Optional sample sheet: rename barcodes → sample IDs
            if (params.sample_sheet && file(params.sample_sheet).exists()) {
                def name_map = [:]
                file(params.sample_sheet).eachLine { line ->
                    line = line.trim()
                    if (line && !line.startsWith('#')) {
                        def cols = line.split('\t')
                        if (cols.size() >= 2) name_map[cols[0].trim()] = cols[1].trim()
                    }
                }
                log.info "Sample sheet loaded: ${name_map.size()} barcode → sample mappings"
                barcode_dirs = barcode_dirs.map { barcode, dir ->
                    tuple(name_map.getOrDefault(barcode, barcode), dir)
                }
            }

            reads = MERGE_BARCODES(barcode_dirs)
            log.info "Input mode: ONT barcodes (${params.barcode_dir})"

        } else if (params.sra_list) {
            sra_ids = Channel
                .fromPath(params.sra_list, checkIfExists: true)
                .splitText()
                .map { it.trim() }
                .filter { it != '' && !it.startsWith('#') }
            reads = SRA_DOWNLOAD(sra_ids)
            log.info "Input mode: SRA download"

        } else if (params.reads) {
            reads = Channel
                .fromPath(params.reads, checkIfExists: true)
                .map { f -> tuple(f.baseName, f) }
            log.info "Input mode: ONT local FASTQ (${params.reads})"

        } else {
            error "ONT mode requires one of: --barcode_dir, --reads, or --sra_list"
        }

        // ── QC ────────────────────────────────────────────────────────────────
        fastqc_out    = FASTQC(reads)
        trimmed_reads = TRIMMING(reads)
        KRAKEN2(trimmed_reads)

        // ── Assembly + Polishing ──────────────────────────────────────────────
        assembled     = ASSEMBLY(trimmed_reads)
        racon_in      = trimmed_reads.join(assembled)
        polished      = RACON(racon_in)

        // ── Variant calling ───────────────────────────────────────────────────
        clair3_out    = CLAIR3(trimmed_reads, ref_genome_ch.first())
        snpeff_in     = clair3_out.map { sid, dir ->
                            tuple(sid, file("${dir}/merge_output.vcf.gz")) }
        SNPEFF(snpeff_in, snpeff_db)

    // ─────────────────────────────────────────────────────────────────────────
    // ── Illumina workflow ─────────────────────────────────────────────────────
    // ─────────────────────────────────────────────────────────────────────────
    } else {

        if (!params.illumina_reads) {
            error "Illumina mode requires --illumina_reads (e.g. 'data/*_R1.fastq.gz')"
        }

        // Pair R1/R2 files automatically by sample name
        // Nextflow fromFilePairs matches on the {1,2} or {R1,R2} in the filename
        illumina_pairs = Channel
            .fromFilePairs(params.illumina_reads, checkIfExists: true)

        log.info "Input mode: Illumina paired-end (${params.illumina_reads})"

        // ── QC ────────────────────────────────────────────────────────────────
        fastqc_out    = FASTQC(illumina_pairs.map { sid, files -> tuple(sid, files[0]) })
        trimmed_reads = TRIMMING_ILLUMINA(illumina_pairs)
        KRAKEN2(trimmed_reads.map { sid, r1, r2 -> tuple(sid, r1) })

        // ── Assembly ──────────────────────────────────────────────────────────
        polished = ASSEMBLY_ILLUMINA(trimmed_reads)
        // No polishing step for Illumina (SPAdes output is used directly)

        // ── Variant calling (Snippy — handles paired-end natively) ────────────
        SNIPPY(trimmed_reads, ref_genome_ch.first())
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ── Steps shared by both platforms ───────────────────────────────────────
    // ─────────────────────────────────────────────────────────────────────────

    // Assembly QC
    QUAST(polished)
    BUSCO(polished)
    CHECKM(polished)
    FASTANI(polished, ref_genome_ch.first())

    // Annotation
    annotated = ANNOTATION(polished)
    BAKTA(polished)

    // AMR
    amr_ready = polished.map { sid, dir -> tuple(sid, file("${dir}/assembly.fasta")) }
    AMR(amr_ready)
    AMRFINDER(polished)

    // Plasmid
    MOBSUITE(polished)
    PLASMIDFINDER(polished)

    // Typing
    MLST(polished)
    CGMLST(polished)

    // Prophage
    PHASTER(polished)

    // Phylogenomics
    PARSNP(polished.map { it[1] }.collect(), ref_genome_ch.first())

    gff_files = annotated.map { sid, dir -> file("${dir}/${sid}.gff") }.collect()
    IQTREE(ROARY(gff_files))

    POPPUNK(polished.map { it[1] }.collect())

    // MultiQC
    MULTIQC(fastqc_out.collect())
}

// ─── Handlers ─────────────────────────────────────────────────────────────────
workflow.onComplete {
    println "[${new Date()}] Pipeline completed. Results: ${params.outdir}"
}
workflow.onError { err ->
    println "[${new Date()}] Pipeline failed: ${err}"
}
