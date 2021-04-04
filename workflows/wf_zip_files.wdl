version 1.0

import "../tasks/task_file_handling.wdl" as file_handling

workflow mercury_batch {
	input {
		Array[File] files_to_cat

	}

	call file_handling.zip_files{
		input:
			files_to_cat=files_to_cat
	}

	output {
	    File      zipped_files  = zip_files.zipped_files

	}
}
