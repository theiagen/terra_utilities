version 1.0

workflow fetch_sra_to_fastq {
  input {
    String SRR
  }
  call fastq-dl-sra {
    input:
      sra_id=SRR
  }
  output {
    Fil read1 = fastq-dl-sra.read1
    File? read2 = fastq-dl-sra.read2
  }
}

task fastq-dl-sra {
  input {
    String sra_id
  }
  command <<<
    fastq-dl --version | tee VERSION
    fastq-dl ~{SRR}
  >>>
  output {
    File read1="${sra_id}_1.fastq.gz"
    File? ead2="${sra_id}_2.fastq.gz"
  }
  runtime {
    docker: "quay.io/biocontainers/fastq-dl:1.1.0--hdfd78af_0"
    memory:"8 GB"
    cpu: 2
    disks: "local-disk 100 SSD"
    preemptible:  1
  }
}

