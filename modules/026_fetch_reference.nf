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

    datasets download genome accession ${accession} \
        --include genome \
        --filename genome.zip

    unzip -o genome.zip

    # Merge all contigs/chromosomes into one FASTA
    cat ncbi_dataset/data/*/*.fna > reference_${serovar}.fna

    rm -rf genome.zip ncbi_dataset/

    if [ ! -s reference_${serovar}.fna ]; then
        echo "ERROR: Download produced an empty file for ${accession}" >&2
        exit 1
    fi

    n_seqs=\$(grep -c '^>' reference_${serovar}.fna)
    echo "Reference ready: \${n_seqs} sequence(s) for ${serovar} (${accession})"
    """
}
