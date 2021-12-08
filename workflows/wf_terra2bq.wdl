version 1.0

workflow terra_2_bq {

    input {
      Array[String]  terra_projects
      Array[String]  workspace_names
      Array[String]  table_names
      Array[String]  table_ids
      String  gcs_uri
    }

    call terra_to_bigquery {
      input:
        terra_projects=terra_projects,
        workspace_names=workspace_names,
        table_names=table_names,
        table_ids=table_ids,
        gcs_uri_prefix=gcs_uri
    }

}

task terra_to_bigquery {
  input {
    Array[String]  terra_projects
    Array[String]  workspace_names
    Array[String]  table_names
    Array[String]  table_ids
    String  gcs_uri_prefix
    String  docker = "schaluvadi/pathogen-genomic-surveillance:api-wdl"
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
  table_id__array_len=$(echo "${#table_id[@]}")
  
  # Ensure equal length of all input arrays
  echo "Terra Projects: $terra_project_array_len, Workspace name: $workspace_name_array_len, Table Names: $table_name_array_len, Table IDs: $table_id_array_len"
  if [ "$terra_project_array_len" -ne "$workspace_name_array_len" ] || [ "$terra_project_array_len" -ne "$table_name_array_len" ] || [ "$terra_project_array_len" -ne "$table_id_array_len" ]; then
    echo "Input arrays are of unequal length. Terra Projects: $terra_project_array_len, Workspace name: $workspace_name_array_len, Table Names: $table_name_array_len, Table IDs: $table_id_array_len" >&2
    exit 1
  else 
    echo "Input arrays are of equal length. Terra Projects: $terra_project_array_len, Workspace name: $workspace_name_array_len, Table Names: $table_name_array_len, Table IDs: $table_id_array_len"
  fi
  
  #Infinite While loop
  counter=0
  echo "enterring loop"
  while true
  do
  
  # Loop through inputs and run python script to create tsv/json and push json to gcp bucket
  for index in  ${!terra_project_array[@]}; do
    terra_project=${terra_project_array[$index]}
    workspace_name=${workspace_name_array[$index]}
    table_name=${table_name_array[$index]}
    table_id=${table_id_array[$index]}
    
    export terra_project workspace_name table_name table_id
  
    python3<<CODE
  import csv
  import json
  import collections
  import os

  from firecloud import api as fapi

  workspace_project = os.environ['terra_project']
  print("workspace project: "+ workspace_project)
  workspace_name = os.environ['workspace_name']
  print("workspace name: "+ workspace_name)
  table_name = os.environ['table_name']
  print("table name: "+ table_name)
  out_fname = os.environ['table_id']
  print("out_fname: " + out_fname) 

  # Grabbbing defined table using firecloud api and reading data to to python dictionary
  table = json.loads(fapi.get_entities(workspace_project, workspace_name, table_name).text)
  headers = collections.OrderedDict()
  rows = []
  headers[table_name + "_id"] = 0
  for row in table:
    outrow = row['attributes']
    for x in outrow.keys():
      headers[x] = 0
      if type(outrow[x]) == dict and set(outrow[x].keys()) == set(('itemsType', 'items')):
        outrow[x] = outrow[x]['items']
    outrow[table_name + "_id"] = row['name']
    rows.append(outrow)

  # Writing tsv output from dictionary object
  with open(out_fname+'.tsv', 'w') as outf:
    writer = csv.DictWriter(outf, headers.keys(), delimiter='\t', dialect=csv.unix_dialect, quoting=csv.QUOTE_MINIMAL)
    writer.writeheader()
    writer.writerows(rows)

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
          if y == "required_for_submission":
            y = ""
          if "Uneven pairs:" in y:
            y = ""
          if x == "County":
            pass
          else:  
            outfile.write('"'+x+'"'+':'+'"'+y+'"'+',')
        outfile.write('"notes":""}'+'\n')      
  CODE
      # counter and sanity checks for troubleshooting
      counter=$((counter+1))
      date_tag=$(date +"%Y-%m-%d-%Hh-%Mm-%Ss")
      echo "count: $counter"
      echo "TIME IS NOW: ${date_tag}" 
      echo "I'm out of the python block"
    
      # add date tag before pushing 
      gsutil -m cp "${table_id}.json" "~{gcs_uri_prefix}${table_id}_${date_tag}.json"
      echo "${table_id}_${date_tag}.json copied to ~{gcs_uri_prefix}"
    done
    sleep ~{sleep_time}
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
  }
}
