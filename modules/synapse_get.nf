// Process for downloading files from Synapse
process SYNAPSE_GET {

  tag "${meta.synapse_id}"

  label 'synapse_python_client'

  secret "SYNAPSE_AUTH_TOKEN"

  input:
  tuple val(meta), val(synapse_id)

  output:
  tuple val(meta), path('*')

  script:
  """
  synapse get ${synapse_id}

  shopt -s nullglob
  for f in *\\ *; do mv "\${f}" "\${f// /_}"; done
  """

  stub:
  """
  touch stub.vcf
  """

}
