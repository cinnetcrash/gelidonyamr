process FASTQC {
    tag "Kalite kontrol işlemi yapılıyor...: FastQC"

    publishDir params.outdir + "/fastqc/", mode: 'copy'
    
    input:
    tuple val(sample_id), path(reads_file)

    output:
    path "fastqc_output/${sample_id}_fastqc.html"

    script:
    """
    mkdir -p fastqc_output
    fastqc $reads_file -o fastqc_output/ --threads 4
    """
}
