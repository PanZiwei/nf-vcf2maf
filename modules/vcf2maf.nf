// Process for annotating VCF file and converting to MAF
process VCF2MAF {

  tag "${meta.synapse_id}"

  container "sagebionetworks/vcf2maf:107.2"

  cpus   { Math.min(6, params.max_cpus as int) }
  memory { [64.GB * task.attempt, params.max_memory as nextflow.util.MemoryUnit].min() }

  errorStrategy 'retry'
  maxRetries 3

  afterScript "rm -f intermediate*"

  input:
  tuple val(meta), path(input_vcf)
  tuple path(reference_fasta), path(reference_fasta_fai)
  path vep_data

  output:
  tuple val(meta), path("*.maf")

  // TODO: Handle VCF genotype columns per variant caller
  script:
  vep_path  = "/root/miniconda3/envs/vep/bin"
  vep_forks = task.cpus - 2
  basename  = input_vcf.name.replaceAll(/.gz$/, "").replaceAll(/.vcf$/, "")

  strelka_params = ""
  if (meta.variant_class == "somatic" && meta.variant_caller.toLowerCase() == "strelka") {
    strelka_params = "--vcf-tumor-id TUMOR --vcf-normal-id NORMAL"
  }

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

  stub:
  basename = input_vcf.name.replaceAll(/.gz$/, "").replaceAll(/.vcf$/, "")
  """
  touch '${basename}.maf'
  """

}
