process ASSEMBLY_ILLUMINA {
    tag "Illumina Assembly: SPAdes — ${sample_id}"

    publishDir "${params.outdir}/assembly/", mode: 'copy'

    input:
    tuple val(sample_id), path(reads_r1), path(reads_r2)

    output:
    tuple val(sample_id), path("assembly_output/${sample_id}_assembly")

    script:
    """
    mkdir -p assembly_output/${sample_id}_assembly

    spades.py \\
        --isolate \\
        -1 ${reads_r1} \\
        -2 ${reads_r2} \\
        -o assembly_output/${sample_id}_assembly/spades_tmp \\
        --threads ${task.cpus} \\
        --memory ${task.memory.toGiga()}

    # Normalise output to the same convention as the ONT assembly module
    cp assembly_output/${sample_id}_assembly/spades_tmp/scaffolds.fasta \\
       assembly_output/${sample_id}_assembly/assembly.fasta

    rm -rf assembly_output/${sample_id}_assembly/spades_tmp

    n=\$(grep -c '^>' assembly_output/${sample_id}_assembly/assembly.fasta)
    echo "SPAdes assembled \${n} scaffolds for ${sample_id}"
    """
}
