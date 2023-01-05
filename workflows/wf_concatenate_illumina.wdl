version 1.0

import "../tasks/task_file_handling.wdl" as file_handling
import "../tasks/task_versioning.wdl" as versioning

workflow concatenate_illumina_fastqs {
  input {
    String samplename
    File read1_lane1
    File? read2_lane1
    File read1_lane2
    File? read2_lane2
    File? read1_lane3
    File? read2_lane3
    File? read1_lane4
    File? read2_lane4
  }
  call file_handling.concatenate_illumina {
    input:
      samplename = samplename,
      read1_lane1 = read1_lane1,
      read2_lane1 = read2_lane1,
      read1_lane2 = read1_lane2,
      read2_lane2 = read2_lane2,
      read1_lane3 = read1_lane3,
      read2_lane3 = read2_lane3,
      read1_lane4 = read1_lane4,
      read2_lane4 = read2_lane4
  }
  call versioning.version_capture{
    input:
  }
  output {
    # version capture task outputs
    String import_pe_version = version_capture.terra_utilities_version
    String import_pe_analysis_date = version_capture.date
    # concatenate_illumina task outputs
    File read1_concatenated = concatenate_illumina.read1_concatenated
    File? read2_concatenated = concatenate_illumina.read2_concatenated
  }
}