version 1.0

import "../tasks/task_file_handling.wdl" as file_handling

workflow concatenate_files {
	input {
		Array[File] files_to_cat
	}
	call file_handling.cat_files{
		input:
			files_to_cat=files_to_cat
	}
	output {
	    File      concatenated_files  = cat_files.concatenated_files
	}
}
