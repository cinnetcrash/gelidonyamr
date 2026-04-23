// AMRFinderPlus — accepts a FASTA file directly so it can be run
// separately on chromosome and plasmid sequences.
process AMRFINDER {
    tag "AMRFinderPlus (${label}): ${sample_id}"

    publishDir "${params.outdir}/amrfinder/", mode: 'copy'

    input:
    tuple val(sample_id), path(fasta_file)
    val  label   // 'chromosome' | 'plasmid' | 'assembly'

    output:
    tuple val(sample_id), val(label), path("${sample_id}_${label}_amrfinder.tsv")

    script:
    """
    amrfinder \\
        --nucleotide ${fasta_file} \\
        --output     ${sample_id}_${label}_amrfinder.tsv \\
        --threads    ${task.cpus} \\
        --name       ${sample_id}_${label} \\
        --organism   Salmonella
    """
}
