process CGMLST {
    tag "cgMLST Analizi: chewBBACA"

    publishDir params.outdir + "/cgmlst/", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly_dir)

    output:
    tuple val(sample_id), path("${params.outdir}/cgmlst/${sample_id}_cgmlst.tsv"),
    path("${params.outdir}/cgmlst/schema/"),  // Copy schema files
    path("${params.outdir}/cgmlst/training_file.trn")  // Copy detected .trn file

    script:
    """
    mkdir -p data/cgmlst/
    mkdir -p ${params.outdir}/cgmlst/

    # Always re-download cgMLST schema (overwrite if it exists)
    echo "Downloading cgMLST schema..."
    rm -rf data/cgmlst/  # Remove existing schema to avoid conflicts
    chewBBACA.py DownloadSchema -sp 8 -sc 1 -o data/cgmlst/

    # Find the .trn file in the schema directory
    trn_file=\$(find data/cgmlst/ -type f -name "*.trn" | head -n 1)

    if [ -z "\$trn_file" ]; then
        echo "ERROR: No .trn file found in schema directory!" >&2
        exit 1
    else
        echo "Using .trn file: \$trn_file"
    fi

    # Copy the .trn file to output directory for inspection
    cp "\$trn_file" "${params.outdir}/cgmlst/training_file.trn"

    # Copy the schema directory to output directory
    cp -r data/cgmlst/ "${params.outdir}/cgmlst/schema/"

    # Automatically respond "yes" to the AlleleCall prompt and use detected .trn file
    chewBBACA.py AlleleCall -i "${assembly_dir}/assembly.fasta" \\
                                  -o "${params.outdir}/cgmlst/${sample_id}_cgmlst" \\
                                  --cpu ${task.cpus} \\
                                  -g "data/cgmlst/" \\
                                  --bsr 0.6 \\
                                  --t 11 \\
                                  --l 5000 \\
                                  --st 0.05 \\
                                  --ptf "\$trn_file" | yes
    """
}
