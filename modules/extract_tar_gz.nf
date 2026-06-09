// Process for decompressing and extracting the VEP cache tarball
process EXTRACT_TAR_GZ {

  container "sagebionetworks/vcf2maf:107.2"

  input:
  path vep_tarball

  output:
  path "vep_data"

  script:
  """
  mkdir -p vep_data/
  tar -zxf ${vep_tarball} -C vep_data/
  """

}
