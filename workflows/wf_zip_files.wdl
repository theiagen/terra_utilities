version 1.0

import "../tasks/task_file_handling.wdl" as file_handling

workflow zip_column_content {
	input {
		Array[File] files_to_zip
	}
	call file_handling.zip_files{
		input:
			files_to_zip=files_to_zip
	}
	output {
	    File      zipped_files  = zip_files.zipped_files
	}
}
