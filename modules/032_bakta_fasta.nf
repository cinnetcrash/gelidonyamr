// Bakta annotation that accepts a FASTA file directly (not an assembly dir).
// Used for annotating chromosome and plasmid sequences separately.
process BAKTA_FASTA {
    tag "Bakta annotation (${label}): ${sample_id}"

    publishDir "${params.outdir}/annotation/${label}/", mode: 'copy'

    input:
    tuple val(sample_id), path(fasta_file)
    val  label    // 'chromosome' or 'plasmid'

    output:
    tuple val(sample_id), val(label), path("${sample_id}_${label}_bakta/")

    script:
    """
    bakta \\
        --db        ${params.bakta_db} \\
        --output    ${sample_id}_${label}_bakta \\
        --prefix    ${sample_id}_${label} \\
        --threads   ${task.cpus} \\
        --force \\
        ${fasta_file}
    """
}
