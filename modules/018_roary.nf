process ROARY {
    tag "Pan-Genom Analizi: Roary"

    publishDir "${params.outdir}/roary/", mode: 'copy'

    input:
    path(gff_files)

    output:
    path("roary_output/")

    script:
    """
    mkdir -p roary_output

    roary -f roary_output/ \\
          -e -n \\
          -p ${task.cpus} \\
          -v \\
          ${gff_files}
    """
}
