version 1.0

import "../tasks/task_submission.wdl" as submission
import "../tasks/task_broad_ncbi_tools.wdl" as ncbi_tools

workflow ncbi_submission {
  input {
    String project_name
    String workspace_name
    String table_name
    Array[String] sample_names
    File ncbi_config_js
    File? input_table
    String biosample_type
    String gcp_bucket_uri
  }
  call submission.prune_table {
    input:
      project_name = project_name,
      workspace_name = workspace_name,
      table_name = table_name,
      sample_names = sample_names,
      input_table = input_table,
      biosample_type = biosample_type,
      gcp_bucket_uri = gcp_bucket_uri
  }
  call ncbi_tools.biosample_submit_tsv_to_xml {
    input:
      meta_submit_tsv = prune_table.biosample_table,
      config_js = ncbi_config_js
  }
  #call ncbi_tools.sra_tsv_to_xml {
  #  input:
  #    meta_submit_tsv = prune_table.sra_table,
  #    config_js = ncbi_config_js,
  #    bioproject = bioproject,
  #    data_bucket_uri = gcp_bucket_uri
  #}
  

  output {
     File biosample_metadata = prune_table.biosample_table
     File sra_metadata = prune_table.sra_table
     File excluded_samples = prune_table.excluded_samples
     File biosample_submission_xml = biosample_submit_tsv_to_xml.submission_xml
  #   File sra_submission_xml = sra_tsv_to_xml.submission_xml
  }
}
