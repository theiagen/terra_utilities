version 1.0

import "../tasks/task_versioning.wdl" as versioning

workflow basespace_fetch {
  input {
    String  samplename
    String  dataset_name
    String  basespace_run_name
    String  api_server
    String  access_token
  }
  call fetch_bs {
    input:
      samplename          = samplename,
      dataset_name        = dataset_name,
      basespace_run_name  = basespace_run_name,
      api_server          = api_server,
      access_token        = access_token
  }
  call versioning.version_capture{
    input:
  }
  output {
    String  basespace_fetch_version        = version_capture.terra_utilities_version
    String  basespace_fetch_analysis_date  = version_capture.date
    
    File    read1  = fetch_bs.read1
    File    read2  = fetch_bs.read2
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
    echo "BS command: ${bs_command}"
  
    #Grab BaseSpace Run_ID from given BaseSpace Run Name
    run_id=$(${bs_command} list run | grep "~{basespace_run_name}" | awk -F "|" '{ print $3 }' | awk '{$1=$1;print}' )
    echo "run_id: ${run_id}"

    #Grab BaseSpace Dataset ID from dataset lists within given run 
    dataset_id_array=($(${bs_command} list dataset --input-run=${run_id} | grep "~{dataset_name}" | awk -F "|" '{ print $3 }' )) 
    echo "dataset_id: ${dataset_id_array[*]}"
    echo "${#dataset_id_array[@]}" | tee NUMBER_LANES
    
    #Download reads by dataset ID
    for index in ${!dataset_id_array[@]}; do
      dataset_id=${dataset_id_array[$index]}
      mkdir ./dataset_${dataset_id} && cd ./dataset_${dataset_id}
      echo "PWD: $(pwd)"
      echo "for loop command (dataset download): ${bs_command} download dataset -i ${dataset_id} -o . --retry"
      ${bs_command} download dataset -i ${dataset_id} -o . --retry && cd ..
      echo "dataset dirs: $(ls ./dataset_*/*)"
    done
    
    #Combine non-empty read files into single file without BaseSpace filename cruft
    ##FWD Read
    for fwd_read in ./dataset_*/*_R1_*.fastq.gz; do
      if [[ -s $fwd_read ]]; then
        echo "for loop command (cat reads): cat $fwd_read >> ~{samplename}_R1.fastq.gz" 
        cat $fwd_read >> ~{samplename}_R1.fastq.gz
      fi
    done
    ##REV Read
    for rev_read in ./dataset_*/*_R2_*.fastq.gz; do
      if [[ -s $rev_read ]]; then 
        echo "for loop command (cat reads): cat $rev_read >> ~{samplename}_R2.fastq.gz" 
        cat $rev_read >> ~{samplename}_R2.fastq.gz
      fi
    done
  >>>
  output {
    File    read1        = "${samplename}_R1.fastq.gz"
    File    read2        = "${samplename}_R2.fastq.gz"
    Int     number_lanes = read_int("NUMBER_LANES")
  }
  runtime {
    docker:       "theiagen/basespace_cli:1.2.1"
    memory:       "~{mem_size_gb} GB"
    cpu:          CPUs
    disks:        "local-disk 100 SSD"
    preemptible:  Preemptible
  }
}
