version 1.0

task cat_files {

  input {
    Array[File] files_to_cat
    String? docker_image = "theiagen/utility:1.0"

  }

  command <<<

  file_array=(~{sep=' ' files_to_cat})

  touch concatonated_files

  # cat files one by one and store them in the concatonated_files file
  for index in ${!file_array[@]}; do
    file=${file_array[$index]}
    cat ${file} >> concatonated_files
  done
>>>
  output {
    File    concatonated_files   = "concatonated_files"
  }

  runtime {
      docker:       "~{docker_image}"
      memory:       "8 GB"
      cpu:          4
      disks:        "local-disk 100 SSD"
      preemptible:  0
  }
}
