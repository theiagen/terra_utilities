version 1.0


task fastq_from_bam_pe {

  input {
    File	bam_file
    String samplename
    String? docker_image = "staphb/samtools:1.12"

  }
  command <<<
    samtools fastq -f2 -F4 -1 ~{samplename}_R1.fastq.gz -2 ~{samplename}_R2.fastq.gz -s singletons.fastq.gz

>>>
  output {
    File  read1 = "~{samplename}_R1.fastq.gz"
    File  read2 = "~{samplename}_R2.fastq.gz"
  }

  runtime {
      docker:       "~{docker_image}"
      memory:       "4 GB"
      cpu:          4
      disks:        "local-disk 100 SSD"
      preemptible:  0
  }
}
task fastq_from_bam_se {

  input {
    File	bam_file
    String samplename
    String? docker_image = "staphb/samtools:1.12"

  }
  command <<<
    samtools fastq -f2 -F4 -1 ~{samplename}_R1.fastq.gz -s singletons.fastq.gz

>>>
  output {
    File    read1   = "~{samplename}_R1.fastq.gz"
  }

  runtime {
      docker:       "~{docker_image}"
      memory:       "4 GB"
      cpu:          4
      disks:        "local-disk 100 SSD"
      preemptible:  0
  }
}
task cp_reads_to_workspace_se {

  input {
    File	read1
    String? docker_image = "theiagen/utility:1.1"

  }
  String r1_basename  = basename(read1)
  command <<<
    cp ~{read1} ~{r1_basename}

>>>
  output {
    File    cp_read1   = "~{r1_basename}"
  }

  runtime {
      docker:       "~{docker_image}"
      memory:       "4 GB"
      cpu:          4
      disks:        "local-disk 100 SSD"
      preemptible:  0
  }
}
task cp_reads_to_workspace_pe {

  input {
    File	read1
    File	read2
    String? docker_image = "theiagen/utility:1.1"

  }
  String r1_basename  = basename(read1)
  String r2_basename  = basename(read2)
  command <<<
    cp ~{read1} ~{r1_basename}
    cp ~{read2} ~(r2_basename)

>>>
  output {
    File    cp_read1   = "~{r1_basename}"
    File    cp_read2   = "~{r2_basename}"
  }

  runtime {
      docker:       "~{docker_image}"
      memory:       "4 GB"
      cpu:          4
      disks:        "local-disk 100 SSD"
      preemptible:  0
  }
}
task cat_files {

  input {
    Array[File] files_to_cat
    String concatenated_file_name
    String? docker_image = "theiagen/utility:1.1"

  }

  command <<<

  file_array=(~{sep=' ' files_to_cat})

  touch ~{concatenated_file_name}

  # cat files one by one and store them in the concatenated_files file
  for index in ${!file_array[@]}; do
    file=${file_array[$index]}
    cat ${file} >> ~{concatenated_file_name}
  done
>>>
  output {
    File    concatenated_files   = "~{concatenated_file_name}"
  }

  runtime {
      docker:       "~{docker_image}"
      memory:       "8 GB"
      cpu:          4
      disks:        "local-disk 100 SSD"
      preemptible:  0
  }
}
task zip_files {

  input {
    Array[File] files_to_zip
    String zipped_file_name
    String? docker_image = "theiagen/utility:1.1"

  }

  command <<<

  file_array=(~{sep=' ' files_to_zip})

  mkdir ~{zipped_file_name}

  # cat files one by one and store them in the concatenated_files file
  for index in ${!file_array[@]}; do
    file=${file_array[$index]}
    mv ${file} ~{zipped_file_name}
  done
  zip -r ~{zipped_file_name}.zip ~{zipped_file_name}
>>>
  output {
    File    zipped_files   = "~{zipped_file_name}.zip"
  }

  runtime {
      docker:       "~{docker_image}"
      memory:       "8 GB"
      cpu:          4
      disks:        "local-disk 100 SSD"
      preemptible:  0
  }
}
