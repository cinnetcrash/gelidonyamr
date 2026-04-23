process PHASTEST {
    tag "Prophage Detection: PHASTEST — ${sample_id}"

    publishDir "${params.outdir}/phastest/", mode: 'copy'

    input:
    tuple val(sample_id), path(fasta_file)

    output:
    tuple val(sample_id), path("phastest_output/${sample_id}_phastest.json")

    script:
    """
    mkdir -p phastest_output

    response=\$(curl -s --data-urlencode "seq@${fasta_file}" "https://phastest.ca/phastest_api")
    job_id=\$(echo "\$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('job_id',''))" 2>/dev/null)

    if [ -z "\$job_id" ]; then
        echo "ERROR: PHASTEST API submission failed. Response: \$response" >&2
        exit 1
    fi

    echo "PHASTEST job submitted: \$job_id"

    # Poll every 2 minutes
    while true; do
        result=\$(curl -s "https://phastest.ca/phastest_api?acc=\${job_id}")
        status=\$(echo "\$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status','0'))" 2>/dev/null || echo "0")
        echo "  Status: \$status"
        if [ "\$status" = "100" ]; then
            echo "\$result" > phastest_output/${sample_id}_phastest.json
            break
        fi
        sleep 120
    done
    """
}
