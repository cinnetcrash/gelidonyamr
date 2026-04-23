process FETCH_CONTEXT_GENOMES {
    tag "Fetch context genomes: ${serovar} (${n_per_country}/country, max ${max_total})"

    publishDir "${params.outdir}/context_genomes/", mode: 'copy'

    input:
    val serovar
    val n_per_country
    val max_total

    output:
    path "context_genomes/*.fasta", emit: fastas
    path "context_genome_manifest.tsv",  emit: manifest

    script:
    """
    #!/usr/bin/env python3
import sys, json, os, zipfile, shutil, time
import urllib.request, urllib.parse, urllib.error

SEROVAR      = "${serovar}"
N_PER        = int("${n_per_country}")
MAX_TOTAL    = int("${max_total}")
BASE         = "https://api.ncbi.nlm.nih.gov/datasets/v2"
HEADERS      = {"Accept": "application/json"}

def api_get(url, retries=3):
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read())
        except Exception as e:
            if attempt == retries - 1:
                raise
            time.sleep(5)

# ── Search for assemblies ──────────────────────────────────────────────
print(f"Searching NCBI for Salmonella {SEROVAR} assemblies...")

page_token = None
reports = []
while True:
    url = (f"{BASE}/genome/taxon/Salmonella%20enterica/dataset_report"
           f"?filters.assembly_level=complete&page_size=200"
           f"&returned_content=ASSEMBLY_INFO")
    if page_token:
        url += f"&page_token={page_token}"
    data = api_get(url)
    reports.extend(data.get("reports", []))
    page_token = data.get("next_page_token")
    if not page_token or len(reports) > 2000:
        break

print(f"Total assemblies retrieved: {len(reports)}")

# ── Filter by serovar and group by country ────────────────────────────
country_groups = {}
for r in reports:
    org = r.get("organism", {}).get("organism_name", "")
    if SEROVAR.lower() not in org.lower():
        continue

    attrs = r.get("assembly_info", {}).get("biosample", {}).get("attributes", []) or []
    geo = next((a.get("value","").split(":")[0].strip()
                for a in attrs if a.get("name") == "geo_loc_name"), "")

    if not geo or geo in ("not collected", "missing", "not applicable", "N/A"):
        continue

    acc = r.get("accession", "")
    if not acc:
        continue

    country_groups.setdefault(geo, []).append(acc)

print(f"Found genomes from {len(country_groups)} countries")

# ── Select up to N_PER per country, MAX_TOTAL total ───────────────────
selected = []
manifest_lines = ["accession\\tcountry\\tfile"]
for country in sorted(country_groups):
    for acc in country_groups[country][:N_PER]:
        selected.append((country, acc))
    if len(selected) >= MAX_TOTAL:
        break
selected = selected[:MAX_TOTAL]
print(f"Selected {len(selected)} assemblies from {len(set(c for c,_ in selected))} countries")

# ── Download genomes ──────────────────────────────────────────────────
os.makedirs("context_genomes", exist_ok=True)
ok = 0
for country, acc in selected:
    safe = country.replace(" ","_").replace("/","-").replace("'","")
    out  = f"context_genomes/{safe}_{acc}.fasta"
    dl   = (f"{BASE}/genome/accession/{acc}/download"
            f"?include_annotation_type=GENOME_FASTA&filename=genome.zip")
    try:
        urllib.request.urlretrieve(dl, "tmp.zip")
        with zipfile.ZipFile("tmp.zip") as z:
            for name in z.namelist():
                if name.endswith(".fna"):
                    with z.open(name) as fi, open(out,"wb") as fo:
                        shutil.copyfileobj(fi, fo)
                    break
        os.remove("tmp.zip")
        manifest_lines.append(f"{acc}\\t{country}\\t{os.path.basename(out)}")
        ok += 1
        print(f"  [{ok}/{len(selected)}] {country} — {acc}")
    except Exception as e:
        print(f"  SKIP {acc}: {e}", file=sys.stderr)

with open("context_genome_manifest.tsv","w") as f:
    f.write("\\n".join(manifest_lines) + "\\n")

print(f"Done: {ok} context genomes downloaded")
    """
}
