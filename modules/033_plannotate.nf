process PLANNOTATE {
    tag "PlaNotate plasmid annotation: ${sample_id}"

    publishDir "${params.outdir}/plannotate/", mode: 'copy'

    input:
    tuple val(sample_id), path(plasmid_fasta)

    output:
    tuple val(sample_id), path("${sample_id}_plannotate/")

    script:
    """
    mkdir -p ${sample_id}_plannotate

    plannotate batch \\
        --input     ${plasmid_fasta} \\
        --output    ${sample_id}_plannotate \\
        --file_name ${sample_id} \\
        --html

    echo "PlaNotate annotation complete for ${sample_id}"
    """
}
