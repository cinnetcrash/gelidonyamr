// Autocycler consensus assembly:
// Runs Flye, Miniasm+Minipolish, and Raven independently,
// then uses Autocycler to build a consensus from all three.
process ASSEMBLY_AUTOCYCLER {
    tag "Autocycler assembly: ${sample_id}"

    publishDir "${params.outdir}/assembly/", mode: 'copy'

    input:
    tuple val(sample_id), path(reads_file)

    output:
    tuple val(sample_id), path("assembly_output/${sample_id}_assembly")

    script:
    """
    mkdir -p assembly_output/${sample_id}_assembly
    mkdir -p assemblies

    # ── Assembler 1: Flye ───────────────────────────────────────────
    flye --nano-hq ${reads_file} \\
         --out-dir flye_out \\
         --genome-size ${params.genome_size} \\
         --threads ${task.cpus}
    cp flye_out/assembly.fasta assemblies/flye.fasta

    # ── Assembler 2: Miniasm + Minimap2 ────────────────────────────
    minimap2 -x ava-ont -t ${task.cpus} ${reads_file} ${reads_file} > overlaps.paf
    miniasm -f ${reads_file} overlaps.paf > miniasm.gfa
    awk '/^S/{print ">"\\$2; print \\$3}' miniasm.gfa > assemblies/miniasm_raw.fasta

    # Polish miniasm with one round of Racon
    minimap2 -x map-ont -t ${task.cpus} assemblies/miniasm_raw.fasta ${reads_file} > mini_map.paf
    racon -t ${task.cpus} ${reads_file} mini_map.paf assemblies/miniasm_raw.fasta > assemblies/miniasm.fasta

    # ── Assembler 3: Raven ──────────────────────────────────────────
    raven --threads ${task.cpus} ${reads_file} > assemblies/raven.fasta

    # ── Autocycler consensus ────────────────────────────────────────
    autocycler compress \\
        --reads ${reads_file} \\
        --out-dir autocycler_work

    autocycler cluster \\
        --assemblies assemblies/flye.fasta assemblies/miniasm.fasta assemblies/raven.fasta \\
        --out-dir autocycler_work

    autocycler trim   --cluster-dir autocycler_work
    autocycler resolve --cluster-dir autocycler_work

    autocycler combine \\
        --cluster-dir autocycler_work \\
        --out-file assembly_output/${sample_id}_assembly/assembly.fasta

    n=\$(grep -c '^>' assembly_output/${sample_id}_assembly/assembly.fasta || echo 0)
    echo "Autocycler assembled \${n} contig(s) for ${sample_id}"

    # Clean up
    rm -rf flye_out overlaps.paf miniasm.gfa mini_map.paf assemblies/ autocycler_work/
    """
}
