process PLASMIDFINDER {
    tag "Plazmid Tespiti: PlasmidFinder"

    publishDir "${params.outdir}/plasmidfinder/", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly_dir)

    output:
    tuple val(sample_id), path("plasmidfinder_output/${sample_id}/")

    script:
    """
    mkdir -p plasmidfinder_output/${sample_id}

    plasmidfinder.py \\
        --infile ${assembly_dir}/assembly.fasta \\
        --outputPath plasmidfinder_output/${sample_id} \\
        --databasePath ${params.plasmidfinder_db} \\
        --extendedOutput
    """
}
