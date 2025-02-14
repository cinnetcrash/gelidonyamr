nextflow.enable.dsl=2

// Workflows to Include
include { FASTQC } from './modules/001_fastqc.nf'
include { TRIMMING } from './modules/007_trimming.nf'
include { ASSEMBLY } from './modules/002_assembly.nf'
include { ANNOTATION } from './modules/003_annotation.nf'
include { AMR } from './modules/004_amr.nf'
include { MLST } from './modules/005_mlst.nf'
include { CGMLST } from './modules/006_cgmlst.nf'
include { MULTIQC } from './modules/009_multiqc.nf'
include { KRAKEN2 } from './modules/008_kraken2.nf'
include { CLAIR3 } from './modules/010_clair.nf'
include { BUSCO } from './modules/011_busco.nf'
include { QUAST } from './modules/012_quast.nf'

workflow {
    // Read sample files (FASTQ) from the input directory and correctly create a tuple (sample_id, file)
    def reads = Channel.fromPath(params.reads, checkIfExists: true)
        .map { file -> tuple(file.baseName, file) }  // Extract sample_id and create a tuple

    // Run FASTQC on raw reads
    fastqc_out = FASTQC(reads)

    // Run TRIMMING on raw reads
    trimmed_reads = TRIMMING(reads)

    // Run ASSEMBLY on trimmed reads
    assembled_contigs = ASSEMBLY(trimmed_reads)

    amr_ready = assembled_contigs.map { sample_id, dir -> tuple(sample_id, file("${dir}/assembly.fasta")) }
    amr_results = AMR(amr_ready)

    // Run MultiQC (after FASTQC)
    multiqc_out = MULTIQC(fastqc_out.collect())  // Ensures all reports are collected first

    // Run annotation on assembled contigs
    annotated_genomes = ANNOTATION(assembled_contigs)
    
    // Run MLST analysis on assembled genomes
    mlst_results = MLST(assembled_contigs)

    // Run Kraken2 on trimmed reads
    kraken_results = KRAKEN2(trimmed_reads)
    
    // Run cgMLST analysis on assembled genomes
    cgmlst_results = CGMLST(assembled_contigs)

    // Output the final results// Run Clair3 for variant calling
    CLAIR3(trimmed_reads)

    // QUAST to check assembly quality
    QUAST(assembled_contigs)

    // BUSCO to check genome completeness
    BUSCO(assembled_contigs)
}

workflow.onComplete = {
    def endTime = new Date()
    println "[${endTime}] Pipeline başarı ile tamamlandı."
    println "[${endTime}] Command line: $workflow.commandLine"
}

workflow.onError = { err ->
    def errorTime = new Date()
    println "[${errorTime}] Logları kontrol edin!"
}
