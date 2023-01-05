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
    String target_bucket
    Int CPUs = 4
    Int mem_size_gb = 8
    String? docker_image = "quay.io/theiagen/utility:1.1"
  }
  command <<<
    file_path_array="~{sep=' ' files_to_transfer}"

    gsutil -m cp -n ${file_path_array[@]} ~{target_bucket}
    
    echo "transferred_files" > transferred_files.tsv
    gsutil ls ~{target_bucket} >> transferred_files.tsv        

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
  task concatenate_illumina {
    input {
      String samplename
      File read1_lane1
      File? read2_lane1
      File read1_lane2
      File? read2_lane2
      File? read1_lane3
      File? read2_lane3
      File? read1_lane4
      File? read2_lane4
      String docker = "quay.io/theiagen/utilities:latest"
    }
    meta {
      # so that this always runs from the start and never uses cache
      volatile: true
      description: "Concatenates FASTQs for samples sequenced on an ILMN machine with multiple lanes (NextSeq, HiSeq, NovaSeq). Requires filenames to have standard ILMN file endings like: _L001_R1_001.fastq.gz"
    }
  command <<<
    # exit task if anything throws an error (important for proper gzip format)
    set -e

    # move reads into single directory
    mkdir -v reads
    mv -v ~{read1_lane1} \
          ~{read2_lane1} \
          ~{read1_lane2} \
          ~{read2_lane2} \
          ~{read1_lane3} \
          ~{read2_lane3} \
          ~{read1_lane4} \
          ~{read2_lane4} \
      reads/

    # check for valid gzipped format (this task assumes FASTQ files are gzipped - they should be coming from ILMN instruments)
    gzip -t reads/*.gz

    # ADD CHECKS HERE? EQUAL NUMBERS OF READS? ANYTHING ELSE?

    # run concatenate script and send STDOUT/ERR to STDOUT
    # reminder: script will skip over samples that only have R1 file present
    # reminder: script REQUIRES standard illumina file endings like: _L001_R1_001.fastq.gz and _L002_R2_001.fastq.gz
    # see script here: https://github.com/theiagen/utilities/blob/main/scripts/concatenate-across-lanes.sh
    concatenate-across-lanes.sh reads/

    # ensure newly merged FASTQs are valid gzipped format
    gzip -t reads/*merged*.gz

    # determine output filenames for outputs
    mv -v reads/*_merged_R1.fastq.gz reads/~{samplename}_merged_R1.fastq.gz
    mv -v reads/*_merged_R2.fastq.gz reads/~{samplename}_merged_R2.fastq.gz

>>>
  output {
    File read1_concatenated = "reads/~{samplename}_merged_R1.fastq.gz"
    File? read2_concatenated = "reads/~{samplename}_merged_R2.fastq.gz"
  }
  runtime {
      docker: "~{docker}"
      memory: "4 GB"
      cpu: 2
      disks: "local-disk 50 SSD"
      preemptible: 0
  }
}