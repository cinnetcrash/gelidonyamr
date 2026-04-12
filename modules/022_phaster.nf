process PHASTER {
    tag "Profaj Tespiti: PHASTER"

    publishDir "${params.outdir}/phaster/", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly_dir)

    output:
    tuple val(sample_id), path("phaster_output/${sample_id}_phaster.json")

    script:
    """
    mkdir -p phaster_output

    # PHASTER API'ye gönder
    response=\$(curl -s --data-urlencode "seq@${assembly_dir}/assembly.fasta" \\
        "https://phaster.ca/phaster_api")
    job_id=\$(echo "\$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('job_id',''))")

    if [ -z "\$job_id" ]; then
        echo "ERROR: PHASTER API submission failed! Response: \$response" >&2
        exit 1
    fi

    echo "PHASTER job ID: \$job_id"

    # Tamamlanana kadar her 2 dakikada bir kontrol et
    while true; do
        result=\$(curl -s "https://phaster.ca/phaster_api?acc=\${job_id}")
        status=\$(echo "\$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','0'))" 2>/dev/null || echo "0")
        echo "PHASTER status: \$status"
        if [ "\$status" = "100" ]; then
            echo "\$result" > phaster_output/${sample_id}_phaster.json
            break
        fi
        sleep 120
    done
    """
}
