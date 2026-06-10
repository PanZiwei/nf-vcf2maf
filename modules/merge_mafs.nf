// Process for merging study MAF files
process MERGE_MAFS {

  tag "${meta.study_id}-${meta.variant_class}-${meta.variant_caller}"

  label 'maf_utils'
  label 'maf_utils_compute'

  errorStrategy 'retry'
  maxRetries 3

  input:
  tuple val(meta), path(input_mafs)

  output:
  tuple val(meta), path("*.merged.maf")

  script:
  prefix = "${meta.study_id}-${meta.variant_class}-${meta.variant_caller}"
  """
  merge_mafs.py -i '${input_mafs.join(',')}' -o '${prefix}.merged.maf'
  """

  stub:
  prefix = "${meta.study_id}-${meta.variant_class}-${meta.variant_caller}"
  """
  touch '${prefix}.merged.maf'
  """

}
