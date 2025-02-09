process MLST {
    tag "MLST Analysis: mlst"

    publishDir params.outdir + "/mlst/", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly_dir)  
    
    output:
    tuple val(sample_id), path("mlst_output/${sample_id}_mlst.tsv"),
    path("mlst_output/mlst_summary.tsv")

    script:
    """
    mkdir -p mlst_output

    # Define the correct FASTA file path using Nextflow's variable expansion
    mlst "${assembly_dir}/assembly.fasta" > mlst_output/${sample_id}_mlst.tsv --threads 2

    # Append to summary file
    if [[ ! -s mlst_output/mlst_summary.tsv ]]; then
        echo -e "Sample_ID\tScheme\tST\tMatches" > mlst_output/mlst_summary.tsv
    fi
    cat mlst_output/${sample_id}_mlst.tsv | tail -n +2 >> mlst_output/mlst_summary.tsv
    """
}
