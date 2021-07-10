version 1.0

import "../tasks/task_file_handling.wdl" as file_handling
import "../tasks/task_versioning.wdl" as versioning

workflow zip_column_content {
	input {
		Array[File] files_to_zip
	}
	call file_handling.zip_files{
		input:
			files_to_zip=files_to_zip
	}
	call versioning.version_capture{
    input:
  }
  output {
    String  bam_to_fastq_se_version        = version_capture.terra_utilities_version
    String  bam_to_fastq_se_analysis_date  = version_capture.date
		
	  File    zipped_files  = zip_files.zipped_files
	}
}
