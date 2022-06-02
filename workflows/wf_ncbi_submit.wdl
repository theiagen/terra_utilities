version 1.0

import "../tasks/task_submission.wdl" as submission

workflow ncbi_submission {
  input {
    String project_name
    String workspace_name
    String table_name
    Array[String] sample_names
    String ncbi_username
    String ncbi_config_stuff
  }
  call submission.prune_table {
    input:
      project_name = project_name,
      workspace_name = workspace_name,
      table_name = table_name,
      sample_names = sample_names
  }




}
