process BAKTA {
    tag "Genome Annotation: Bakta"

    publishDir "${params.outdir}/bakta/", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly_dir)

    output:
    tuple val(sample_id), path("bakta_output/${sample_id}/")

    script:
    """
    mkdir -p bakta_output/${sample_id}

    bakta \\
        --db ${params.bakta_db} \\
        --output bakta_output/${sample_id} \\
        --prefix ${sample_id} \\
        --threads ${task.cpus} \\
        --force \\
        ${assembly_dir}/assembly.fasta
    """
}
