resource "google_monitoring_alert_policy" "alert_policy" {
  display_name = "hrm Alert Policy"
  combiner     = "OR"
  conditions {
    display_name = "test condition"
    condition_threshold {
      filter     = "metric.type=\"compute.googleapis.com/instance/disk/write_bytes_count\" AND resource.type=\"gce_instance\""
      duration   = "60s"
      comparison = "COMPARISON_GT"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }
}

resource "google_monitoring_group" "parent" {
  display_name = "MonitoringParentGroup"
  filter       = "resource.metadata.region=\"us-west1\""
}

resource "google_monitoring_group" "subgroup" {
  display_name = "MonitoringSubGroup"
  filter       = "resource.metadata.region=\"us-west1\""
  parent_name  =  google_monitoring_group.parent.name
}

resource "google_monitoring_notification_channel" "basic" {
  display_name = "hrm Notification Channel"
  type         = "email"

  labels = {
    email_address = "hrm@local.com"
  }
}

resource "google_monitoring_uptime_check_config" "http" {
  display_name = "http-uptime-check"
  timeout      = "60s"

  tcp_check {
    port = 888
  }

  resource_group {
    resource_type = "INSTANCE"
    group_id      = google_monitoring_group.parent.name
  }

#   content_matchers {
#     content = "example"
#   }
}