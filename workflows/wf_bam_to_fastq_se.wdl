version 1.0

import "../tasks/task_file_handling.wdl" as file_handling

workflow bam_to_fastq_se {
	input {
		File	bam_file
		String	samplename
	}

	call file_handling.fastq_from_bam_se {
    input:
      bam_file	=	bam_file,
			samplename	=	samplename
	}

output {
    File  read1       = fastq_from_bam_se.read1
}
}
