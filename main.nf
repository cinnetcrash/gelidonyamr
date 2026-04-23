nextflow.enable.dsl=2

// ─── Module Imports ───────────────────────────────────────────────────────────
include { SRA_DOWNLOAD          } from './modules/000_sra_download.nf'
include { MERGE_BARCODES        } from './modules/027_merge_barcodes.nf'
include { FASTQC                } from './modules/001_fastqc.nf'
include { TRIMMING              } from './modules/007_trimming.nf'
include { TRIMMING_ILLUMINA     } from './modules/030_trimming_illumina.nf'
include { KRAKEN2               } from './modules/008_kraken2.nf'
include { ASSEMBLY              } from './modules/002_assembly.nf'
include { ASSEMBLY_ILLUMINA     } from './modules/028_assembly_illumina.nf'
include { ASSEMBLY_AUTOCYCLER   } from './modules/034_assembly_autocycler.nf'
include { RACON                 } from './modules/016_racon.nf'
include { QUAST                 } from './modules/012_quast.nf'
include { BUSCO                 } from './modules/011_busco.nf'
include { CHECKM                } from './modules/025_checkm.nf'
include { FASTANI               } from './modules/024_fastani.nf'
include { MOBSUITE              } from './modules/013_mobsuite.nf'
include { SPLIT_MOB_OUTPUT      } from './modules/031_split_mob_output.nf'
include { BAKTA_FASTA           } from './modules/032_bakta_fasta.nf'
include { PLANNOTATE            } from './modules/033_plannotate.nf'
include { AMRFINDER             } from './modules/014_amrfinder.nf'
include { MLST                  } from './modules/005_mlst.nf'
include { CGMLST                } from './modules/006_cgmlst.nf'
include { PLASMIDFINDER         } from './modules/017_plasmidfinder.nf'
include { PHASTEST              } from './modules/022_phastest.nf'
include { CLAIR3                } from './modules/010_clair.nf'
include { SNPEFF                } from './modules/021_snpeff.nf'
include { SNIPPY                } from './modules/029_snippy.nf'
include { PARSNP                } from './modules/015_parsnp.nf'
include { ROARY                 } from './modules/018_roary.nf'
include { IQTREE                } from './modules/019_iqtree.nf'
include { POPPUNK               } from './modules/020_poppunk.nf'
include { MULTIQC               } from './modules/009_multiqc.nf'
include { FETCH_REFERENCE       } from './modules/026_fetch_reference.nf'
include { FETCH_CONTEXT_GENOMES } from './modules/035_fetch_context_genomes.nf'

