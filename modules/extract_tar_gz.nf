// Process for decompressing and extracting the VEP cache tarball
process EXTRACT_TAR_GZ {

  label 'vcf2maf'

  input:
  path vep_tarball

  output:
  path "vep_data"

  script:
  """
  mkdir -p vep_data/
  tar -zxf ${vep_tarball} -C vep_data/
  """

  stub:
  """
  mkdir -p vep_data
  """

}
