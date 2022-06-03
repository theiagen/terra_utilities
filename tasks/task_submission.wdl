version 1.0

task prune_table { # this is only for c. auris submission at the moment
  input {
    String table_name
    String workspace_name
    String project_name
    File? input_table
    Array[String] sample_names
  }
  command <<<
    # when running on terra, comment out all input_table mentions
    #python3 /scripts/export_large_tsv/export_large_tsv.py --project ~{project_name} --workspace ~{workspace_name} --entity_type ~{table_name} --tsv_filename ~{table_name}-data.tsv
    
    # when running locally, use the input_table in place of downloading from Terra
    cp ~{input_table} ~{table_name}-data.tsv

    wc -l ~{table_name}-data.tsv
       
    python3 << CODE 
    import pandas as pd
  
    # read export table into pandas
    tablename = "~{table_name}-data.tsv"
    table = pd.read_csv(tablename, delimiter='\t', header=0)

    # extract the samples for upload from the entire table
    table = table[table["~{table_name}_id"].isin("~{sep='*' sample_names}".split("*"))]
   
    # create biosample/sra metadata sheets 
    biosample_metadata = table[["~{table_name}_id", "organism", "isolate", "collected_by", "collection_date", "geo_loc_name", "host", "host_disease", "isolation_source", "lat_lon", "isolation_type"]].copy()
    biosample_metadata.rename(columns={"~{table_name}_id" : "sample_name"}, inplace=True)
    
    biosample_outfile = biosample_metadata.to_csv("biosample-table.tsv", sep='\t', index=False)

    sra_metadata = table[["~{table_name}_id", "library_id", "title", "library_strategy", "library_source", "library_selection", "library_layout", "platform", "instrument_model", "design_description", "filetype", "filename", "filename2"]].copy()
    sra_metadata.rename(columns={"~{table_name}_id" : "sample_id"}, inplace=True)

    sra_outfile = sra_metadata.to_csv("sra-table.tsv", sep='\t', index=False)

    CODE

  >>>
  output {
    File biosample_table = "biosample-table.tsv"
    File sra_table = "sra-table.tsv"

  }
  runtime {
    docker: "broadinstitute/terra-tools:tqdm"
    memory: "8 GB"
    cpu: 4
    disks: "local-disk 100 SSD"
    preemptible: 0
  }


}