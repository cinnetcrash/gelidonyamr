process CGMLST {
    tag "cgMLST Analysis: chewBBACA"

    publishDir params.outdir + "/cgmlst/", mode: 'copy'

    input:
    tuple val(sample_id), path(assembly_dir)

    output:
    tuple val(sample_id), path("cgmlst_output/${sample_id}_cgmlst/"),
          path("cgmlst_output/schema/"),
          path("cgmlst_output/training_file.trn")

    script:
    """
    mkdir -p data/cgmlst/
    mkdir -p cgmlst_output/

    # Always re-download cgMLST schema (overwrite if it exists)
    echo "Downloading cgMLST schema..."
    rm -rf data/cgmlst/
    chewBBACA.py DownloadSchema -sp ${params.cgmlst_species_id} -sc ${params.cgmlst_schema_id} -o data/cgmlst/

    # Find the .trn file in the schema directory
    trn_file=\$(find data/cgmlst/ -type f -name "*.trn" | head -n 1)

    if [ -z "\$trn_file" ]; then
        echo "ERROR: No .trn file found in schema directory!" >&2
        exit 1
    else
        echo "Using .trn file: \$trn_file"
    fi

    # Copy the .trn file and schema to local output directory
    cp "\$trn_file" cgmlst_output/training_file.trn
    cp -r data/cgmlst/ cgmlst_output/schema/

    # Run AlleleCall
    chewBBACA.py AlleleCall -i "${assembly_dir}/assembly.fasta" \\
                                  -o "cgmlst_output/${sample_id}_cgmlst" \\
                                  --cpu ${task.cpus} \\
                                  -g "data/cgmlst/" \\
                                  --bsr 0.6 \\
                                  --t 11 \\
                                  --l 5000 \\
                                  --st 0.05 \\
                                  --ptf "\$trn_file" | yes
    """
}
