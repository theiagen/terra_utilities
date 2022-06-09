version 1.0

task prune_table {
  input {
    String table_name
    String workspace_name
    String project_name
    File? input_table
    Array[String] sample_names
    String biosample_type
    String bioproject
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
   
    # remove rows with blank cells from table
    table.replace(r'^\s+$', np.nan, regex=True)        # replace blank cells with NaNs 
    excluded_samples = table[table.isna().any(axis=1)] # write out all rows with NaNs to a new table
    excluded_samples["~{table_name}_id"].to_csv("excluded_samples.tsv", sep='\t', index=False, header=False) # write the excluded names out to a file
    table.dropna(axis=0, how='any', inplace=True)      # remove all rows with NaNs from table
    
    # set required and optional metadata fields based on the biosample_type package
    if ("~{biosample_type}" == "Microbe") or ("~{biosample_type}" == "microbe"):
      required_metadata = ["submission_id", "organism", "isolate", "collection_date", "geo_loc_name", "sample_type"]
      optional_metadata = ["strain", "isolate", "bioproject_accession", "attribute_package", "host", "isolation_source", "collected_by", "identified_by", "MLST"] # this will be easy to add to
      # add a column for biosample package -- required for XML submission
      table["attribute_package"] = "Microbe"
      # umbrella bioproject = PRJNA531911
      # subproject depends on organism
      # "CDC HAI-Seq Gram-negative bacteria (PRJNA288601) will be used for most AR LAb Network submissions related to HAIs"
      # qc checks:
      #   q-score >= 30
      #   reads > 50 bp
      #   trailing/leading bases removed
      #   similar GC content to expected genome
      #   assembled genome ratio ~1.0
      #   200 contigs or less
   
    elif ("~{biosample_type}" == "Pathogen") or ("~{biosample_type}" == "pathogen"):
      required_metadata = ["submission_id", "organism", "collected_by", "collection_date", "geo_loc_name", "host", "host_disease", "isolation_source", "lat_lon", "isolation_type"]
      optional_metadata = ["sample_title", "bioproject_accession", "attribute_package", "strain", "isolate", "culture_collection", "genotype",	"host_age",	"host_description",	"host_disease_outcome",	"host_disease_stage", "host_health_state",	"host_sex",	"host_subject_id",	"host_tissue_sampled",	"passage_history",	"pathotype",	"serotype",	"serovar",	"specimen_voucher",	"subgroup",	"subtype",	"description"] 
      # add a column for biosample package -- required for XML submission
      table["attribute_package"] = "Pathogen.cl"
      # umbrella bioproject = PRJNA642852
      # qc checks:
      #   gc after trimming 42-47.5%
      #   average phred after trimming >= 28
     
      #   coverage after trimming >= 20X
      #if "mean_coverage_depth" in table.columns:
      #  table = table[(table.mean_coverage_depth > 20)]

    else:
      raise Exception('Only "Microbe" and "Pathogen" are supported as acceptable input for the \`biosample_type\` variable at this time. You entered ~{biosample_type}.')

    # add bioproject_accesion to table
    table["bioproject_accession"] = "~{bioproject}"
    
    # extract the required metadata from the table
    biosample_metadata = table[required_metadata].copy()

    # add optional metadata fields if present; rename first column
    for column in optional_metadata:
      if column in table.columns:
        biosample_metadata[column] = table[column]
    biosample_metadata.rename(columns={"submission_id" : "sample_name"}, inplace=True)

    # sra metadata is the same regardless of biosample_type package, but I'm separating it out in case we find out this is incorrect
    sra_fields = ["submission_id", "library_ID", "title", "library_strategy", "library_source", "library_selection", "library_layout", "platform", "instrument_model", "design_description", "filetype", "read1", "read2"]
    
    # extract the required metadata from the table; rename first column 
    sra_metadata = table[sra_fields].copy()
    #sra_metadata.rename(columns={"submission_id" : "sample_id"}, inplace=True)
    sra_metadata.rename(columns={"submission_id" : "sample_name"}, inplace=True)

    # prettify the filenames and rename them to be sra compatible
    sra_metadata["read1"] = sra_metadata["read1"].map(lambda filename: filename.split('/').pop())
    sra_metadata["read2"] = sra_metadata["read2"].map(lambda filename2: filename2.split('/').pop())   
    sra_metadata.rename(columns={"read1" : "filename", "read2" : "filename2"}, inplace=True)
 
    ### Create a file that contains the names of all the reads so we can use gsutil -m cp
    table["read1"].to_csv("filepaths.tsv", index=False, header=False)
    table["read2"].to_csv("filepaths.tsv", mode='a', index=False, header=False)

    # write metadata tables to tsv output files
    biosample_metadata.to_csv("biosample_table.tsv", sep='\t', index=False)
    sra_metadata.to_csv("sra_table.tsv", sep='\t', index=False)

    CODE

    # copy the raw reads to the bucket specified by user
    export CLOUDSDK_PYTHON=python2.7  # ensure python 2.7 for gsutil commands
    # iterate through file created earlier to grab the uri for each read file
    while read -r line; do
      echo "running \`gsutil -m cp ${line} ~{gcp_bucket_uri}\`"
      gsutil -m cp -n ${line} ~{gcp_bucket_uri}
    done < filepaths.tsv
    unset CLOUDSDK_PYTHON   # probably not necessary, but in case I do more things afterwards, this resets that env var

  >>>
  output {
    File biosample_table = "biosample_table.tsv"
    File sra_table = "sra_table.tsv"
    File excluded_samples = "excluded_samples.tsv"
  }
  runtime {
    docker: "broadinstitute/terra-tools:tqdm"
    memory: "8 GB"
    cpu: 4
    disks: "local-disk 100 SSD"
    preemptible: 0
  }
}

task add_biosample_accessions {
  input {
    File attributes
    File sra_metadata
  }
  command <<<
    # extract from the attributes file the biosample and original name columns
    # put the original name in column 1, biosample in column 2
    awk -F '\t' '{print $3, $1}' OFS='\t' ~{attributes} > biosample_temp.tsv

    # echo out the header
    echo -e "$(head -n 1 ~{sra_metadata})\tbiosample_accession" > "sra_table_with_biosample_accessions-with-sample-names.tsv"

    # join the biosample_temp with the sra_metadata; using tail to skip the header 
    join -t $'\t' <(sort <(tail -n+2 ~{sra_metadata})) <(sort <(tail -n+2 biosample_temp.tsv)) >> "sra_table_with_biosample_accessions-with-sample-names.tsv"

    # remove the unnecessary submission_id column
    cut -f2- "sra_table_with_biosample_accessions-with-sample-names.tsv" > "sra_table_with_biosample_accessions.tsv"
  
  >>>
  output {
    File sra_table = "sra_table_with_biosample_accessions.tsv"
  }
  runtime {
    docker: "broadinstitute/terra-tools:tqdm"
    memory: "8 GB"
    cpu: 4
    disks: "local-disk 100 SSD"
    preemptible: 0
  }
}