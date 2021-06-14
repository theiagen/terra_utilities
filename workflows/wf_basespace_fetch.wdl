version 1.0

workflow basespace_fetch {

  input {
    String    samplename
    String    dataset_name
    String    basespace_run_name
    String    api_server
    String    access_token
  }

  call fetch_bs {
    input:
      samplename=samplename,
      dataset_name=dataset_name,
      basespace_run_name=basespace_run_name,
      api_server=api_server,
      access_token=access_token
  }

  output {
    File    read1   =fetch_bs.read1
    File    read2   =fetch_bs.read2
  }
}

task fetch_bs {

  input {
    String    samplename
    String    dataset_name
    String    basespace_run_name
    String    api_server
    String    access_token
    Int       mem_size_gb=8
    Int       CPUs = 2
    Int       Preemptible = 1
  }

  command <<<
    #Set BaseSpace comand prefix
    bs_command="bs --api-server=~{api_server} --access-token=~{access_token}"
  
    #Grab BaseSpace Run_ID from given BaseSpace Run Name
    run_id=$(${bs_command} list run | grep “~{basespace_run_name}" | awk -F "|" '{ print $3 }' )

    #Grab BaseSpace Dataset ID from dataset lists within given run 
    dataset_id=$(${bs_command} list dataset —input-run=${run_id} | grep “~{dataset_name}” | awk -F "|" '{ print $3 }' ) 

    #Download reads by dataset ID
    ${bs_command} download dataset ${dataset_id} -o . --retry
    
    #Remove cruft from filename
    mv *_R1_* ~{samplename}_R1.fastq.gz
    mv *_R2_* ~{samplename}_R2.fastq.gz

  >>>

  output {
    File    read1="${samplename}_R1.fastq.gz"
    File    read2="${samplename}_R2.fastq.gz"
  }

  runtime {
    docker:       "theiagen/basespace_cli:1.2.1"
    memory:       "~{mem_size_gb} GB"
    cpu:          CPUs
    disks:        "local-disk 100 SSD"
    preemptible:  Preemptible
  }
}
