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

    # Debug: List available FastQC files
    echo "Checking available FastQC reports for MultiQC:"
    ls -lh ${fastqc_reports}

    # Find valid FastQC files (zip or fastqc_data.txt)
    valid_files=\$(find ${fastqc_reports} -type f -name "*_fastqc.zip" -o -name "fastqc_data.txt" | wc -l)

    if [ "\$valid_files" -eq 0 ]; then
        echo "ERROR: No valid FastQC reports found for MultiQC!" >&2
        exit 1
    fi

    # Run MultiQC with valid FastQC files
    multiqc ${fastqc_reports} --outdir multiqc_output/ --force

    # Verify if MultiQC report was successfully generated
    if [ ! -f "multiqc_output/multiqc_report.html" ]; then
        echo "ERROR: MultiQC report not found!" >&2
        exit 1
    fi
    """
}
