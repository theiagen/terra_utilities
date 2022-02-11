version 1.0

task import_terra_table {
  input {
    String terra_project
    String workspace_name
    File terra_table
     
  }
  command {
    python3 /scripts/import_large_tsv/import_large_tsv.py --project ~{terra_project} --workspace ~{workspace_name} --tsv ~{terra_table}
  }
  output {
  }
  runtime {
    memory: "4 GB"
    cpu: 2
    docker: "broadinstitute/terra-tools:tqdm"
    disks: "local-disk 100 HDD"
  }
}