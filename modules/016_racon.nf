process RACON {
    tag "Polishing: Minimap2 + Racon (4×)"

    publishDir "${params.outdir}/polished/", mode: 'copy'

    input:
    tuple val(sample_id), path(reads_file), path(assembly_dir)

    output:
    tuple val(sample_id), path("polished_output/${sample_id}_polished")

    script:
    """
    mkdir -p polished_output/${sample_id}_polished

    # Başlangıç assembly'yi kopyala
    cp ${assembly_dir}/assembly.fasta polished_output/${sample_id}_polished/assembly.fasta

    # 4 tur Racon polishing
    for i in 1 2 3 4; do
        minimap2 -ax map-ont -t ${task.cpus} \\
            polished_output/${sample_id}_polished/assembly.fasta \\
            ${reads_file} > mappings_round\${i}.paf

        racon -t ${task.cpus} \\
            ${reads_file} \\
            mappings_round\${i}.paf \\
            polished_output/${sample_id}_polished/assembly.fasta \\
            > polished_output/${sample_id}_polished/racon_round\${i}.fasta

        # Sonraki tur için güncelle
        cp polished_output/${sample_id}_polished/racon_round\${i}.fasta \\
           polished_output/${sample_id}_polished/assembly.fasta
    done

    # Ara dosyaları temizle
    rm -f mappings_round*.paf
    rm -f polished_output/${sample_id}_polished/racon_round*.fasta
    """
}
