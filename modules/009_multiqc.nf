process MULTIQC {
    tag "MultiQC Raporu Oluşturuluyor..."

    publishDir params.outdir + "/multiqc/", mode: 'copy'

    input:
    path fastqc_reports

    output:
    path("multiqc_output/multiqc_report.html")

    script:
    """
    mkdir -p multiqc_output
    multiqc fastqc_output/ --outdir multiqc_output/ --ai-summary-full
    """
}