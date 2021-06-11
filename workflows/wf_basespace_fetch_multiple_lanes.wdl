version 1.0

workflow basespace_fetch_multiple_lanes {

  input {
    String    sample_name
    String    dataset_name
    String    api_server
    String    access_token
  }

  call fetch_bs {
    input:
      sample=sample_name,
      dataset=dataset_name,
      api=api_server,
      token=access_token
  }

  output {

    File    read1   =fetch_bs.read1
    File    read2   =fetch_bs.read2
  }
}

task fetch_bs {

  input {
    String    sample
    String    dataset
    String    api
    String    token
    Int       mem_size_gb = 8
    Int       CPUs = 2
  }

  command <<<

    bs --api-server=~{api} --access-token=~{token} download dataset -n ~{dataset}_L001 -o .
    bs --api-server=~{api} --access-token=~{token} download dataset -n ~{dataset}_L002 -o .
    bs --api-server=~{api} --access-token=~{token} download dataset -n ~{dataset}_L003 -o .
    bs --api-server=~{api} --access-token=~{token} download dataset -n ~{dataset}_L004 -o .
    
    bs --api-server=~{api} --access-token=~{token} download dataset -n ~{dataset}_L1 -o .
    bs --api-server=~{api} --access-token=~{token} download dataset -n ~{dataset}_L2 -o .
    bs --api-server=~{api} --access-token=~{token} download dataset -n ~{dataset}_L3 -o .
    bs --api-server=~{api} --access-token=~{token} download dataset -n ~{dataset}_L4 -o .

    for file in `ls *_R1_*`; do cat $file >> ~{sample}_R1.fastq.gz; done
    for file in `ls *_R2_*`; do cat $file >> ~{sample}_R2.fastq.gz; done

  >>>

  output {

    File    read1="${sample}_R1.fastq.gz"
    File    read2="${sample}_R2.fastq.gz"
  }

  runtime {
    docker:       "theiagen/basespace_cli:1.2.1"
    memory:       "~{mem_size_gb} GB"
    cpu:          CPUs
    disks:        "local-disk 100 SSD"
    preemptible:  1
  }
}
