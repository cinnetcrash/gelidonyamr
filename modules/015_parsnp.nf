process PARSNP {
    tag "Core SNP Phylogeny: Parsnp"

    publishDir "${params.outdir}/parsnp/", mode: 'copy'

    input:
    path(assembly_dirs)

    output:
    path("parsnp_output/")

    script:
    """
    mkdir -p assemblies parsnp_output

    # Copy each assembly.fasta with a unique name derived from the directory
    for dir in ${assembly_dirs}; do
        sample=\$(basename \$dir)
        cp \${dir}/assembly.fasta assemblies/\${sample}.fasta
    done

    parsnp -r ${params.ref_genome} \\
           -d assemblies/ \\
           -o parsnp_output/ \\
           -p ${task.cpus} \\
           -c
    """
}
