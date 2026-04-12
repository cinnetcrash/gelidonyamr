process SNPEFF {
    tag "Varyant Anotasyonu: snpEff"

    publishDir "${params.outdir}/snpeff/", mode: 'copy'

    input:
    tuple val(sample_id), path(vcf_file)

    output:
    tuple val(sample_id),
          path("snpeff_output/${sample_id}_annotated.vcf"),
          path("snpeff_output/${sample_id}_snpEff.html"),
          path("snpeff_output/${sample_id}_snpEff.csv")

    script:
    """
    mkdir -p snpeff_output

    snpEff -v \\
           -stats snpeff_output/${sample_id}_snpEff.html \\
           -csvStats snpeff_output/${sample_id}_snpEff.csv \\
           ${params.snpeff_db} \\
           ${vcf_file} \\
           > snpeff_output/${sample_id}_annotated.vcf
    """
}
