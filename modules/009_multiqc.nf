process MULTIQC {
    tag "MultiQC Raporu Oluşturuluyor..."

    publishDir params.outdir + "/multiqc/", mode: 'copy'

    input:
    path(fastqc_reports)

    output:
    path("multiqc_output/multiqc_report.html")

    script:
    """
    mkdir -p multiqc_output

    # Debug: List input files
    echo "FastQC reports available for MultiQC:"
    ls -lh ${fastqc_reports}

    # Run MultiQC with correct input files
    multiqc ${fastqc_reports} --outdir multiqc_output/ --force

    # Debug: Check if the report was generated
    if [ ! -f "multiqc_output/multiqc_report.html" ]; then
        echo "ERROR: MultiQC report not found!" >&2
        exit 1
    fi
    """
}
