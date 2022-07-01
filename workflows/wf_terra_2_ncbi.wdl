version 1.0

import "../tasks/task_submission.wdl" as submission
import "../tasks/task_broad_ncbi_tools.wdl" as ncbi_tools

workflow Terra_2_NCBI {
  input {
    String project_name
    String workspace_name
    String table_name
    Array[String] sample_names
   # Array[String]? biosample_accessions
    File ncbi_config_js
    File? input_table
    String biosample_type
    String gcp_bucket_uri
    String path_on_ftp_server
    String bioproject
  }
  call submission.prune_table {
    input:
    # if they know biosample accession, 
      project_name = project_name,
      workspace_name = workspace_name,
      table_name = table_name,
      sample_names = sample_names,
      input_table = input_table,
      biosample_type = biosample_type,
      bioproject = bioproject,
      gcp_bucket_uri = gcp_bucket_uri,
    #  biosample_accessions = biosample_accessions
  }
  call ncbi_tools.biosample_submit_tsv_ftp_upload {
    input:
      meta_submit_tsv = prune_table.biosample_table, 
      config_js = ncbi_config_js, 
      target_path = path_on_ftp_server
  }
  call submission.add_biosample_accessions {
    input:
      attributes = biosample_submit_tsv_ftp_upload.attributes_tsv,
      sra_metadata = prune_table.sra_table,
      project_name = project_name,
      workspace_name = workspace_name,
      table_name = table_name
  }
  call ncbi_tools.sra_tsv_to_xml {
    input:
      meta_submit_tsv = add_biosample_accessions.sra_table,
      config_js = ncbi_config_js,
      bioproject = bioproject,
      data_bucket_uri = gcp_bucket_uri
  }
  call ncbi_tools.ncbi_sftp_upload {
    input: 
      submission_xml = sra_tsv_to_xml.submission_xml,
      config_js = ncbi_config_js,
      target_path = path_on_ftp_server
  }
  output {
    File sra_metadata = add_biosample_accessions.sra_table
    File biosample_metadata = prune_table.biosample_table
    File excluded_samples = prune_table.excluded_samples
    File attributes_tsv = biosample_submit_tsv_ftp_upload.attributes_tsv
    File biosample_submission_xml = biosample_submit_tsv_ftp_upload.submission_xml
    Array[File] biosample_report_xmls = biosample_submit_tsv_ftp_upload.reports_xmls
    File sra_submission_xml = sra_tsv_to_xml.submission_xml
    Array[File] sra_report_xmls = ncbi_sftp_upload.reports_xmls
  }
}
