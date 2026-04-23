process TRIMMING_ILLUMINA {
    tag "Paired-end Trimming: fastp — ${sample_id}"

    publishDir "${params.outdir}/trimmed/", mode: 'copy'

    input:
    tuple val(sample_id), path(reads_r1), path(reads_r2)

    output:
    tuple val(sample_id),
          path("trimmed_reads/${sample_id}_R1_trimmed.fastq.gz"),
          path("trimmed_reads/${sample_id}_R2_trimmed.fastq.gz")

    script:
    """
    mkdir -p trimmed_reads

    fastp \\
        -i  ${reads_r1} \\
        -I  ${reads_r2} \\
        -o  trimmed_reads/${sample_id}_R1_trimmed.fastq.gz \\
        -O  trimmed_reads/${sample_id}_R2_trimmed.fastq.gz \\
        -h  trimmed_reads/${sample_id}.html \\
        -j  trimmed_reads/${sample_id}.json \\
        -R  "${sample_id} fastp Report" \\
        -w  ${task.cpus} \\
        --detect_adapter_for_pe \\
        --correction \\
        --qualified_quality_phred 20 \\
        --length_required 50
    """
}
