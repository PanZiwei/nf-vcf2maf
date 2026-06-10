#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include { SAMPLE_MAFS } from './workflows/sample_mafs'
include { STUDY_MAFS  } from './workflows/study_mafs'


// Entrypoint workflow
workflow {

  // Parse input CSV sample sheet
  input_vcfs_ch = Channel
    .fromPath ( params.input )
    .splitCsv ( header:true, strip:true )
    .map { create_vcf_channel(it) }

  // Process individual sample VCF files
  SAMPLE_MAFS(input_vcfs_ch)

  // Filter and merge MAF files by study
  STUDY_MAFS(SAMPLE_MAFS.out)

}


// Function to get list of [ meta, vcf ]
def create_vcf_channel(LinkedHashMap row) {

  def meta = [:]
  meta.synapse_id       = row.synapse_id
  meta.biospecimen_id   = row.biospecimen_id
  meta.sample_parent_id = row.sample_parent_id
  meta.merged_parent_id = row.merged_parent_id
  meta.study_id         = row.study_id
  meta.variant_class    = row.variant_class
  meta.variant_caller   = row.variant_caller
  meta.is_releasable    = row.is_releasable.toBoolean()

  return [meta, row.synapse_id]
}
