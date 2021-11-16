version 1.0

import "../tasks/task_file_handling.wdl" as file_handling
import "../tasks/task_versioning.wdl" as versioning

workflow transfer_column_content {
  input {
    Array[String] files_to_transfer
    String target_bucket
  }
  call file_handling.transfer_files{
    input:
      files_to_transfer=files_to_transfer,
      target_bucket=target_bucket
    }
  call versioning.version_capture{
    input:
  }
  output {
    String transfer_column_content_version = version_capture.terra_utilities_version
    String transfer_column_content_analysis_date = version_capture.date

    File bucket_files = transfer_files.bucket_files
  }
}
