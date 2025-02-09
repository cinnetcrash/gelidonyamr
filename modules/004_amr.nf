process AMR {
    tag "AMR Analizi Yapılıyor...: Abricate"

    publishDir params.outdir + "/amr/", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly_file)

    output:
    tuple val(sample_id), 
          path("amr_output/${sample_id}_plasmidfinder.tsv"),
          path("amr_output/${sample_id}_megares.tsv"),
          path("amr_output/${sample_id}_argannot.tsv"),
          path("amr_output/${sample_id}_resfinder.tsv"),
          path("amr_output/${sample_id}_vfdb.tsv"),
          path("amr_output/${sample_id}_card.tsv"),
          path("amr_output/${sample_id}_ncbi.tsv"),
          path("amr_output/abricate_summary.tsv")

    script:
    """
    mkdir -p amr_output

    # List of databases
    for db in plasmidfinder megares argannot resfinder vfdb card ncbi; do
        abricate --db \$db $assembly_file > amr_output/${sample_id}_\${db}.tsv
    done

    # Create summary file
    echo -e "Sample_ID\\tDatabase\\tGene\\tSequence\\tIdentity\\tCoverage" > amr_output/abricate_summary.tsv
    for db in plasmidfinder megares argannot resfinder vfdb card ncbi; do
        tail -n +2 amr_output/${sample_id}_\${db}.tsv >> amr_output/abricate_summary.tsv
    done
    """
}
