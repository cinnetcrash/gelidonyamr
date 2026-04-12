process FASTQC {
    tag "Quality Control: FastQC"

    publishDir params.outdir + "/fastqc/", mode: 'copy'

    input:
    tuple val(sample_id), path(reads_file)

    output:
    path "fastqc_output/"

    script:
    """
    mkdir -p fastqc_output
    fastqc $reads_file -o fastqc_output/ --threads 4
    """
}
