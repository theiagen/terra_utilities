version 1.0


task fastq_from_bam_pe {
  input {
    File	bam_file
    String samplename
    String? samtools_fastq_options
    String? docker_image = "quay.io/staphb/samtools:1.12"
  }
  command <<<
    # ensure bam file is sorted
    samtools sort -n ~{bam_file} > sorted.bam
    #generate fastq files from bam; output singletons to separate file
    samtools fastq ~{samtools_fastq_options} -1 ~{samplename}_R1.fastq.gz -2 ~{samplename}_R2.fastq.gz ~{bam_file}
>>>
  output {
    File read1 = "~{samplename}_R1.fastq.gz"
    File read2 = "~{samplename}_R2.fastq.gz"
  }
  runtime {
    docker: "~{docker_image}"
    memory: "4 GB"
    cpu: 4
    disks: "local-disk 100 SSD"
    preemptible: 0
  }
}
task fastq_from_bam_se {
  input {
    File	bam_file
    String samplename
    String? samtools_fastq_options
    String? docker_image = "quay.io/staphb/samtools:1.12"
  }
  command <<<
    # ensure bam file is sorted
    samtools sort -n ~{bam_file} > sorted.bam
    #generate fastq files from bam; output singletons to separate file
    samtools fastq ~{samtools_fastq_options} -0 ~{samplename}_R1.fastq.gz sorted.bam
>>>
  output {
    File reads = "~{samplename}_R1.fastq.gz"
  }
  runtime {
    docker: "~{docker_image}"
    memory: "4 GB"
    cpu: 4
    disks: "local-disk 100 SSD"
    preemptible: 0
  }
}
task cp_reads_to_workspace_se {
  input {
    File reads
    String? docker_image = "quay.io/theiagen/utility:1.1"
  }
  String reads_basename  = basename(reads)
  command <<<
    cp ~{reads} ~{reads_basename}
>>>
  output {
    File cp_reads = "~{reads_basename}"
  }
  runtime {
      docker: "~{docker_image}"
      memory: "4 GB"
      cpu: 4
      disks: "local-disk 100 SSD"
      preemptible: 0
  }
}
task cp_reads_to_workspace_pe {
  input {
    File read1
    File read2
    String? docker_image = "quay.io/theiagen/utility:1.1"
  }
  String r1_basename = basename(read1)
  String r2_basename = basename(read2)
  command <<<
    cp ~{read1} ~{r1_basename}
    cp ~{read2} ~{r2_basename}
>>>
  output {
    File cp_read1 = "~{r1_basename}"
    File cp_read2 = "~{r2_basename}"
  }
  runtime {
    docker: "~{docker_image}"
    memory: "4 GB"
    cpu: 4
    disks: "local-disk 100 SSD"
    preemptible: 0
  }
}
task cat_files {
  input {
    Array[File] files_to_cat
    String concatenated_file_name
    String? docker_image = "quay.io/theiagen/utility:1.1"
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
    File concatenated_files = "~{concatenated_file_name}"
  }
  runtime {
    docker: "~{docker_image}"
    memory: "8 GB"
    cpu: 4
    disks: "local-disk 100 SSD"
    preemptible: 0
  }
}
task zip_files {
  input {
    Array[File] files_to_zip
    String zipped_file_name
    String? docker_image = "quay.io/theiagen/utility:1.1"
  }
  command <<<
    file_array=(~{sep=' ' files_to_zip})
    mkdir ~{zipped_file_name}

    # move files oto a single directory before zipping
    for index in ${!file_array[@]}; do
      file=${file_array[$index]}
      mv ${file} ~{zipped_file_name}
    done
    
    zip -r ~{zipped_file_name}.zip ~{zipped_file_name}
>>>
  output {
    File zipped_files = "~{zipped_file_name}.zip"
  }
  runtime {
      docker: "~{docker_image}"
      memory: "8 GB"
      cpu: 4
      disks: "local-disk 100 SSD"
      preemptible: 0
  }
}
task transfer_files {
  input {
    Array[String] files_to_transfer
    Array[String] samplenames
    String target_bucket
    String target_root_entity="transferred_files"
    String transferred_file_column_header="transferred_file"
    Int CPUs = 4
    Int mem_size_gb = 8
    String? docker_image = "quay.io/theiagen/utility:1.1"
  }
  command <<<
    file_path_array=(~{sep=' ' files_to_transfer})
    file_path_string_array="~{sep=' ' files_to_transfer}"
    samplename_array=(~{sep=' ' samplenames})
    echo -e "entity:~{target_root_entity}_id\t~{transferred_file_column_header}" > transferred_files.tsv
    
    #transfer files to target bucket
    echo "Running gsutil -m cp -n ${file_path_string_array[@]} ~{target_bucket}"
    gsutil -m cp -n ${file_path_string_array[@]} ~{target_bucket}
    
    #create datatable for transferred files
    for index in ${!file_path_array[@]}; do
      transferred_file=${file_path_array[$index]}
      transferred_file=$(echo ${transferred_file} | awk -F "/" '{print $NF}')
      samplename=${samplename_array[$index]}
      
      gcp_address="~{target_bucket}${transferred_file}"
      echo "GCP address: ${gcp_address}"
      
      if [ $(gsutil -q stat ${gcp_address}; echo $?) == 1 ]; then
        echo "${transferred_file} does not exist in ~{target_bucket}" >&2
      else
        echo "${transferred_file} found in ~{target_bucket}"
        echo -e "${samplename}\t${gcp_address}" >> transferred_files.tsv
      fi
    done
  
>>>
  output {
    File transferred_files = "transferred_files.tsv"
  }
  runtime {
      docker: "~{docker_image}"
      memory: "~{mem_size_gb} GB"
      cpu: CPUs
      disks: "local-disk 100 SSD"
      preemptible: 0
  }
}