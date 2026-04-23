process MERGE_BARCODES {
    tag "Merging barcode: ${sample_id}"

    publishDir "${params.outdir}/merged_reads/", mode: 'copy'

    input:
    tuple val(sample_id), path(barcode_dir)

    output:
    tuple val(sample_id), path("${sample_id}_merged.fastq")

    script:
    """
    # Collect all FASTQ files (gzipped or plain), sorted for reproducibility
    find -L ${barcode_dir} -maxdepth 1 \\
        \\( -name "*.fastq.gz" -o -name "*.fastq" -o -name "*.fq.gz" -o -name "*.fq" \\) \\
        | sort > file_list.txt

    if [ ! -s file_list.txt ]; then
        echo "ERROR: No FASTQ files found in ${barcode_dir}" >&2
        exit 1
    fi

    n_files=\$(wc -l < file_list.txt)
    echo "Merging \${n_files} file(s) for ${sample_id}..."

    while IFS= read -r f; do
        if [[ "\$f" == *.gz ]]; then
            zcat "\$f"
        else
            cat "\$f"
        fi
    done < file_list.txt > ${sample_id}_merged.fastq

    n_reads=\$(awk 'NR%4==1' ${sample_id}_merged.fastq | wc -l)
    echo "Done: \${n_reads} reads merged from \${n_files} files → ${sample_id}_merged.fastq"
    """
}
