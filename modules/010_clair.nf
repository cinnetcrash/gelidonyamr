process CLAIR3 {
    tag "Variant Calling: Clair3"

    publishDir "${params.outdir}/clair3/", mode: 'copy'

    input:
    tuple val(sample_id), path(trimmed_reads)

    output:
    tuple val(sample_id), path("clair3_output/${sample_id}/")

    script:
    """
    mkdir -p clair3_output/${sample_id}

    # Align reads to reference genome
    minimap2 -ax map-ont -t ${task.cpus} ${params.ref_genome} ${trimmed_reads} | \
        samtools sort -@ ${task.cpus} -o clair3_output/${sample_id}/${sample_id}.bam
    samtools index clair3_output/${sample_id}/${sample_id}.bam

    # Call variants with Clair3
    run_clair3.sh \\
        --bam_fn=clair3_output/${sample_id}/${sample_id}.bam \\
        --ref_fn=${params.ref_genome} \\
        --threads=${task.cpus} \\
        --platform=ont \\
        --model_path=${params.clair3_model} \\
        --output=clair3_output/${sample_id}
    """
}
