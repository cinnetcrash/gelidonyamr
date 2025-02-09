process ANNOTATION {
    tag "Anotasyon İşlemi Yapılıyor...: Prokka"

    publishDir params.outdir + "/annotation/", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly_dir)

    output:
    tuple val(sample_id), path("annotation_output/${sample_id}_prokka")

    script:
    """
    mkdir -p annotation_output/${sample_id}_prokka
    prokka --outdir annotation_output/${sample_id}_prokka --prefix ${sample_id} ${assembly_dir}/assembly.fasta --cpu 2 --force
    """
}
