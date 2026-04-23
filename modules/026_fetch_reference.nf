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
    #!/usr/bin/env python3
    import urllib.request, urllib.error, zipfile, shutil, os, sys, time

    accession = "${accession}"
    serovar   = "${serovar}"
    out_fasta = f"reference_{serovar}.fna"
    url = (f"https://api.ncbi.nlm.nih.gov/datasets/v2/genome/accession/{accession}/download"
           f"?include_annotation_type=GENOME_FASTA&filename=genome.zip")

    print(f"Downloading {serovar} reference genome ({accession}) from NCBI...")

    for attempt in range(5):
        try:
            urllib.request.urlretrieve(url, "genome.zip")
            break
        except Exception as e:
            if attempt == 4:
                print(f"ERROR: Download failed after 5 attempts: {e}", file=sys.stderr)
                sys.exit(1)
            time.sleep(10)

    with zipfile.ZipFile("genome.zip") as z:
        with open(out_fasta, "wb") as out:
            for name in sorted(z.namelist()):
                if name.endswith(".fna"):
                    with z.open(name) as f:
                        shutil.copyfileobj(f, out)

    os.remove("genome.zip")

    if not os.path.getsize(out_fasta):
        print(f"ERROR: Empty FASTA for {accession}", file=sys.stderr)
        sys.exit(1)

    n = sum(1 for line in open(out_fasta) if line.startswith(">"))
    print(f"Reference ready: {n} sequence(s) for {serovar} ({accession})")
    """
}
