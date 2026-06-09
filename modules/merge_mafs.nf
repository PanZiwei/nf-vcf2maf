// Process for merging study MAF files
process MERGE_MAFS {

  tag "${meta.study_id}-${meta.variant_class}-${meta.variant_caller}"

  container "python:3.10.4"

  memory { 16.GB * task.attempt }

  errorStrategy = 'retry'
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

}
