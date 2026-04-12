process POPPUNK {
    tag "Population Structure: PopPUNK"

    publishDir "${params.outdir}/poppunk/", mode: 'copy'

    input:
    path(assembly_dirs)

    output:
    path("poppunk_output/")

    script:
    """
    mkdir -p poppunk_output

    # Build input file (sample_id <tab> assembly_path)
    for dir in ${assembly_dirs}; do
        sample=\$(basename \$dir)
        echo -e "\${sample}\\t\${dir}/assembly.fasta"
    done > poppunk_input.txt

    # Create sketch database
    poppunk --create-db \\
            --r-files poppunk_input.txt \\
            --output poppunk_output/db \\
            --min-k 13 \\
            --k-step 4 \\
            --threads ${task.cpus}

    # Fit BGMM model
    poppunk --fit-model bgmm \\
            --ref-db poppunk_output/db \\
            --output poppunk_output/db \\
            --threads ${task.cpus}

    # Assign clusters
    poppunk_assign \\
            --db poppunk_output/db \\
            --query poppunk_input.txt \\
            --output poppunk_output/clusters \\
            --threads ${task.cpus}
    """
}
