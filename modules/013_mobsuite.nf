process MOBSUITE {
    tag "Plasmid Reconstruction: MOBsuite"

    publishDir "${params.outdir}/mobsuite/", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly_dir)

    output:
    tuple val(sample_id), path("mobsuite_output/${sample_id}/")

    script:
    """
    mkdir -p mobsuite_output/${sample_id}

    mob_recon --infile ${assembly_dir}/assembly.fasta \\
              --outdir mobsuite_output/${sample_id} \\
              --num_threads ${task.cpus} \\
              --force
    """
}
