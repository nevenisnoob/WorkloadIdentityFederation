resource "google_project_iam_audit_config" "storage_logging" {
  project = "workload-idenity-federation"
  service = "storage.googleapis.com"
  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}
