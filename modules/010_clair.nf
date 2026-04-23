process CLAIR3 {
    tag "Variant Calling: Clair3 — ${sample_id}"

    publishDir "${params.outdir}/clair3/", mode: 'copy'

    input:
    tuple val(sample_id), path(trimmed_reads)
    path ref_genome_file

    output:
    tuple val(sample_id), path("clair3_output/${sample_id}/")

    script:
    """
    mkdir -p clair3_output/${sample_id}

    minimap2 -ax map-ont -t ${task.cpus} ${ref_genome_file} ${trimmed_reads} | \
        samtools sort -@ ${task.cpus} -o clair3_output/${sample_id}/${sample_id}.bam
    samtools index clair3_output/${sample_id}/${sample_id}.bam

    run_clair3.sh \\
        --bam_fn=clair3_output/${sample_id}/${sample_id}.bam \\
        --ref_fn=${ref_genome_file} \\
        --threads=${task.cpus} \\
        --platform=ont \\
        --model_path=${params.clair3_model} \\
        --output=clair3_output/${sample_id}
    """
}
