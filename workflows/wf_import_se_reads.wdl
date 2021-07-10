version 1.0

import "../tasks/task_file_handling.wdl" as file_handling
import "../tasks/task_versioning.wdl" as versioning

workflow import_se_read_files {
    input {
      File  reads
    }
    call file_handling.cp_reads_to_workspace_se {
    input:
      reads = reads
    }
    call versioning.version_capture{
    input:
    }
 output {
    String  import_se_version        = version_capture.terra_utilities_version
    String  import_se_analysis_date  = version_capture.date
    File    imported_reads           = cp_reads_to_workspace_se.cp_reads
}
}
