process SRA_DOWNLOAD {
    tag "SRA Download: ${srr_id}"

    publishDir "${params.outdir}/raw_reads/", mode: 'copy'

    input:
    val srr_id

    output:
    tuple val(srr_id), path("${srr_id}.fastq")

    script:
    """
    # Prefetch + fasterq-dump (ONT data produces single-end FASTQ)
    prefetch ${srr_id} --output-directory .
    fasterq-dump ${srr_id}/${srr_id}.sra \\
        --outdir . \\
        --threads ${task.cpus} \\
        --skip-technical

    # Merge split files if multiple parts were downloaded
    if ls ${srr_id}_*.fastq 1>/dev/null 2>&1; then
        cat ${srr_id}_*.fastq > ${srr_id}.fastq
        rm -f ${srr_id}_*.fastq
    fi

    # Clean up prefetch directory
    rm -rf ${srr_id}/
    """
}
