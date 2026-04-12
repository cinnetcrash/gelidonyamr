process QUAST {
    tag "Assembly Quality: QUAST"

    publishDir "${params.outdir}/quast/", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly_dir)

    output:
    tuple val(sample_id), path("quast_output/${sample_id}/")

    script:
    """
    mkdir -p quast_output

    quast.py ${assembly_dir}/assembly.fasta \\
             -o quast_output/${sample_id} \\
             --threads ${task.cpus}
    """
}
