version 1.0

task ncbi_sftp_upload {
    input {
        File           submission_xml
        Array[File]    additional_files = []
        File           config_js
        String         target_path

        String         wait_for="1"  # all, disabled, some number

        String         docker = "quay.io/broadinstitute/ncbi-tools:2.10.7.10"
    }
    command <<<
        upload_path="~{target_path}/sra/$(date -I)_$(echo $RANDOM | md5sum | head -c 10)"

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
        cp /opt/converter/reports/*report*.xml .
    >>>
    output {
        Array[File] reports_xmls = glob("*report*.xml")
    }
    runtime {
        cpu:     2
        memory:  "2 GB"
        disks:   "local-disk 100 HDD"
        dx_instance_type: "mem2_ssd1_v2_x2"
        docker:  docker
        maxRetries: 0
    }
}

task sra_tsv_to_xml {
    input {
        File     meta_submit_tsv
        File     config_js
        String   bioproject
        String   data_bucket_uri

        String   docker = "quay.io/broadinstitute/ncbi-tools:2.10.7.10"
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
        File   submission_xml = "~{basename(meta_submit_tsv, '.tsv')}-submission.xml"
    }
    runtime {
        cpu:     1
        memory:  "2 GB"
        disks:   "local-disk 50 HDD"
        dx_instance_type: "mem2_ssd1_v2_x2"
        docker:  docker
        maxRetries: 2
    }
}

task biosample_submit_tsv_to_xml {
    input {
        File     meta_submit_tsv
        File     config_js

        String   docker = "quay.io/broadinstitute/ncbi-tools:2.10.7.10"
    }
    meta {
        description: "This converts a web portal submission TSV for NCBI BioSample into an ftp-appropriate XML submission for NCBI BioSample. It does not connect to NCBI, and does not submit or fetch any data."
    }
    command <<<
        set -e
        cd /opt/converter
        cp "~{config_js}" src/config.js
        cp "~{meta_submit_tsv}" files/
        echo "Asymmetrik script version: $ASYMMETRIK_REPO_COMMIT"
        node src/main.js --debug \
            -i=$(basename "~{meta_submit_tsv}") \
            --runTestMode=true
        cd -
        cp "/opt/converter/files/~{basename(meta_submit_tsv, '.tsv')}-submission.xml" .
    >>>
    output {
        File   submission_xml = "~{basename(meta_submit_tsv, '.tsv')}-submission.xml"
    }
    runtime {
        cpu:     1
        memory:  "2 GB"
        disks:   "local-disk 50 HDD"
        dx_instance_type: "mem2_ssd1_v2_x2"
        docker:  docker
        maxRetries: 2
    }
}

task biosample_submit_tsv_ftp_upload {
    input {
        File     meta_submit_tsv
        File     config_js
        String   target_path

        String   docker = "quay.io/broadinstitute/ncbi-tools:2.10.7.10"
    }
    String base=basename(meta_submit_tsv, '.tsv')
    meta {
        description: "This registers a table of metadata with NCBI BioSample. It accepts a TSV similar to the web UI input at submit.ncbi.nlm.nih.gov, but converts to an XML, submits via their FTP/XML API, awaits a response, and retrieves a resulting attributes table and returns that as a TSV. This task registers live data with the production NCBI database."
    }
    command <<<
        # append current date to end of target_path with random string prefacing for testing
        upload_path="~{target_path}/biosample/$(date -I)_$(echo $RANDOM | md5sum | head -c 10)"

        set -e
        cd /opt/converter
        cp "~{config_js}" src/config.js
        cp "~{meta_submit_tsv}" files/
        echo "Asymmetrik script version: $ASYMMETRIK_REPO_COMMIT"
        node src/main.js --debug \
            -i=$(basename "~{meta_submit_tsv}") \
            --uploadFolder="$upload_path" # target directory on FTP server
        cd -
        cp /opt/converter/reports/~{base}-attributes.tsv /opt/converter/files/~{base}-submission.xml /opt/converter/reports/~{base}-report.*.xml .
    >>>
    output {
        File        attributes_tsv = "~{base}-attributes.tsv"
        File        submission_xml = "~{base}-submission.xml"
        Array[File] reports_xmls   = glob("~{base}-report.*.xml")
    }
    runtime {
        cpu:     2
        memory:  "2 GB"
        disks:   "local-disk 100 HDD"
        dx_instance_type: "mem2_ssd1_v2_x2"
        docker:  docker
        maxRetries: 0
    }
}

task biosample_xml_response_to_tsv {
    input {
        File     meta_submit_tsv
        File     ncbi_report_xml

        String   docker = "quay.io/broadinstitute/ncbi-tools:2.10.7.10"
    }
    String out_name = "~{basename(meta_submit_tsv, '.tsv')}-attributes.tsv"
    meta {
        description: "This converts an FTP-based XML response from BioSample into a web-portal-style attributes.tsv file with metadata and accessions. This task does not communicate with NCBI, it only parses pre-retrieved responses."
    }
    command <<<
        set -e
        cd /opt/converter
        cp "~{meta_submit_tsv}" files/submit.tsv
        cp "~{ncbi_report_xml}" reports/report.xml
        echo "Asymmetrik script version: $ASYMMETRIK_REPO_COMMIT"
        node src/main.js --debug \
            -i=submit.tsv \
            -p=report.xml
        cd -
        cp /opt/converter/reports/submit-attributes.tsv "~{out_name}"
    >>>
    output {
        File   biosample_attributes_tsv = "~{out_name}"
    }
    runtime {
        cpu:     2
        memory:  "2 GB"
        disks:   "local-disk 100 HDD"
        dx_instance_type: "mem2_ssd1_v2_x2"
        docker:  docker
        maxRetries: 2
    }
}