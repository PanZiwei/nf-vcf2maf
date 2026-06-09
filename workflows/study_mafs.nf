include { FILTER_MAF    } from '../modules/filter_maf'
include { MERGE_MAFS    } from '../modules/merge_mafs'
include { SYNAPSE_STORE } from '../modules/synapse_store'


// Workflow for generating study-level MAF files
workflow STUDY_MAFS {

  take:
    sample_mafs

  main:
    // Only consider releasable MAF files
    releasable_mafs = sample_mafs
      .filter { meta, maf -> meta.is_releasable }

    // Filter MAF files for passed variants
    FILTER_MAF(releasable_mafs)

    // Group MAF files by study and merge
    mafs_by_study_ch = FILTER_MAF.out
      .map { meta, maf -> subset_study_meta(meta, maf) }
      .groupTuple( by: 0 )
    MERGE_MAFS(mafs_by_study_ch)

    // Upload study MAF files to Synapse
    merged_mafs_ch = MERGE_MAFS.out
      .map { meta, maf -> [ maf, meta.merged_parent_id ] }
    SYNAPSE_STORE(merged_mafs_ch)

}


// Function to get list of [ study_meta, maf ]
def subset_study_meta(vcf_meta, maf) {

  def study_meta = [:]
  study_meta.merged_parent_id = vcf_meta.merged_parent_id
  study_meta.study_id         = vcf_meta.study_id
  study_meta.variant_class    = vcf_meta.variant_class
  study_meta.variant_caller   = vcf_meta.variant_caller

  return [ study_meta, maf ]
}
