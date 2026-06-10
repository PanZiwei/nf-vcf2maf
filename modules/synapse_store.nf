// Process for uploading files to Synapse
process SYNAPSE_STORE {

  tag "${parent_id}/${input.name}"

  label 'synapse'

  secret "SYNAPSE_AUTH_TOKEN"

  input:
  tuple path(input), val(parent_id)

  script:
  """
  synapse store --parentId ${parent_id} ${input}
  """

  stub:
  """
  echo "stub: skipping synapse store"
  """

}