// ─── Workflow ─────────────────────────────────────────────────────────────────
workflow {

    // ── Platform validation ───────────────────────────────────────────────────
    def platform = params.platform?.toLowerCase() ?: 'ont'
    if (!['ont', 'illumina'].contains(platform)) {
        error "--platform must be 'ont' or 'illumina' (got '${params.platform}')"
    }
    log.info "Platform  : ${platform.toUpperCase()}"
    log.info "Assembler : ${params.assembler}"

    // ── Reference genome ──────────────────────────────────────────────────────
    if (params.ref_genome && file(params.ref_genome).exists()) {
        ref_genome_ch = Channel.fromPath(params.ref_genome, checkIfExists: true)
        log.info "Reference : ${params.ref_genome} (local)"
    } else {
        def accession = params.serovar_refs[params.serovar]
        if (!accession) {
            error "Unknown serovar '${params.serovar}'. " +
                  "Supported: ${params.serovar_refs.keySet().join(', ')}. " +
                  "Or provide --ref_genome /path/to/ref.fna"
        }
        log.info "Reference : downloading ${params.serovar} (${accession}) from NCBI…"
        ref_genome_ch = FETCH_REFERENCE(Channel.of(accession), Channel.of(params.serovar))
    }

    // ── snpEff database ───────────────────────────────────────────────────────
    def snpeff_db = params.snpeff_db
                 ?: params.serovar_snpeff[params.serovar]
                 ?: 'Salmonella_enterica'
    log.info "snpEff DB : ${snpeff_db}"

    // ─────────────────────────────────────────────────────────────────────────
    // ── ONT workflow ──────────────────────────────────────────────────────────
    // ─────────────────────────────────────────────────────────────────────────
    if (platform == 'ont') {

        // Input
        if (params.barcode_dir) {
            barcode_dirs = Channel
                .fromPath("${params.barcode_dir}/barcode*/", type: 'dir', checkIfExists: true)
                .map { dir -> tuple(dir.name, dir) }

            if (params.sample_sheet && file(params.sample_sheet).exists()) {
                def name_map = [:]
                file(params.sample_sheet).eachLine { line ->
                    line = line.trim()
                    if (line && !line.startsWith('#')) {
                        def cols = line.split('\t')
                        if (cols.size() >= 2) name_map[cols[0].trim()] = cols[1].trim()
                    }
                }
                barcode_dirs = barcode_dirs.map { barcode, dir ->
                    tuple(name_map.getOrDefault(barcode, barcode), dir)
                }
            }
            reads = MERGE_BARCODES(barcode_dirs)

        } else if (params.sra_list) {
            sra_ids = Channel.fromPath(params.sra_list, checkIfExists: true)
                .splitText().map { it.trim() }.filter { it != '' && !it.startsWith('#') }
            reads = SRA_DOWNLOAD(sra_ids)

        } else if (params.reads) {
            reads = Channel.fromPath(params.reads, checkIfExists: true)
                .map { f -> tuple(f.baseName, f) }

        } else {
            error "ONT mode requires one of: --barcode_dir, --reads, or --sra_list"
        }

        // QC
        fastqc_out    = FASTQC(reads)
        trimmed_reads = TRIMMING(reads)
        KRAKEN2(trimmed_reads)

        // Assembly
        if (params.assembler == 'autocycler') {
            assembled = ASSEMBLY_AUTOCYCLER(trimmed_reads)
        } else {
            assembled = ASSEMBLY(trimmed_reads)
        }
        racon_in = trimmed_reads.join(assembled)
        polished = RACON(racon_in)

        // Variant calling
        clair3_out = CLAIR3(trimmed_reads, ref_genome_ch.first())
        snpeff_in  = clair3_out.map { sid, dir ->
                         tuple(sid, file("${dir}/merge_output.vcf.gz")) }
        SNPEFF(snpeff_in, snpeff_db)

    // ─────────────────────────────────────────────────────────────────────────
    // ── Illumina workflow ─────────────────────────────────────────────────────
    // ─────────────────────────────────────────────────────────────────────────
    } else {
        if (!params.illumina_reads) {
            error "Illumina mode requires --illumina_reads (e.g. 'data/*_R1.fastq.gz')"
        }
        illumina_pairs = Channel.fromFilePairs(params.illumina_reads, checkIfExists: true)

        fastqc_out    = FASTQC(illumina_pairs.map { sid, f -> tuple(sid, f[0]) })
        trimmed_reads = TRIMMING_ILLUMINA(illumina_pairs)
        KRAKEN2(trimmed_reads.map { sid, r1, r2 -> tuple(sid, r1) })

        polished = ASSEMBLY_ILLUMINA(trimmed_reads)
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

    // ── MOBsuite → split chromosome / plasmid ─────────────────────────────────
    mob_results  = MOBSUITE(polished)
    split_output = SPLIT_MOB_OUTPUT(mob_results)

    chrom_ch   = split_output.chromosome
    plasmid_ch = split_output.plasmids

    // ── Plasmid typing (before annotation) ───────────────────────────────────
    PLASMIDFINDER(polished)

    // ── Annotation: chromosome and plasmid separately ─────────────────────────
    BAKTA_FASTA(chrom_ch,   'chromosome')
    BAKTA_FASTA(plasmid_ch, 'plasmid')

    // ── Plasmid-specific annotation ───────────────────────────────────────────
    PLANNOTATE(plasmid_ch)

    // ── AMR: chromosome and plasmid separately ────────────────────────────────
    AMRFINDER(chrom_ch,   'chromosome')
    AMRFINDER(plasmid_ch, 'plasmid')

    // ── Molecular typing (on full assembly) ───────────────────────────────────
    MLST(polished)
    CGMLST(polished)

    // ── Prophage (on chromosome) ──────────────────────────────────────────────
    PHASTEST(chrom_ch)

    // ── Context genomes for phylogenomics ─────────────────────────────────────
    if (params.run_context_genomes) {
        context_fastas = FETCH_CONTEXT_GENOMES(
            Channel.of(params.serovar),
            Channel.of(params.context_per_country as String),
            Channel.of(params.context_max_total as String)
        ).fastas
    } else {
        context_fastas = Channel.empty()
    }

    // ── Phylogenomics ─────────────────────────────────────────────────────────
    // Parsnp: combine own assemblies + context genomes
    all_assemblies = polished.map { it[1] }
        .mix(context_fastas)
        .collect()

    PARSNP(all_assemblies, ref_genome_ch.first())
    POPPUNK(polished.map { it[1] }.collect())

    // Pan-genome (optional)
    if (params.run_pangenome) {
        chrom_gff = BAKTA_FASTA.out
            .filter { sid, label, dir -> label == 'chromosome' }
            .map    { sid, label, dir -> file("${dir}/${sid}_chromosome.gff3") }
            .collect()
        roary_out  = ROARY(chrom_gff)
        IQTREE(roary_out)
    }

    // QC summary
    MULTIQC(fastqc_out.collect())
}

// ─── Handlers ─────────────────────────────────────────────────────────────────
workflow.onComplete {
    println "[${new Date()}] Pipeline complete. Results: ${params.outdir}"
}
workflow.onError { err ->
    println "[${new Date()}] Pipeline failed: ${err}"
}
