version 1.0

import "../tasks/task_file_handling.wdl" as file_handling
import "../tasks/task_versioning.wdl" as versioning

workflow import_pe_read_files {
	input {
		File	read1
		File	read2
	}
	call file_handling.cp_reads_to_workspace_pe {
    input:
      read1 = read1,
			read2 = read2
	}
	call versioning.version_capture{
    input:
  }
  output {
    String  import_pe_version        = version_capture.terra_utilities_version
    String  import_pe_analysis_date  = version_capture.date

    File    imported_read1  = cp_reads_to_workspace_pe.cp_read1
		File    imported_read2  = cp_reads_to_workspace_pe.cp_read2
}
}
