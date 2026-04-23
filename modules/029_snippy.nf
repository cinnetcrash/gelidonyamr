process SNIPPY {
    tag "Variant Calling: Snippy — ${sample_id}"

    publishDir "${params.outdir}/snippy/", mode: 'copy'

    input:
    tuple val(sample_id), path(reads_r1), path(reads_r2)
    path ref_genome_file

    output:
    tuple val(sample_id), path("snippy_output/${sample_id}/")

    script:
    """
    mkdir -p snippy_output

    snippy \\
        --outdir snippy_output/${sample_id} \\
        --ref    ${ref_genome_file} \\
        --R1     ${reads_r1} \\
        --R2     ${reads_r2} \\
        --cpus   ${task.cpus} \\
        --ram    ${task.memory.toGiga()} \\
        --force

    echo "Snippy finished for ${sample_id}"
    echo "  VCF: snippy_output/${sample_id}/snps.vcf"
    echo "  Summary: snippy_output/${sample_id}/snps.txt"
    """
}
