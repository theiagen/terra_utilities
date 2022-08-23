version 1.0

task ncbi_sftp_upload {
  input {
    File submission_xml
    Array[File] additional_files = []
    File config_js
    String target_path

    String wait_for="1"  # all, disabled, some number
  }
  command <<<
    # append current date to the second to end of target_path 
    if [ ~{target_path} == "production" || ~{target_path} == "Production" ]; then
      path="Production"
    else # if they don't put in production, it will default to Test
      path="Test"
    fi

    upload_path="submit/${path}/sra/$(date +'%Y-%m-%d_%H-%M-%S')"

    set -e
    cd /opt/converter
    cp "~{config_js}" src/config.js
    rm -rf files/tests
    cp "~{submission_xml}" files/submission.xml
    if [[ "~{length(additional_files)}" != "0" ]]; then
      cp ~{sep=' ' additional_files} files/
    fi
    MANIFEST=$(ls -1 files | paste -sd,)
    echo "uploading: $MANIFEST to destination ftp folder ~{target_path}"
    echo "Asymmetrik script version: $ASYMMETRIK_REPO_COMMIT"
    node src/main.js --debug \
      --uploadFiles="$MANIFEST" \
      --poll="~{wait_for}" \
      --uploadFolder="$upload_path"
    ls -alF files reports
    cd -
    cp /opt/converter/reports/*report.*.xml .

    echo "#### REPORT XML FILES ####"
    cat *report.*.xml
  >>>
  output {
    Array[File] reports_xmls = glob("*report*.xml")
  }
  runtime { 
    cpu: 2
    memory: "2 GB"
    disks: "local-disk 100 HDD"
    dx_instance_type: "mem2_ssd1_v2_x2"
    docker: "quay.io/broadinstitute/ncbi-tools:2.10.7.10"
    maxRetries: 0
  }
}

task sra_tsv_to_xml { 
  input {
    File meta_submit_tsv
    File config_js
    String bioproject
    String data_bucket_uri
  }
  command <<<
    set -e
    cd /opt/converter
    cp "~{config_js}" src/config.js
    cp "~{meta_submit_tsv}" files/
    echo "Asymmetrik script version: $ASYMMETRIK_REPO_COMMIT"
    node src/main.js --debug \
      -i=$(basename "~{meta_submit_tsv}") \
      --submissionType=sra \
      --bioproject="~{bioproject}" \
      --submissionFileLoc="~{data_bucket_uri}" \
      --runTestMode=true
    cd -
    cp "/opt/converter/files/~{basename(meta_submit_tsv, '.tsv')}-submission.xml" .
  >>>
  output {
    File submission_xml = "~{basename(meta_submit_tsv, '.tsv')}-submission.xml"
  }
  runtime {
    cpu: 1
    memory: "2 GB"
    disks: "local-disk 50 HDD"
    dx_instance_type: "mem2_ssd1_v2_x2"
    docker: "quay.io/broadinstitute/ncbi-tools:2.10.7.10"
    maxRetries: 2
  }
}

task biosample_submit_tsv_ftp_upload { 
  input {
    File meta_submit_tsv
    File config_js
    String target_path
  }
  String base=basename(meta_submit_tsv, '.tsv')
  meta {
    description: "This registers a table of metadata with NCBI BioSample. It accepts a TSV similar to the web UI input at submit.ncbi.nlm.nih.gov, but converts to an XML, submits via their FTP/XML API, awaits a response, and retrieves a resulting attributes table and returns that as a TSV. This task registers live data with the production NCBI database."
  }
  command <<<
    # append current date to the second to end of target_path 
    if [ ~{target_path} == "production" || ~{target_path} == "Production" ]; then
      path="Production"
    else # if they don't put in production, it will default to Test
      path="Test"
    fi

    upload_path="submit/${path}/biosample/$(date +'%Y-%m-%d_%H-%M-%S')"


    set -e
    cd /opt/converter
    cp "~{config_js}" src/config.js
    cp "~{meta_submit_tsv}" files/
    echo "Asymmetrik script version: $ASYMMETRIK_REPO_COMMIT"
    node src/main.js --debug \
        -i=$(basename "~{meta_submit_tsv}") \
        --uploadFolder="$upload_path" # target directory on FTP server
    cd -

    # for if these exist, output these
    cp /opt/converter/reports/~{base}-report.*.xml . # given back

    # cat the report file to stdout
    echo "#### REPORT XML FILES ####"
    cat ~{base}-report.*.xml

    # parse final report.xml for any generated biosample accessions
    grep "accession=" report.xml | cut -d ' ' -f12-13 | sed 's/accession="//' | sed 's/" spuid="/\t/' | sed 's/"//' > generated_accessions.tsv

    # extract any "error-stop" messages and their spuids, reasons, and invalid attribute
    # this -A 4 means that it grabs the next 4 lines after the match; may need to be adjusted in the future
    grep -A 4 "error-stop" report.xml  > biosample_failures.txt

    cp /opt/converter/files/~{base}-submission.xml . # we upload -- should always be produced.

    ## test this to make sure task doesn't fail if not produced.
    if [ -f /opt/converted/reports/~{base}-attributes.tsv ]; then
      cp /opt/converter/reports/~{base}-attributes.tsv . # given back -- make this optional
    fi
  >>>
  output {
    File generated_accessions = "generated-accessions.tsv"
    File biosample_failures = "biosample_failures.txt"
    File submission_xml = "~{base}-submission.xml"
    File? biosample_attributes = "~{base}_attributes.tsv"
    Array[File] report_xmls   = glob("~{base}-report*.xml")
  }
  runtime {
    cpu: 2
    memory: "2 GB"
    disks: "local-disk 100 HDD"
    dx_instance_type: "mem2_ssd1_v2_x2"
    docker: "quay.io/broadinstitute/ncbi-tools:2.10.7.10"
    maxRetries: 0
  }
}