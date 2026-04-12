process MLST {
    tag "MLST Analysis: mlst"

    publishDir params.outdir + "/mlst/", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly_dir)  
    
    output:
    tuple val(sample_id), path("mlst_output/${sample_id}_mlst.tsv")

    script:
    """
    mkdir -p mlst_output

    mlst --threads 3 "${assembly_dir}/assembly.fasta" > mlst_output/${sample_id}_mlst.tsv
    """
}
