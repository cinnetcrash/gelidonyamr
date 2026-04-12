process POPPUNK {
    tag "Popülasyon Yapısı: PopPUNK"

    publishDir "${params.outdir}/poppunk/", mode: 'copy'

    input:
    path(assembly_dirs)

    output:
    path("poppunk_output/")

    script:
    """
    mkdir -p poppunk_output

    # Girdi dosyası oluştur (örnek_id <tab> assembly_yolu)
    for dir in ${assembly_dirs}; do
        sample=\$(basename \$dir)
        echo -e "\${sample}\\t\${dir}/assembly.fasta"
    done > poppunk_input.txt

    # Veritabanı oluştur
    poppunk --create-db \\
            --r-files poppunk_input.txt \\
            --output poppunk_output/db \\
            --min-k 13 \\
            --k-step 4 \\
            --threads ${task.cpus}

    # Model uydur (BGMM)
    poppunk --fit-model bgmm \\
            --ref-db poppunk_output/db \\
            --output poppunk_output/db \\
            --threads ${task.cpus}

    # Küme ataması
    poppunk_assign \\
            --db poppunk_output/db \\
            --query poppunk_input.txt \\
            --output poppunk_output/clusters \\
            --threads ${task.cpus}
    """
}
