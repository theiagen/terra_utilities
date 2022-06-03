version 1.0

task prune_table {
  input {
    String table_name
    String workspace_name
    String project_name
    File? input_table
    Array[String] sample_names
    String biosample_type
    String gcp_bucket_uri
  }
  command <<<
    # when running on terra, comment out all input_table mentions
    python3 /scripts/export_large_tsv/export_large_tsv.py --project ~{project_name} --workspace ~{workspace_name} --entity_type ~{table_name} --tsv_filename ~{table_name}-data.tsv
    
    # when running locally, use the input_table in place of downloading from Terra
    #cp ~{input_table} ~{table_name}-data.tsv

    python3 <<CODE 
    import pandas as pd
    import numpy as np

    # read export table into pandas
    tablename = "~{table_name}-data.tsv"
    table = pd.read_csv(tablename, delimiter='\t', header=0)

    # extract the samples for upload from the entire table
    table = table[table["~{table_name}_id"].isin("~{sep='*' sample_names}".split("*"))]
    
    # set required and optional metadata fields based on the biosample_type package
    if ("~{biosample_type}" == "Microbe") or ("~{biosample_type}" == "microbe"):
      required_metadata = ["~{table_name}_id", "organism", "isolate", "collection_date", "geo_loc_name", "sample_type"]
      optional_metadata = ["strain", "isolate", "host", "isolation_source", "collected_by", "identified_by"] # this will be easy to add to
    elif ("~{biosample_type}" == "Pathogen") or ("~{biosample_type}" == "pathogen"):
      required_metadata = ["~{table_name}_id", "organism", "collected_by", "collection_date", "geo_loc_name", "host", "host_disease", "isolation_source", "lat_lon", "isolation_type"]
      optional_metadata = ["isolate", "strain", "bioproject_accession", "host_age", "host_sex"] # this will be easy to add to
    else:
      raise Exception('Only "Microbe" and "Pathogen" are supported as acceptable input for the \`biosample_type\` variable at this time. You entered ~{biosample_type}.')
    
    # todo: prune qc checks

    # remove rows with blank cells from table
    table.replace(r'^\s+$', np.nan, regex=True)        # replace blank cells with NaNs 
    excluded_samples = table[table.isna().any(axis=1)] # write out all rows with NaNs to a new table
    excluded_samples["~{table_name}_id"].to_csv("excluded-samples.tsv", sep='\t', index=False, header=False) # write the excluded names out to a file
    table.dropna(axis=0, how='any', inplace=True)      # remove all rows with NaNs from table
        
    # extract the required metadata from the table
    biosample_metadata = table[required_metadata].copy()

    # add optional metadata fields if present, rename first column
    for column in optional_metadata:
      if column in table.columns:
        biosample_metadata[column] = table[column]
    biosample_metadata.rename(columns={"~{table_name}_id" : "sample_name"}, inplace=True)

    # sra metadata is the same regardless of biosample_type package, but I'm separating it out in case we find out this is incorrect
    sra_fields = ["~{table_name}_id", "library_id", "title", "library_strategy", "library_source", "library_selection", "library_layout", "platform", "instrument_model", "design_description", "filetype", "read1", "read2"]
    
    # extract the required metadata from the table, rename first column 
    sra_metadata = table[sra_fields].copy()
    sra_metadata.rename(columns={"~{table_name}_id" : "sample_id"}, inplace=True)
     
    # prettify the filenames and rename them to be sra compatible
    sra_metadata["read1"] = sra_metadata["read1"].map(lambda filename: filename.split('/').pop())
    sra_metadata["read2"] = sra_metadata["read2"].map(lambda filename2: filename2.split('/').pop())   
    sra_metadata.rename(columns={"read1" : "filename", "read2" : "filename2"}, inplace=True)
 
    ### Create a file that contains the names of all the reads so we can use gsutil -m cp
    table["read1"].to_csv("filepaths.tsv", index=False, header=False)
    table["read2"].to_csv("filepaths.tsv", mode='a', index=False, header=False)

    # write metadata tables to tsv output files
    biosample_metadata.to_csv("biosample-table.tsv", sep='\t', index=False)
    sra_metadata.to_csv("sra-table.tsv", sep='\t', index=False)

    CODE

    # copy the raw reads to the bucket specified by user
    export CLOUDSDK_PYTHON=python2.7  # not sure why this works, but google recommended this
    # iterate through file created earlier to grab the uri for each read file
    while read -r line; do
      echo "running \`gsutil -m cp ${line} ~{gcp_bucket_uri}\`"
      gsutil -m cp -n ${line} ~{gcp_bucket_uri}
    done < filepaths.tsv
    unset CLOUDSDK_PYTHON   # probably not necessary, but in case I do more things afterwards, this resets that env var

  >>>
  output {
    File biosample_table = "biosample-table.tsv"
    File sra_table = "sra-table.tsv"
    File excluded_samples = "excluded-samples.tsv"
  }
  runtime {
    docker: "broadinstitute/terra-tools:tqdm"
    memory: "8 GB"
    cpu: 4
    disks: "local-disk 100 SSD"
    preemptible: 0
  }
}