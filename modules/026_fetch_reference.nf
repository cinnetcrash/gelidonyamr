process FETCH_REFERENCE {
    tag "Download reference: ${accession} (${serovar})"

    publishDir "${params.outdir}/reference/", mode: 'copy'

    input:
    val accession
    val serovar

    output:
    path "reference_${serovar}.fna"

    script:
    """
    echo "Downloading reference genome for Salmonella ${serovar} (${accession})..."

    # Use NCBI Datasets REST API — no extra tools required beyond curl + unzip
    curl -L --retry 5 --retry-delay 10 --max-time 300 \
        "https://api.ncbi.nlm.nih.gov/datasets/v2/genome/accession/${accession}/download?include_annotation_type=GENOME_FASTA&filename=genome.zip" \
        -o genome.zip

    unzip -o genome.zip

    # Merge all sequences into one FASTA
    find ncbi_dataset/data/ -name "*.fna" | sort | xargs cat > reference_${serovar}.fna

    rm -rf genome.zip ncbi_dataset/

    if [ ! -s reference_${serovar}.fna ]; then
        echo "ERROR: Download produced an empty file for ${accession}" >&2
        exit 1
    fi

    n_seqs=\$(grep -c '^>' reference_${serovar}.fna)
    echo "Reference ready: \${n_seqs} sequence(s) for ${serovar} (${accession})"
    """
}
