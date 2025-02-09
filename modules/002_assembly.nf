process ASSEMBLY {
    tag "Genom Montajlama İşlemi Yapılıyor...: Flye"

    publishDir params.outdir + "/assembly/", mode: 'copy'

    input:
    tuple val(sample_id), path(trimmed_reads_file)  // Use correct tuple format

    output:
    tuple val(sample_id), path("assembly_output/${sample_id}_assembly")

    script:
    """
    mkdir -p assembly_output
    flye --nano-hq $trimmed_reads_file --out-dir "assembly_output/${sample_id}_assembly" --genome-size 5m --threads 4
    """
}
