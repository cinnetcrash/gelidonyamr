process KRAKEN2 {
    tag "Kraken2 Analizi Yapılıyor..."

    publishDir "${params.outdir}/kraken2/", mode: 'copy'

    input:
    tuple val(sample_id), file(trimmed_reads)

    output:
    tuple val(sample_id), file("kraken2_output/${sample_id}_kraken2.txt"),
          file("kraken2_output/${sample_id}_kraken2_report.txt"),
          file("kraken2_output/${sample_id}_kraken2_unclassified.txt"),
          file("kraken2_output/${sample_id}_kraken2_classified.txt")

    script:
    """
    mkdir -p kraken2_output

    kraken2 --db ${params.kraken2_db} \\
            --output kraken2_output/${sample_id}_kraken2.txt \\
            --report kraken2_output/${sample_id}_kraken2_report.txt \\
            --unclassified-out kraken2_output/${sample_id}_kraken2_unclassified.txt \\
            --classified-out kraken2_output/${sample_id}_kraken2_classified.txt \\
            --use-names --report-zero-counts --use-mpa-style \\
            --threads ${task.cpus} \\
            $trimmed_reads --threads 3 --memory-mapping
    """
}
