process CGMLST {
    tag "cgMLST Analysis: chewBBACA"
    publishDir params.outdir + "/" +  "cgmlst/", mode: 'copy'
    
    input:
    path(assembled_reads)
    
    output:
    path "*.tsv" into cgmlst_results
    
    script:
    """
    chewBBACA.py AlleleCall -i ${assembled_reads} -g ${params.cgmlst_db} -o cgmlst_results
    """
}