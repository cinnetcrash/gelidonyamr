![GelidonyAMR Header](/visuals/gelindonyAMR.png)

# gelidonyAMR

**Oxford Nanopore Tabanlı *Salmonella Infantis* Genomik Epidemiyoloji Pipeline'ı**

---

The name **GelidonyAMR** is inspired by the **Gelidonya Lighthouse**, a historic maritime landmark on the southern coast of Türkiye. Just as the lighthouse has guided sailors for centuries, GelidonyAMR serves as a bioinformatics beacon for detecting antimicrobial resistance genes in *Salmonella Infantis* and other foodborne pathogens.

> **PhD Project:** *"Determination of Evolutionary Structure and Antimicrobial Resistance Profile of Salmonella Infantis"*

---

## Pipeline Genel Bakış

```
INPUT (SRA listesi veya FASTQ klasörü)
        │
        ▼
┌───────────────────────────────────┐
│  Kalite Kontrol                   │
│  FastQC · fastp · Kraken2         │
└────────────────┬──────────────────┘
                 │
                 ▼
┌───────────────────────────────────┐
│  Assembly                         │
│  Flye (Nano-raw)                  │
└────────────────┬──────────────────┘
                 │
                 ▼
┌───────────────────────────────────┐
│  Polishing & Assembly QC          │
│  Minimap2 + Racon (4×) · Clair3  │
│  QUAST · BUSCO · CheckM           │
└────────────────┬──────────────────┘
                 │
        ┌────────┴────────┐
        ▼                 ▼
┌──────────────┐  ┌────────────────┐
│  Anotasyon   │  │ Tür Doğrulama  │
│  Prokka      │  │ FastANI        │
│  Bakta       │  └────────────────┘
└──────┬───────┘
       │
       ├──── AMR Analizi ──────── AMRFinderPlus · Abricate (7 DB)
       │
       ├──── Plazmid Analizi ──── PlasmidFinder · MobSuite
       │
       ├──── Moleküler Tipleme ── MLST · cgMLST · PopPUNK
       │
       ├──── Filogeni ──────────── Parsnp · Roary → IQ-TREE
       │
       ├──── Prophage ──────────── PHASTER
       │
       └──── Varyant Anotasyonu ── Clair3 → snpEff
```

---

## Gereksinimler

- **İşletim Sistemi:** Linux (Ubuntu 20.04+ önerilir)
- **Conda / Mamba:** Ortam yönetimi için
- **Nextflow:** ≥ 23.10.0
- **Java:** 11 veya üzeri (Nextflow için)

