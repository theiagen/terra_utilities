version 1.0

import "../tasks/task_file_handling.wdl" as file_handling

workflow import_se_read_files {
	input {
		File	read1
	}

	call file_handling.cp_reads_to_workspace_se {
    input:
      read1 = read1
	}

output {
    File  imported_read1       = cp_reads_to_workspace_se.cp_read1
}
}
