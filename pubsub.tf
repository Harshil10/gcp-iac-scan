resource "google_pubsub_topic" "pubsub" {
  name = "hrm-topic"
}

resource "google_pubsub_subscription" "pubsub" {
  name  = "hrm-subscription"
  topic = google_pubsub_topic.pubsub.name

  ack_deadline_seconds = 20

  labels = {
    test = "tag_drift"
  }

#   push_config {
#     push_endpoint = "https://example.com/push"

#     attributes = {
#       x-goog-version = "v1"
#     }
#   }
}