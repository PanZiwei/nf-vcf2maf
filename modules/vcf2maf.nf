// Process for annotating VCF file and converting to MAF
process VCF2MAF {

  tag "${meta.synapse_id}"

  container "sagebionetworks/vcf2maf:107.2"

  cpus   6
  memory { 64.GB * task.attempt }

  errorStrategy = 'retry'
  maxRetries 3

  afterScript "rm -f intermediate*"

  input:
  tuple val(meta), path(input_vcf)
  tuple path(reference_fasta), path(reference_fasta_fai)
  path vep_data

  output:
  tuple val(meta), path("*.maf")

  // TODO: Remove hard-coded VEP path
  // TODO: Handle VCF genotype columns per variant caller
  script:
  vep_path  = "/root/miniconda3/envs/vep/bin"
  vep_forks = task.cpus - 2
  basename  = input_vcf.name.replaceAll(/.gz$/, "").replaceAll(/.vcf$/, "")

  // Add vcf_tumor_id and vcf_normal_id for somatic Strelka samples
  strelka_params = ""
  if (meta.variant_class == "somatic" && meta.variant_caller.toLowerCase() == "strelka") {
    strelka_params = "--vcf-tumor-id TUMOR --vcf-normal-id NORMAL"
  }

  // Add VEP stats parameter to pass --vep-stats to vcf2maf so it does not append --no_stats internally.
  // By default, vcf2maf.pl appends --no_stats to the VEP command unless --vep-stats is provided.
  // vcf2maf.pl script (dockerhub sagebionetworks/vcf2maf:107.2 container line 461)
  // $vep_cmd .= " --no_stats" unless( $vep_stats );
  // Default --no_stats behavior causes a known Ensembl VEP issue fail with
  // "substr outside of string" in TranscriptVariationAllele.pm.
  // The Ensembl VEP team currently recommends avoiding --no_stats as a short-term workaround.
  // Set params.vep_stats_params = false to suppress --vep-stats.
  vep_stats_params = params.vep_stats_params ? "--vep-stats" : ""

  """
  if [[ ${input_vcf} == *.gz ]]; then
    zcat ${input_vcf} > intermediate.vcf
  else
    cat  ${input_vcf} > intermediate.vcf
  fi

  vcf2maf.pl \
    --input-vcf intermediate.vcf --output-maf intermediate.maf.raw \
    --ref-fasta ${reference_fasta} --vep-data ${vep_data}/ \
    --ncbi-build ${params.ncbi_build} --max-subpop-af ${params.max_subpop_af} \
    --vep-path ${vep_path} --maf-center ${params.maf_center} \
    --tumor-id '${meta.biospecimen_id}' --vep-forks ${vep_forks} \
    --species ${params.species} ${strelka_params} ${vep_stats_params}

  grep -v '^#' intermediate.maf.raw > '${basename}.maf'
  """

}
