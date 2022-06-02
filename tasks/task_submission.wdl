version 1.0

task prune_table {
  input {
    String table_name
    String workspace_name
    String project_name
    Array[String] sample_names
    String docker_image = "broadinstitute/terra-tools:tqdm"
  }
  command <<<
    echo "before download"
    python3 /scripts/export_large_tsv/export_large_tsv.py --project ~{project_name} --workspace ~{workspace_name} --entity_type ~{table_name} --tsv_filename ~{table_name}-data.tsv
    echo "after download"
    echo `wc -l ~{table_name}-data.tsv`
    echo "after wc -l command"
    # prune out only those in sample_names
    python3 << CODE 
    import pandas as pd
    print("inside python code")
    # read export table into pandas
    table = pd.read_csv(~{table_name}-data.tsv, delimiter='\t', header=0)
    print(table)
    # extract the samples for upload from the entire table
    table = table[table["entity:~{table_name}_id"].isin("~{sep='*' sample_names}".split("*"))]
    
    # create biosample/sra metadata sheets
    outfile = table.to_csv("pruned-table.tsv", sep='\t', index=False)
    CODE

    # gcp data transfer

  >>>
  output {
    File pruned_table = "pruned-table.tsv"

  }
  runtime {
    docker: "~{docker_image}"
    memory: "8 GB"
    cpu: 4
    disks: "local-disk 100 SSD"
    preemptible: 0
  }


}