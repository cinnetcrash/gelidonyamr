process FASTANI {
    tag "Tür Doğrulama: FastANI"

    publishDir "${params.outdir}/fastani/", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly_dir)

    output:
    tuple val(sample_id), path("fastani_output/${sample_id}_fastani.txt")

    script:
    """
    mkdir -p fastani_output

    fastANI \\
        --query ${assembly_dir}/assembly.fasta \\
        --ref ${params.ref_genome} \\
        --output fastani_output/${sample_id}_fastani.txt \\
        --threads ${task.cpus}
    """
}
