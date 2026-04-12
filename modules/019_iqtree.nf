process IQTREE {
    tag "ML Phylogeny: IQ-TREE"

    publishDir "${params.outdir}/iqtree/", mode: 'copy'

    input:
    path(roary_dir)

    output:
    path("iqtree_output/")

    script:
    """
    mkdir -p iqtree_output

    iqtree2 \\
        -s ${roary_dir}/core_gene_alignment.aln \\
        -m GTR+G \\
        -B 1000 \\
        -T ${task.cpus} \\
        --prefix iqtree_output/core_genome_tree
    """
}
