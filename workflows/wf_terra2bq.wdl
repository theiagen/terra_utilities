version 1.0

workflow terra_2_bq {

    input {
      String	gcs_uri
      String	outname
    }

    call terra_to_bigquery {
      input:
        outname=outname,
        gcs_uri_prefix=gcs_uri
    }

}

task terra_to_bigquery {
  input {
    String  terra_project
    String  workspace_name
    String  table_name
    String  outname
    String  gcs_uri_prefix
    String  docker = "schaluvadi/pathogen-genomic-surveillance:api-wdl"
    Int mem_size_gb = 32
    Int CPUs = 8
    Int disk_size = 100
  }

  meta {
    volatile: true
  }
  command <<<
  set -e
  
  #Infinite While loop
  counter=0
  echo "enterring loop"
  while true
  do
    python3<<CODE
  import csv
  import json
  import collections

  from firecloud import api as fapi

  workspace_project = '~{terra_project}'
  workspace_name = '~{workspace_name}'
  table_name = '~{table_name}'
  out_fname = '~{outname}'+'.csv'

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
  with open(out_fname, 'wt') as outf:
    writer = csv.DictWriter(outf, headers.keys(), delimiter='\t', dialect=csv.unix_dialect, quoting=csv.QUOTE_MINIMAL)
    writer.writeheader()
    writer.writerows(rows)

  # Writing the newline json file from tsv output above
  with open(out_fname, 'r') as infile:
    headers = infile.readline()
    headers_array = headers.strip().split('\t')
    headers_array[0] = "specimen_id"
    with open('~{outname}'+'.json', 'w') as outfile:
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
    date_tag=$(date +"%Y-%m-%d-%mm-%ss")
    echo "count: $counter"
    echo "TIME IS NOW: ${date_tag}" 
    echo "I'm out of the python block"
    
    # add date tag before pushing 
    gsutil -m cp "~{outname}.json" ~{gcs_uri_prefix}/"~{outname}_${date_tag}.json"

    sleep 15m
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
    File csv_file = "~{outname}.csv"
    File json_file = "~{outname}.json"
  }
}
