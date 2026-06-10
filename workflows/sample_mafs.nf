include { SYNAPSE_GET    } from '../modules/synapse_get'
include { EXTRACT_TAR_GZ } from '../modules/extract_tar_gz'
include { VCF2MAF        } from '../modules/vcf2maf'
include { SYNAPSE_STORE  } from '../modules/synapse_store'


// Workflow for generating sample-level MAF files
workflow SAMPLE_MAFS {

  take:
    sample_vcfs

  main:
    // Pair up FASTA and FAI reference files
    ref_fasta_pair = [params.reference_fasta, params.reference_fasta_fai]

    // Download VCF files from Synapse
    SYNAPSE_GET(sample_vcfs)

    // Decompress and extract VEP cache tarball
    EXTRACT_TAR_GZ(params.vep_tarball)

    // Run vcf2maf on each vcf file
    VCF2MAF(SYNAPSE_GET.out, ref_fasta_pair, EXTRACT_TAR_GZ.out)

    // Upload MAF files to Synapse
    sample_mafs_ch = VCF2MAF.out
      .map { meta, maf -> [ maf, meta.sample_parent_id ] }
    SYNAPSE_STORE(sample_mafs_ch)

  emit:
    VCF2MAF.out

}
