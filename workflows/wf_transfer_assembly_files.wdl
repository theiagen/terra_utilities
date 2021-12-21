version 1.0

import "../tasks/task_file_handling.wdl" as file_handling
import "../tasks/task_versioning.wdl" as versioning
import "../tasks/task_fapi.wdl" as fapi

workflow transfer_assembly_files {
  input {
    Array[String] assemblies
    Array[String] samplenames
    Array[Float] percent_reference_coverage
    Boolean import_terra_table = false
    String target_terra_project = "NA"
    String target_workspace_name = "NA"
    String target_bucket
    String target_root_entity
    String transferred_file_column_header

  }
  call filter_assemblies{
    input:
      assemblies = assemblies,
      samplenames = samplenames,
      percent_reference_coverage = percent_reference_coverage
  }
  call file_handling.transfer_files{
    input:
      files_to_transfer = filter_assemblies.assemblies_filterred,
      samplenames = filter_assemblies.samplenames_filterred,
      target_bucket = target_bucket,
      target_root_entity = target_root_entity,
      transferred_file_column_header = transferred_file_column_header,
      create_terra_table = true
    }
  if(import_terra_table){
    call fapi.import_terra_table as import_table {
      input:
        terra_project = target_terra_project,
        workspace_name = target_workspace_name,
        terra_table = transfer_files.transferred_files
    }
  }
  call versioning.version_capture{
    input:
  }
  output {
    String transfer_assembies_version = version_capture.terra_utilities_version
    String transfer_assemblies_analysis_date = version_capture.date

    File assembly_data_table = transfer_files.transferred_files
  }
}

task filter_assemblies {
  input {
    Array[String] assemblies
    Array[Float] percent_reference_coverage
    Int percent_reference_coverage_threshold = 90
    Array[String] samplenames
    String? docker_image = "quay.io/theiagen/utility:1.1"
  }
  command <<<
    assembly_array=(~{sep=' ' assemblies})
    assembly_array_len=$(echo "${#assembly_array[@]}")
    reference_coverage_array=(~{sep=' ' percent_reference_coverage})
    referece_coverage_array_len=$(echo "${#reference_coverage_array[@]}")
    samplename_array=(~{sep=' ' samplenames})
    samplename_array_len=$(echo "${#samplename_array[@]}")
    mkdir ./passed_assemblies
    passed_assemblies=""
    passed_samplenames=""
    
    #Create files to capture batched and excluded samples
    echo -e "Samplename\tPercent reference coverage" > assemblies_included.tsv
    echo -e "Samplename\tPercent reference coverage" > assemblies_filterred.tsv

    #Ensure assembly, meta, and vadr arrays are of equal length
    echo "Samples: $samplename_array_len, Assemblies: $assembly_array_len, percent_reference_coverages: $referece_coverage_array_len"
    if [ "$samplename_array_len" -ne "$referece_coverage_array_len" ] && [ "$samplename_array_len" -ne "$assembly_array_len" ]; then
      echo "Input arrays are of unequal length. Samples: $samplename_array_len, Assemblies: $assembly_array_len, percent_reference_coverages: $referece_coverage_array_len" >&2
      exit 1
    else 
      echo "Input arrays are of equal length. Samples: $samplename_array_len, Assemblies: $assembly_array_len, percent_reference_coverages: $referece_coverage_array_len"
    fi

    echo "name array: ${samplename_array[@]}"
    echo "reference_coverage array: ${reference_coverage_array[@]}"
    
    #remove samples that do not meet coverage threshold 
    for index in  ${!samplename_array[@]}; do
      samplename=${samplename_array[$index]}
      assembly=${assembly_array[$index]}
      reference_coverage=${reference_coverage_array[$index]}
      reference_coverage=${reference_coverage%.*}

      if [ "${reference_coverage}" -ge "~{percent_reference_coverage_threshold}" ] ; then
        passed_assemblies=( "${passed_assemblies[@]}" "${assembly}")
        passed_samplenames=( "${passed_samplenames[@]}" "${samplename}")
        echo -e "\t$samplename coverage (${reference_coverage}) passes threshold (~{percent_reference_coverage_threshold})"
        echo -e "$samplename\t$reference_coverage" >> assemblies_included.tsv
      else
        echo -e "\t$samplename coverage (${reference_coverage}) does not meet coverage threshold (~{percent_reference_coverage_threshold})"
        echo -e "$samplename\t$reference_coverage" >> assemblies_filterred.tsv
      fi
    done

    passed_assemblies_len=$(echo "${#passed_assemblies[@]}")
    passed_samplenames_len=$(echo "${#passed_samplenames[@]}")
    # sanity check before completing task
    if  [ "$passed_assemblies_len" -ne "$passed_samplenames_len" ] ; then 
      echo "OUTPUT arrays are of unequal length. samplenames:$passed_samplenames_len; assemblies: $passed_assemblies_len" >&2
      exit 1
    elif [ "${passed_assemblies_len}" == 1 ] ; then 
      echo "No assemblies passed coverage threshold" >&2
      exit 1
    else 
      echo "OUTPUT arrays are of equal length. samplenames:$passed_samplenames_len; assemblies: $passed_assemblies_len"
    fi

    printf '%s\n' "${passed_assemblies[@]}" > PASSED_ASSEMBLIES
    printf  '%s\n' "${passed_samplenames[@]}" > PASSED_SAMPLENAMES

>>>
  output {
    Array[String] assemblies_filterred = read_lines("PASSED_ASSEMBLIES")
    Array[String] samplenames_filterred = read_lines("PASSED_SAMPLENAMES")
  }
  runtime {
      docker: "~{docker_image}"
      memory: "1 GB"
      cpu: 1
      disks: "local-disk 10 HDD"
      preemptible: 0
  }
}

