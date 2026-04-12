process BUSCO {
    tag "Genome Completeness: BUSCO"

    publishDir "${params.outdir}/busco/", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly_dir)

    output:
    tuple val(sample_id), path("busco_output/${sample_id}/")

    script:
    """
    mkdir -p busco_output

    busco -i ${assembly_dir}/assembly.fasta \\
          -o ${sample_id} \\
          --out_path busco_output/ \\
          -m genome \\
          --auto-lineage-prok \\
          --cpu ${task.cpus} \\
          --force
    """
}
