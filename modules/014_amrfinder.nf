process AMRFINDER {
    tag "AMR Gene Detection: AMRFinder Plus"

    publishDir "${params.outdir}/amrfinder/", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly_dir)

    output:
    tuple val(sample_id), path("amrfinder_output/${sample_id}_amrfinder.tsv")

    script:
    """
    mkdir -p amrfinder_output

    amrfinder --nucleotide ${assembly_dir}/assembly.fasta \\
              --output amrfinder_output/${sample_id}_amrfinder.tsv \\
              --threads ${task.cpus} \\
              --name ${sample_id}
    """
}
