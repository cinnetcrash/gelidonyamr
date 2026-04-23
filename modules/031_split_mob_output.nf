process SPLIT_MOB_OUTPUT {
    tag "Split chromosome/plasmid: ${sample_id}"

    publishDir "${params.outdir}/split/", mode: 'copy'

    input:
    tuple val(sample_id), path(mobsuite_dir)

    output:
    tuple val(sample_id), path("${sample_id}_chromosome.fasta"), emit: chromosome
    tuple val(sample_id), path("${sample_id}_plasmids.fasta"),   emit: plasmids,   optional: true

    script:
    """
    # Chromosome
    cp ${mobsuite_dir}/chromosome.fasta ${sample_id}_chromosome.fasta

    # Collect and merge all plasmid FASTAs (if any)
    plasmid_files=\$(find ${mobsuite_dir} -name "plasmid_*.fasta" 2>/dev/null | sort)

    if [ -n "\$plasmid_files" ]; then
        cat \$plasmid_files > ${sample_id}_plasmids.fasta
        n_plasmids=\$(echo "\$plasmid_files" | wc -l)
        n_contigs=\$(grep -c '^>' ${sample_id}_plasmids.fasta)
        echo "Found \${n_plasmids} plasmid file(s) — \${n_contigs} contig(s)"
    else
        echo "No plasmids detected by MOBsuite for ${sample_id}"
    fi
    """
}
