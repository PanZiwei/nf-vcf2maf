# nf-vcf2maf: Annotate VCF Files and Generate MAF Files

> [!NOTE]
> This is an actively maintained fork of [sage-bionetworks-workflows/nf-vcf2maf](https://github.com/sage-bionetworks-workflows/nf-vcf2maf). The `modularize` branch restructures the pipeline into a modular layout and makes containers configurable without editing module files. See [What's new](#whats-new) for a summary.

## Purpose

This Nextflow workflow annotates variants in VCF files using the Ensembl Variant Effect Predictor (VEP) and converts the annotated output into [Mutation Annotation Format](https://docs.gdc.cancer.gov/Data/File_Formats/MAF_Format/) (MAF). Unlike VEP-annotated VCF files, MAF files are tabular and more useful for downstream applications. They can be loaded directly into R (for example, with the [`maftools`](https://www.bioconductor.org/packages/release/bioc/html/maftools.html) package) and used to generate input files for [cBioPortal](https://www.cbioportal.org/visualize).

**Important:** Please read the [limitations](#known-limitations) listed below.

This workflow uses the [sagebionetworks/vcf2maf](https://hub.docker.com/r/sagebionetworks/vcf2maf) container image, which bundles the [Sage Bionetworks fork of vcf2maf](https://github.com/Sage-Bionetworks-Workflows/vcf2maf) and VEP 107. The VEP cache is loaded at runtime from `s3://sage-igenomes`.

## What's new

The `modularize` branch introduces three sets of changes relative to the original `main` branch. None of these changes alter runtime behavior or output files.

**Modular layout (#10).** All processes are split into individual files under `modules/`, and the two main workflows live in `workflows/`. The `main.nf` entrypoint only wires them together. This makes each component easier to test, reuse, and review independently.

**Configurable containers (#11).** Container images are no longer hardcoded inside module files. Every module carries a process label, and all container assignments live in `withLabel` blocks inside `nextflow.config`. To swap an image, edit one line in the config rather than hunting across multiple module files.

**Synapseclient upgrade (#13).** The Synapse download and upload steps now use `ghcr.io/sage-bionetworks/synapsepythonclient:v4.13.0` (GitHub Container Registry) instead of the older `sagebionetworks/synapsepythonclient:v2.6.0` on Docker Hub. The `synapse get` and `synapse store` CLI commands are backward-compatible across v2 and v4.

## Architecture

```
main.nf                         # Entrypoint: parses samplesheet, calls SAMPLE_MAFS + STUDY_MAFS
workflows/
  sample_mafs.nf                # Per-sample workflow: download VCF -> annotate -> upload MAF
  study_mafs.nf                 # Per-study workflow: filter -> merge -> upload merged MAF
modules/
  synapse_get.nf                # Download a file from Synapse by ID
  extract_tar_gz.nf             # Decompress and extract the VEP cache tarball
  vcf2maf.nf                    # Run vcf2maf (calls VEP internally)
  filter_maf.nf                 # Filter MAF to PASS/. variants only
  merge_mafs.nf                 # Merge per-sample MAFs into a study-level MAF
  synapse_store.nf              # Upload a file to Synapse
bin/
  filter_maf.py                 # Python script called by FILTER_MAF
  merge_mafs.py                 # Python script called by MERGE_MAFS
nextflow.config                 # All parameters and container assignments
```

### Container labels

Each module carries one or more process labels. The container image and resource settings for each label are defined in `nextflow.config` under `process { withLabel: ... }`.

| Label | Modules | Purpose |
|---|---|---|
| `synapse_python_client` | `synapse_get`, `synapse_store` | Synapse CLI (download/upload) |
| `vcf2maf` | `vcf2maf` | vcf2maf + VEP binary |
| `vcf2maf_compute` | `vcf2maf` | CPU/memory sizing for annotation |
| `python312` | `filter_maf`, `merge_mafs` | Python 3.12 for post-processing scripts |
| `python312_compute` | `merge_mafs` | Memory sizing for large merges |

To change a container image, update the corresponding `container = '...'` line in `nextflow.config`. No module file needs to be touched.

## Quickstart

1. Prepare a CSV samplesheet according to the [format](#samplesheet) described below.

    **Example:** Stored locally as `./samplesheet.csv`

    ```csv
    synapse_id  ,biospecimen_id ,sample_parent_id ,merged_parent_id ,study_id ,variant_class ,variant_caller ,is_releasable
    syn87654301 ,sample_001     ,syn87654311      ,syn87654321      ,study_x  ,germline      ,deepvariant    ,true
    syn87654302 ,sample_002     ,syn87654311      ,syn87654321      ,study_x  ,germline      ,deepvariant    ,false
    syn87654303 ,sample_003     ,syn87654311      ,syn87654321      ,study_x  ,germline      ,deepvariant    ,true
    syn87654304 ,sample_004     ,syn87654312      ,syn87654321      ,study_x  ,germline      ,mutect2        ,false
    syn87654307 ,sample_007     ,syn87654313      ,syn87654322      ,study_y  ,germline      ,deepvariant    ,true
    syn36245848 ,sample_008     ,syn87654313      ,syn87654322      ,study_y  ,germline      ,deepvariant    ,true
    ```

2. Create a Nextflow secret called `SYNAPSE_AUTH_TOKEN` with a Synapse personal access token ([docs](#authentication)).

3. Prepare a parameters file. Only `input` is required; the remaining parameters have sensible defaults.

    **Example:** Stored locally as `./params.yml`

    ```yaml
    input: "./samplesheet.csv"
    maf_center: "Sage Bionetworks"
    max_subpop_af: 0.0005
    ```

4. Launch the workflow using the [Nextflow CLI](https://nextflow.io/docs/latest/cli.html#run), the [Tower CLI](https://help.tower.nf/latest/cli/), or the [Tower web UI](https://help.tower.nf/latest/launch/launchpad/).

    **Example:** Launched using the Nextflow CLI with Docker enabled

    ```console
    nextflow run PanZiwei/nf-vcf2maf -r modularize -params-file ./params.yml -profile docker
    ```

5. Explore the MAF files uploaded to Synapse (using the parent IDs listed in the samplesheet).

## Authentication

This workflow transfers files to and from Synapse, so it requires a secret with a personal access token for authentication. To configure Nextflow with such a token:

1. Generate a personal access token (PAT) on Synapse using [this dashboard](https://www.synapse.org/#!PersonalAccessTokens:). Enable the `view`, `download`, and `modify` scopes, since the workflow both downloads VCF files and uploads MAF files.
2. Create a secret called `SYNAPSE_AUTH_TOKEN` using the [Nextflow CLI](https://nextflow.io/docs/latest/secrets.html) or [Nextflow Tower](https://help.tower.nf/latest/secrets/overview/).
3. (Tower only) When launching the workflow, include `SYNAPSE_AUTH_TOKEN` as a pipeline secret from your user or workspace secrets.

## Parameters

Check out the [Quickstart](#quickstart) section for example parameter values. Some parameters have not been tested with non-default values; see [Known Limitations](#known-limitations).

- **`input`**: (Required) Path to a CSV samplesheet listing the VCF files to process. See [Samplesheet](#samplesheet) below.
- **`max_subpop_af`**: Allele-frequency threshold for the `common_variant` filter in vcf2maf. Variants with a gnomAD sub-population AF at or above this value are flagged as common variants and excluded from merged MAF files ([source](https://github.com/mskcc/vcf2maf/blob/5ed414428046e71833f454d4b64da6c30362a89b/docs/vep_maf_readme.txt#L116-L120)). Default: `0.0005`.
- **`maf_center`**: Value written to the `Center` MAF column. Default: `"Sage Bionetworks"`.
- **`reference_fasta`**: Reference genome FASTA file. Default: `"s3://sage-igenomes/igenomes/Homo_sapiens/GATK/GRCh38/Sequence/WholeGenomeFasta/Homo_sapiens_assembly38.fasta"`.
- **`reference_fasta_fai`**: Reference genome FASTA index (FAI) file. The workflow picks this up automatically from the `.fai` alongside the FASTA in most cases. Default: `"${reference_fasta}.fai"`.
- **`vep_tarball`**: Compressed tarball of the VEP cache. Default: `"s3://sage-igenomes/vep_cache/homo_sapiens_vep_107_GRCh38.tar.gz"`.
- **`ncbi_build`**: NCBI genome build, passed to `--assembly` in VEP ([source](http://Jul2022.archive.ensembl.org/info/docs/tools/vep/script/vep_options.html)). Default: `"GRCh38"`.
- **`species`**: Species identifier, passed to `--species` in VEP ([source](http://Jul2022.archive.ensembl.org/info/docs/tools/vep/script/vep_options.html)). Default: `"homo_sapiens"`.
- **`vep_stats_params`**: When `true`, passes `--vep-stats` to `vcf2maf.pl`, which suppresses the internal `--no_stats` flag. The `--no_stats` flag triggers a [known VEP bug](https://github.com/Ensembl/ensembl-vep/issues/1013#issuecomment-874079598) with no upstream fix; the VEP team recommends running without it. Set to `false` to restore the original `--no_stats` behavior. Default: `true`.
- **`max_cpus`**: Maximum number of CPUs available. Used for resource capping. Default: `16`.
- **`max_memory`**: Maximum memory available. Used for resource capping. Default: `"128.GB"`.

## Inputs

### Samplesheet

The input samplesheet must be in comma-separated values (CSV) format. Avoid spaces or special characters in any column value to prevent job caching issues.

1. **`synapse_id`**: Synapse ID of the VCF file. The Synapse account associated with the token must have access to every listed file.
2. **`biospecimen_id`**: Biospecimen or sample identifier. This value populates the `Tumor_Sample_Barcode` MAF column and must be unique within each merged MAF file.
3. **`sample_parent_id`**: Synapse ID of the folder where the per-sample MAF file will be uploaded. A common choice is the folder that contains the corresponding VCF file.
4. **`merged_parent_id`**: Synapse ID of the folder where the merged study MAF file will be uploaded. This value must be consistent across all VCF files that belong to the same merged MAF; inconsistent values produce artificially split merged files.
5. **`study_id`**: Study identifier. The Synapse ID of the study project works well if no shorthand ID exists.
6. **`variant_class`**: `somatic` or `germline`.
7. **`variant_caller`**: Name of the variant caller used to produce the VCF.
8. **`is_releasable`**: `true` or `false`. Only samples marked `true` are included in merged MAF files.

## Outputs

### MAF files

**Per-sample MAF files** (uploaded to `sample_parent_id`)
- Unfiltered: includes all variants regardless of their FILTER status
- Naming: `${biospecimen_id}-${variant_class}-${variant_caller}.maf`

**Merged study MAF files** (uploaded to `merged_parent_id`, one per combination of `study_id`, `variant_class`, and `variant_caller`)
- Filtered: restricted to releasable samples and variants where `FILTER` is `PASS` or `.` (excludes variants flagged `common_variant`)
- Naming: `${study_id}-${variant_class}-${variant_caller}.merged.maf`

## Known Limitations

- This workflow has only been tested with the following parameter values:
  - `vep_tarball`: Ensembl VEP 107 (GRCh38)
  - `species`: `homo_sapiens`
  - `ncbi_build`: `GRCh38`
  - `reference_fasta`: GATK GRCh38 FASTA from `sage-igenomes`
- The VEP binary version inside the container must match the VEP cache version. The default `sagebionetworks/vcf2maf:107.2` image bundles VEP 107 and is paired with the VEP 107 cache at `s3://sage-igenomes`. Switching to a different vcf2maf image without updating the cache (or vice versa) will produce incorrect or empty gnomAD annotation columns without a visible error.
- The upstream `mskcc/vcf2maf` repository was archived in May 2026. Sage Bionetworks maintains its own fork, and `sagebionetworks/vcf2maf:107.2` is based on that fork. A migration path to community-maintained tooling is under evaluation in [issue #12](https://github.com/sage-bionetworks-workflows/nf-vcf2maf/issues/12).

## Benchmarks

### Setup

The following benchmarks were performed on an EC2 instance.

```console
# Install tmux for long-running commands
sudo yum install -y tmux

# Install and set up Nextflow
sudo yum install -y java
(cd .local/bin && wget -qO- https://get.nextflow.io | bash)
echo 'export NXF_ENABLE_SECRETS=true' >> ~/.bashrc
source ~/.bashrc
nextflow secrets put -n SYNAPSE_AUTH_TOKEN -v "<synapse-pat>"
mkdir -p $HOME/.nextflow/
echo 'aws.client.anonymous = true' >> $HOME/.nextflow/config

# Download and extract Ensembl VEP cache
mkdir -p $HOME/ref/ $HOME/.vep/
rsync -avr --progress rsync://ftp.ensembl.org/ensembl/pub/release-107/variation/indexed_vep_cache/homo_sapiens_vep_107_GRCh38.tar.gz $HOME/ref/
tar -zvxf $HOME/ref/homo_sapiens_vep_107_GRCh38.tar.gz -C $HOME/.vep/

# Download reference genome FASTA file
mkdir -p $HOME/ref/fasta/
aws --no-sign-request s3 sync s3://sage-igenomes/igenomes/Homo_sapiens/GATK/GRCh38/Sequence/WholeGenomeFasta/ $HOME/ref/fasta/

# Stage reference files in memory
mkdir -p /dev/shm/vep/ /dev/shm/fasta/
sudo mount -o remount,size=25G /dev/shm  # Increase /dev/shm size
rsync -avhP $HOME/.vep/ /dev/shm/vep/
rsync -avhP $HOME/ref/fasta/ /dev/shm/fasta/
```

### Preparing the Ensembl VEP cache

#### Outside of Nextflow

To determine the most efficient way to prepare the VEP cache for vcf2maf, several permutations of downloading the tarball or extracted folder from Ensembl or S3 were compared:

- **Download tarball using rsync from Ensembl:** 10 min 23 sec
- **Download tarball using AWS CLI from S3:** 3 min 14 sec
- **Extract tarball using `tar` locally:** 6 min 11 sec
- **Download extracted folder using AWS CLI from S3:** 4 min 5 sec

Based on these results, the estimated end-to-end runtimes are:

- **Download tarball from Ensembl and extract locally:** 16 min 34 sec
- **Download tarball from S3 and extract locally:** 9 min 25 sec
- **Download extracted folder from S3:** 4 min 5 sec

Downloading the pre-extracted folder from S3 is the fastest option, followed by downloading the tarball from S3 and extracting locally.

#### Within Nextflow

After benchmarking cache download methods outside of Nextflow, various tests were run inside a Nextflow pipeline. SHM refers to shared memory (`/dev/shm`).

- **Baseline (all reference files in SHM):** 3 min 43 sec
- **FASTA in S3, VEP folder in SHM:** 4 min 9 sec
- **FASTA in S3, VEP folder in non-SHM:** 3 min 43 sec
- **FASTA in S3, VEP folder in S3:** Over 17 min 7 sec[^1]
- **FASTA in S3, VEP tarball in non-SHM:** 8 min 39 sec
- **FASTA and VEP tarball in S3:** 8 min 38 sec

Downloading the tarball from S3 is the most efficient portable method. While roughly 10 minutes is nontrivial, it is small relative to per-sample vcf2maf runtimes of 4 to 5 hours. The tarball approach also works without modification on Nextflow Tower.

[^1]: This method was expected to be the most efficient for downloading the VEP cache, but the job had to be killed because it was taking too long. The AWS Java SDK appears considerably less efficient than the AWS CLI for recursive S3 folder downloads.
