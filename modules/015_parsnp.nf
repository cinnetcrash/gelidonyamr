process PARSNP {
    tag "Core SNP Phylogeny: Parsnp"

    publishDir "${params.outdir}/parsnp/", mode: 'copy'

    input:
    path assembly_dirs
    path ref_genome_file

    output:
    path "parsnp_output/"

    script:
    """
    mkdir -p assemblies parsnp_output

    for dir in ${assembly_dirs}; do
        sample=\$(basename \$dir)
        cp \${dir}/assembly.fasta assemblies/\${sample}.fasta
    done

    parsnp -r ${ref_genome_file} \\
           -d assemblies/ \\
           -o parsnp_output/ \\
           -p ${task.cpus} \\
           -c
    """
}
