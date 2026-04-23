process ASSEMBLY {
    tag "Genome Assembly: Flye"

    publishDir params.outdir + "/assembly/", mode: 'copy'

    input:
    tuple val(sample_id), path(trimmed_reads_file)  // Use correct tuple format

    output:
    tuple val(sample_id), path("assembly_output/${sample_id}_assembly")

    script:
    """
    mkdir -p assembly_output
    flye --nano-hq $trimmed_reads_file --out-dir "assembly_output/${sample_id}_assembly" --genome-size ${params.genome_size} --threads ${task.cpus}
    """
}
