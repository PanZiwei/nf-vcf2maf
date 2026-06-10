// Process for filtering MAF files for passed variants
process FILTER_MAF {

  tag "${meta.synapse_id}"

  label 'python'

  input:
  tuple val(meta), path(input_maf)

  output:
  tuple val(meta), path("*.passed.maf")

  script:
  """
  filter_maf.py ${input_maf} '${input_maf.baseName}.passed.maf'
  """

  stub:
  """
  touch '${input_maf.baseName}.passed.maf'
  """

}