> **Not:** PHASTER adımı internet bağlantısı gerektirir (https://phaster.ca API'si kullanılır).

---

## Kurulum

### 1. Conda Ortamını Oluştur

Çok sayıda araç içerdiğinden standart `conda` yerine `mamba` kullanılması **şiddetle tavsiye edilir** (10-20 kat daha hızlı çözümleme):

```bash
conda install -n base -c conda-forge mamba
mamba env create -f environment.yaml
conda activate gelidonyamr
```

> **Bağımlılık uyarısı:** `chewBBACA`, `clair3` ve `poppunk` bazı sistemlerde çakışma yaratabilir.
> Bu durumda aşağıdaki araçları ayrı bir ortamda kurmanız önerilir.
> Nextflow her işlemi ayrı bir work dizininde çalıştırdığı için ortam geçişi otomatik yapılabilir.

### 2. Veritabanlarını İndir

#### Kraken2
```bash
# Standart veritabanı (~60 GB)
kraken2-build --standard --db /home/analysis/kraken2_db --threads 8
```

#### Abricate
```bash
abricate --setupdb
abricate --list     # Kurulu DB'leri kontrol et
```

#### ChewBBACA cgMLST Şeması
Pipeline çalışırken otomatik indirilir. Manuel indirmek için:
```bash
chewBBACA.py DownloadSchema -sp 8 -sc 1 -o data/cgmlst/
```

#### Bakta
```bash
bakta_db download --output /home/analysis/bakta_db --type full
```

#### PlasmidFinder
```bash
# Resmi PlasmidFinder veritabanı
git clone https://bitbucket.org/genomicepidemiology/plasmidfinder_db.git /home/analysis/plasmidfinder_db
```

#### snpEff — Salmonella Veritabanı
```bash
snpEff download Salmonella_enterica
```

#### SRA Toolkit Yapılandırması (opsiyonel, indirme hızı için)
```bash
vdb-config --interactive
# Önbellek dizinini ve ağ ayarlarını yapılandırın
```

---

## Çalıştırma

### Mod 1 — FASTQ Klasörü ile

Elinizdeki Nanopore FASTQ dosyalarını bir klasöre koyun:

```
input_folder/
├── sample1.fastq
├── sample2.fastq
└── sample3.fastq
```

```bash
nextflow run main.nf \
  --reads "input_folder/*.fastq" \
  --outdir Results \
  -c config/nextflow.config
```

### Mod 2 — NCBI SRA Listesi ile

NCBI'dan doğrudan indirmek için bir TXT dosyası oluşturun:

```
# sra_accessions.txt
SRR12345678
SRR12345679
SRR12345680
ERR9876543
```

- Her satırda bir akesyon numarası (SRR / ERR / DRR)
- `#` ile başlayan satırlar yorum olarak göz ardı edilir
- Boş satırlar otomatik atlanır

```bash
nextflow run main.nf \
  --sra_list sra_accessions.txt \
  --outdir Results \
  -c config/nextflow.config
```

> `--reads` ve `--sra_list` aynı anda kullanılamaz. `--sra_list` verilmişse `--reads` göz ardı edilir.

### Ek Çalıştırma Seçenekleri

```bash
# Yarıda kalan pipeline'ı kaldığı yerden devam ettir
nextflow run main.nf -resume --reads "input_folder/*.fastq" -c config/nextflow.config

# Rapor ve zaman çizelgesi ile
nextflow run main.nf --reads "input_folder/*.fastq" -c config/nextflow.config \
  -with-report pipeline_report.html \
  -with-timeline pipeline_timeline.html

# Belirli bir iş (örn. sadece assembly testi için) — Nextflow -entry henüz desteklenmez,
# modülleri geçici olarak main.nf'den yorum satırına alabilirsiniz.
```

---

## Parametreler

| Parametre | Varsayılan | Açıklama |
|-----------|-----------|----------|
| `--reads` | `input_folder/*.fastq` | FASTQ dosyalarının yolu (glob desteklenir) |
| `--sra_list` | `null` | SRR akesyon numaralarının bulunduğu TXT dosyası |
| `--outdir` | `Results` | Tüm çıktıların yazılacağı dizin |
| `--ref_genome` | `data/ref_genome.fna` | Referans genom (Clair3, FastANI, Parsnp için) |
| `--kraken2_db` | `/home/analysis/kraken2_db` | Kraken2 veritabanı dizini |
| `--clair3_model` | `/opt/models/r941_prom_hac_g360+g422` | ONT kimya modeli |
| `--bakta_db` | `/home/analysis/bakta_db` | Bakta veritabanı dizini |
| `--plasmidfinder_db` | `/home/analysis/plasmidfinder_db` | PlasmidFinder veritabanı dizini |
| `--snpeff_db` | `Salmonella_enterica` | snpEff organizma veritabanı adı |
| `--max_cpu` | `14` | Maksimum CPU çekirdeği sayısı |
| `--max_memory` | `14GB` | Maksimum bellek |
| `--max_time` | `24h` | Maksimum çalışma süresi |

---

## Çıktı Dizin Yapısı

```
Results/
├── raw_reads/          # SRA modunda indirilen FASTQ dosyaları
├── fastqc/             # FastQC kalite raporları
├── trimmed/            # fastp ile kırpılmış okumalar
├── kraken2/            # Taksonomi sınıflandırma sonuçları
├── assembly/           # Flye ham assembly çıktıları
├── polished/           # Minimap2 + Racon ile cilalı genomlar (kullanılan)
├── quast/              # Assembly kalite metrikleri
├── busco/              # Genom tamlık değerlendirmesi
├── checkm/             # Kontaminasyon / tamlık kontrolü
├── fastani/            # Tür doğrulama (ANI değerleri)
├── annotation/         # Prokka anotasyon dosyaları (.gff, .gbk, .faa)
├── bakta/              # Bakta anotasyon dosyaları
├── amr/                # Abricate sonuçları (7 veritabanı)
├── amrfinder/          # AMRFinder Plus sonuçları
├── mobsuite/           # Plazmid rekonstruksiyon ve mobilizasyon analizi
├── plasmidfinder/      # Replikon tipleme sonuçları
├── mlst/               # 7-gen MLST tipleme
├── cgmlst/             # chewBBACA cgMLST / wgMLST
├── clair3/             # Varyant çağırma (VCF)
├── snpeff/             # Varyant anotasyonu
├── phaster/            # Profaj tespiti (JSON)
├── roary/              # Pan-genom analizi (core/accessory)
├── iqtree/             # ML filogenetik ağaç
├── parsnp/             # Core SNP analizi
├── poppunk/            # Popülasyon yapısı ve kümeler
├── multiqc/            # Tüm QC çıktılarının özet raporu
└── pipeline_info/      # Nextflow zaman çizelgesi ve raporu
```

---

## Araç Referansı

| Adım | Araç | Sürüm |
|------|------|-------|
| SRA İndirme | SRA Toolkit (fasterq-dump) | ≥3.0 |
| Kalite Kontrol | FastQC | 0.12.1 |
| Trimming | fastp | 0.24.0 |
| Taksonomi | Kraken2 | 2.1.3 |
| Assembly | Flye | 2.9 |
| Polishing | Minimap2 + Racon | ≥2.26 / ≥1.5 |
| Varyant Çağırma | Clair3 | ≥1.0 |
| Assembly QC | QUAST | 5.3.0 |
| Genom Tamlık | BUSCO | 5.7.1 |
| Kalite Denetim | CheckM | ≥1.2 |
| Tür Doğrulama | FastANI | ≥1.34 |
| Anotasyon | Prokka + Bakta | ≥1.14 / ≥1.9 |
| AMR | AMRFinder Plus | ≥3.12 |
| AMR | Abricate | 1.0.1 |
| Plazmid | PlasmidFinder | ≥2.1 |
| Plazmid | MobSuite | ≥3.1 |
| Tipleme | MLST | 2.23.0 |
| Tipleme | chewBBACA | 3.3.6 |
| Prophage | PHASTER | Web API |
| Varyant Anotasyon | snpEff | ≥5.2 |
| Pan-Genom | Roary | ≥3.13 |
| Filogeni | IQ-TREE2 | ≥2.3 |
| Core SNP | Parsnp | ≥2.0 |
| Popülasyon | PopPUNK | ≥2.6 |
| QC Özet | MultiQC | 1.27 |

---

## Referans Genom

- **Organizma:** *Salmonella enterica* subsp. *enterica* serovar Infantis
- **Akesyon:** `LN649235.1`
- **NCBI Assembly:** `GCA_000953495.1`

Referans genomu indirmek için:
```bash
datasets download genome accession GCA_000953495.1 --include genome
```

---

## Sık Sorulan Sorular

**S: SRA adımı için ekstra bir şey yapmalı mıyım?**

Hayır. `--sra_list` parametresine TXT dosyanızın yolunu verin, pipeline her şeyi halleder.
Tek gereksinim: `sra-tools` paketinin conda ortamında kurulu olması (environment.yaml ile otomatik kurulur).
İndirme hızını artırmak için `vdb-config --interactive` ile AWS/GCP yönlendirmesini yapılandırabilirsiniz.

**S: Tüm araçlar tek bir conda ortamında çalışıyor mu?**

Araçların büyük çoğunluğu `bioconda` kanalı aracılığıyla conda ile kurulabilir.
Ancak `chewBBACA`, `clair3` ve `poppunk` bazı Python bağımlılıklarında çakışma yaratabilir.
Sorun yaşarsanız `mamba` kullanın — standart `conda`'ya göre bağımlılıkları çok daha iyi çözümler.
PHASTER için lokal kurulum gerekmez; pipeline web API üzerinden çalışır (internet bağlantısı gerekli).

**S: Pipeline yarıda kaldı, nasıl devam ettiririm?**

```bash
nextflow run main.nf -resume --reads "input_folder/*.fastq" -c config/nextflow.config
```

`-resume` bayrağı Nextflow'un tamamlanan adımları önbellekten okumasını sağlar.

**S: Sadece birkaç adımı çalıştırabilir miyim?**

`main.nf` içinde çalıştırmak istemediğiniz adımları `//` ile yorum satırına alabilirsiniz.

---

## Katkıda Bulunma / İletişim

Sorunlar için GitHub Issues kullanın veya doğrudan iletişime geçin.

---

**Pipeline Geliştirici:** Gültekin Ünal

*Gelidonya Deniz Feneri'nden ilham alınmıştır — Finike, Türkiye*
