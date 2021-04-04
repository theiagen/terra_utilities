version 1.0

task cat_files {

  input {
    Array[File] files_to_cat
    String? docker_image = "theiagen/utility:1.1"

  }

  command <<<

  file_array=(~{sep=' ' files_to_cat})

  touch concatenated_files

  # cat files one by one and store them in the concatenated_files file
  for index in ${!file_array[@]}; do
    file=${file_array[$index]}
    cat ${file} >> concatenated_files
  done
>>>
  output {
    File    concatenated_files   = "concatenated_files"
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
