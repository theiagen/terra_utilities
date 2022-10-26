version 1.0

workflow terra_2_bq {

    input {
      Array[String]  terra_projects
      Array[String]  workspace_names
      Array[String]  table_names
      Array[String]  table_ids
      Array[String]  gcs_uris
      Array[String]  output_filename_prefixs
    }

    call terra_to_bigquery {
      input:
        terra_projects=terra_projects,
        workspace_names=workspace_names,
        table_names=table_names,
        table_ids=table_ids,
        gcs_uri_prefixs=gcs_uris,
        output_filename_prefix=output_filename_prefixs
    }

}

task terra_to_bigquery {
  input {
    Array[String]  terra_projects
    Array[String]  workspace_names
    Array[String]  table_names
    Array[String]  table_ids
    Array[String]  gcs_uri_prefixs
    Array[String]?  output_filename_prefix
    String  docker = "broadinstitute/terra-tools:tqdm"
    Int page_size = 5000
    Int mem_size_gb = 32
    Int CPUs = 8
    Int disk_size = 100
    String sleep_time = "15m"
  }

  meta {
    volatile: true
  }
  command <<<
  set -e

  # set bash arrays
  terra_project_array=(~{sep=' ' terra_projects})
  terra_project_array_len=$(echo "${#terra_project_array[@]}")
  workspace_name_array=(~{sep=' ' workspace_names})
  workspace_name_array_len=$(echo "${#workspace_name_array[@]}")
  table_name_array=(~{sep=' ' table_names})
  table_name_array_len=$(echo "${#table_name_array[@]}")
  table_id_array=(~{sep=' ' table_ids})
  table_id__array_len=$(echo "${#table_id_array[@]}")
  gcs_uri_prefix_array=(~{sep=' ' gcs_uri_prefixs})
  gcs_uri_prefix_array_len=$(echo "${#gcs_uri_prefix_array[@]}")
  output_filename_prefix_array=(~{sep=' ' output_filename_prefix})
  output_filename_prefix_array_len=$(echo "${#output_filename_prefix[@]}")


  # Ensure equal length of all input arrays (excluding output filename prefix array for length check since it is optional)
  echo "Terra Projects array length: $terra_project_array_len, Workspace name array length: $workspace_name_array_len, Table Name array length: $table_name_array_len, Table ID array length: $table_id_array_len, GCS URI prefixes array length: $gcs_uri_prefix_array_len"
  if [ "$terra_project_array_len" -ne "$workspace_name_array_len" ] && [ "$terra_project_array_len" -ne "$table_name_array_len" ] && [ "$terra_project_array_len" -ne "$table_id_array_len" ] && [ "$terra_project_array_len" -ne "$gcs_uri_prefix_array" ]; then
    echo "Input arrays are of unequal length. Terra Projects array length: $terra_project_array_len, Workspace name array length: $workspace_name_array_len, Table Name array length: $table_name_array_len, Table ID array length: $table_id_array_len, GCS URI prefix array length: $gcs_uri_prefix_array_len" >&2
    exit 1
  else
    echo -e "Input arrays are of equal length. \nProceeding to transfer the following Terra Data Tables to their specified GCS URIs: ${gcs_uri_prefix_array[@]}\n${table_id_array[@]} \n\nTransfer will occur every ~{sleep_time} until this job is aborted.\n"
  fi

  # Infinite While loop
  counter=0
  echo -e "**ENTERING LOOP**"
  while true
  do

    # counter and sanity checks for troubleshooting
    counter=$((counter+1))
    date_tag=$(date +"%Y-%m-%d-%Hh-%Mm-%Ss")
    echo -e "\n========== Iteration number ${counter} of continuous loop =========="
    echo "TIME: ${date_tag}"

  # Loop through inputs and run python script to create tsv/json and push json to specified gcp bucket
    for index in "${!terra_project_array[@]}"; do
      date_tag=$(date +"%Y-%m-%d-%Hh-%Mm-%Ss")
      terra_project=${terra_project_array[$index]}
      workspace_name=${workspace_name_array[$index]}
      table_name=${table_name_array[$index]}
      table_id=${table_id_array[$index]}
      gcs_uri=${gcs_uri_prefix_array[$index]}
      output_filename_prefix=${output_filename_prefix_array[$index]}

      export terra_project workspace_name table_name table_id date_tag gcs_uri output_filename_prefix

      # download Terra table TSV using export_large_tsv.py from Broad
      python3 /scripts/export_large_tsv/export_large_tsv.py \
        --project "${terra_project}" \
        --workspace "${workspace_name}" \
        --entity_type "${table_name}" \
        --page_size ~{page_size} \
        --tsv_filename "${table_id}_${date_tag}.tsv"

      echo -e "\n::Procesing ${table_id} for export (${date_tag})::"

      # reformat TSV using code below
      # additionally take cleaned-TSV and create nlJSON
      python3<<CODE
  import csv
  import json
  import collections
  import os

  from firecloud import api as fapi

  # sanity checks for env variables loaded into python
  workspace_project = os.environ['terra_project']
  print("workspace project: "+ workspace_project)
  workspace_name = os.environ['workspace_name']
  print("workspace name: "+ workspace_name)
  table_name = os.environ['table_name']
  print("table name: "+ table_name)
  out_fname = os.environ['table_id']
  print("out_fname: " + out_fname)
  date_tag = os.environ['date_tag']
  print("date_tag: " + date_tag)

  ####COMMENTING OUT THIS BLOCK####
  # Grabbbing defined table using firecloud api and reading data to to python dictionary
  #table = json.loads(fapi.get_entitiesget_entities(workspace_project, workspace_name, table_name).text)

  # instead of loading JSON directly from Terra data table, load in TSV that was just exported from Terra

  ####COMMENTING OUT THIS BLOCK####
  # This block transforms JSON to dictionary
  # headers = collections.OrderedDict()
  # rows = []
  # headers[table_name + "_id"] = 0
  # for row in table:
  #   outrow = row['attributes']
  #   for x in outrow.keys():
  #     headers[x] = 0
  #     if type(outrow[x]) == dict and set(outrow[x].keys()) == set(('itemsType', 'items')):
  #       outrow[x] = outrow[x]['items']
  #   outrow[table_name + "_id"] = row['name']
  #   rows.append(outrow)

  ####COMMENTING OUT THIS BLOCK####
  # Writing tsv output from dictionary object
  # with open(out_fname+'_temp.tsv', 'w') as outf:
  #   writer = csv.DictWriter(outf, headers.keys(), delimiter='\t', dialect=csv.unix_dialect, quoting=csv.QUOTE_MINIMAL)
  #   writer.writeheader()
  #   writer.writerows(rows)
  
  print("adding source_terra_table column to TSV...")

  # TSV add additional column
  # Add column to capture source terra table (table_id) 
  with open(out_fname + '_' + date_tag +'.tsv','r') as csvinput:
    with open(out_fname+'.tsv', 'w') as csvoutput:
        writer = csv.writer(csvoutput, delimiter='\t')
        reader = csv.reader(csvinput, delimiter='\t')

        all = []
        tsv_row = next(reader)
        tsv_row.append("source_terra_table")
        all.append(tsv_row)

        for tsv_row in reader:
            tsv_row.append(out_fname)
            all.append(tsv_row)

        writer.writerows(all)

  print("converting TSV to newline JSON...")

  # Writing the newline json file from tsv output above
  with open(out_fname+'.tsv', 'r') as infile:
    headers = infile.readline()
    headers_array = headers.strip().split('\t')
    headers_array[0] = "specimen_id"
    with open(out_fname+'.json', 'w') as outfile:
      for line in infile:
        outfile.write('{')
        line_array=line.strip().split('\t')
        for x,y in zip(headers_array, line_array):
          if x == "nextclade_aa_dels" or x == "nextclade_aa_subs":
            y = y.replace("|", ",")
          if y == "NA":
            y = ""
          if y == "N/A":
            y = ""
          if y == "Unknown":
            y = ""
          if y == "unknown":
            y = ""
          if y == "UNKNOWN":
            y = ""
          if y == "required_for_submission":
            y = ""
          if "Uneven pairs:" in y:
            y = ""
          if x == "County":
            pass
          else:
            outfile.write('"'+x+'"'+':'+'"'+y+'"'+',')
        outfile.write('"notes":""}'+'\n')
  print ("finished creating newline JSON, exiting python block...")
  CODE

      export CLOUDSDK_PYTHON=python2.7  # ensure python 2.7 for gsutil commands

      # add date tag when transferring file to gcp
      #### date_tag variable is already set above the python block, so commenting out ###
      #date_tag=$(date +"%Y-%m-%d-%Hh-%Mm-%Ss")

      # if user defines a filename prefix, then use it to name the output JSON file
      # if output_filename_prefix bash input string is non-zero, return TRUE
      if [ -n "${output_filename_prefix}" ]; then
        echo "User specified an output filename prefix of: ${output_filename_prefix}"
        # copy new line JSON to bucket & copy re-formatted TSV (for testing purposes)
        gsutil -m cp "${table_id}.json" "${gcs_uri}${output_filename_prefix}.json"
        echo "${output_filename_prefix}.json copied to ${gcs_uri}"
      else
        # copy new line JSON to bucket & copy re-formatted TSV (for testing purposes)
        echo "User did NOT specify an output prefix, using default prefix with table_id and date_tag variables"
        gsutil -m cp "${table_id}.json" "${gcs_uri}${table_id}_${date_tag}.json"
        echo "${table_id}_${date_tag}.json copied to ${gcs_uri}"
      fi

      unset CLOUDSDK_PYTHON   # probably not necessary, but in case I do more things afterwards, this resets that env var
    done
    echo "Sleeping for user-specified time of " ~{sleep_time}
    sleep ~{sleep_time}
    echo "Finished sleeping, onto the next iteration of the loop!"
  done
  echo "Loop exited"
  >>>

  runtime {
    docker: docker
    memory: "~{mem_size_gb} GB"
    cpu: CPUs
    disks: "local-disk ~{disk_size} SSD"
  }

  output {
    ## add outputs for all intermediate files
  }
}
