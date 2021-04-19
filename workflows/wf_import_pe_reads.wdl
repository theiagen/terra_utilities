
version 1.0

import "../tasks/task_file_handling.wdl" as file_handling

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

output {
    File  imported_read1       = cp_reads_to_workspace_pe.cp_read1
		File  imported_read2       = cp_reads_to_workspace_pe.cp_read2
}
}
