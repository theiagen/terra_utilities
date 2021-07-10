version 1.0

import "../tasks/task_file_handling.wdl" as file_handling
import "../tasks/task_versioning.wdl" as versioning

workflow bam_to_fastq_se {
  input {
    File    bam_file
    String  samplename
    }
  call file_handling.fastq_from_bam_se {
    input:
      bam_file    = bam_file,
      samplename  = samplename
    }
  call versioning.version_capture{
    input:
  }
  output {
    String  bam_to_fastq_se_version        = version_capture.terra_utilities_version
    String  bam_to_fastq_se_analysis_date  = version_capture.date
    
		File    reads  = fastq_from_bam_se.read1
  }
}
