resource "google_project_iam_custom_role" "terraform-ci" {
  title       = "TerraformCI"
  role_id     = "Terraform CI Custom Role"
  description = "TerraformCIのCustomRole"
  stage       = "ALPHA"
  permissions = [
    "resourcemanager.projects.getIamPolicy",
  ]
}

resource "google_project_iam_member" "terraform-role" {
  project = local.project_id
  role    = google_project_iam_custom_role.terraform-ci.id
  member  = "serviceAccount:${data.google_service_account.terraform-sa.email}"
}


resource "google_project_iam_audit_config" "enable_gcs_logging" {
  project = var.project_id
  service = "storage.googleapis.com"
  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

resource "google_monitoring_alert_policy" "alert_gcs_with_call_ip" {
  display_name = "GCS Caller IP Alert"
  combiner     = "OR"
  conditions {
    condition_matched_log {
      filter = join("", [
        "resource.type=gcs_bucket AND ",
        "(protoPayload.authorizationInfo.permission = \"storage.objects.get\" OR ",
        "protoPayload.authorizationInfo.permission = \"storage.objects.update\" OR ",
        "protoPayload.authorizationInfo.permission = \"storage.objects.create\" OR ",
        "protoPayload.authorizationInfo.permission = \"storage.objects.delete\") AND ",
        "NOT (",
        "${join(" OR ", formatlist("ip_in_net(protoPayload.requestMetadata.callerIp, \"%s\")", var.valid_caller_ips))}",
        ")",
      ])
    }
    display_name = "GCS Caller IP Alert"
  }
  enabled               = true
  project               = local.project_id
  notification_channels = [data.google_monitoring_notification_channel.gcs_unknown_access_notify_channel.id]
  alert_strategy {
    auto_close = "604800s" #Incident autoclose duration: 7d

    notification_rate_limit {
      period = "86400s" #  One notification per 1 day
    }
  }
}

data "google_monitoring_notification_channel" "gcs_unknown_access_notify_channel" {
  display_name = "Unexpected GCS Accessing"
}
