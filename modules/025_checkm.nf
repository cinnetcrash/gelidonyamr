process CHECKM {
    tag "Genom Kalite Kontrolü: CheckM"

    publishDir "${params.outdir}/checkm/", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly_dir)

    output:
    tuple val(sample_id), path("checkm_output/${sample_id}/")

    script:
    """
    mkdir -p checkm_input/${sample_id}
    mkdir -p checkm_output/${sample_id}

    cp ${assembly_dir}/assembly.fasta checkm_input/${sample_id}/

    checkm lineage_wf \\
        checkm_input/${sample_id}/ \\
        checkm_output/${sample_id}/ \\
        -t ${task.cpus} \\
        -x fasta \\
        --reduced_tree

    # Özet tablosu
    checkm qa \\
        checkm_output/${sample_id}/lineage.ms \\
        checkm_output/${sample_id}/ \\
        -o 2 \\
        --tab_table \\
        -f checkm_output/${sample_id}/${sample_id}_checkm_summary.tsv
    """
}
