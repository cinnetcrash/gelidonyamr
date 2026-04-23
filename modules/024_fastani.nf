process FASTANI {
    tag "Species Verification: FastANI — ${sample_id}"

    publishDir "${params.outdir}/fastani/", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly_dir)
    path ref_genome_file

    output:
    tuple val(sample_id), path("fastani_output/${sample_id}_fastani.txt")

    script:
    """
    mkdir -p fastani_output

    fastANI \\
        --query ${assembly_dir}/assembly.fasta \\
        --ref ${ref_genome_file} \\
        --output fastani_output/${sample_id}_fastani.txt \\
        --threads ${task.cpus}
    """
}
