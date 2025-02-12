process TRIMMING {
    tag "Traşlama İşlemi Yapılıyor...: fastp"

    publishDir params.outdir + "/trimmed/", mode: 'copy'

    input:
    tuple val(sample_id), path(reads_file)

    output:
    tuple val(sample_id), path("trimmed_reads/${sample_id}_trimmed.fastq")

    script:
    """
    mkdir -p trimmed_reads
    fastp -i $reads_file -o trimmed_reads/${sample_id}_trimmed.fastq -h trimmed_reads/${sample_id}.html -w 3 -j trimmed_reads/${sample_id}.json -R trimmed_reads/${sample_id}_report.json
    """
}
