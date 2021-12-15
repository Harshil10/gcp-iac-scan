resource "google_storage_bucket" "image_store" {
  name     = "hrm-storage-bucket"
  location = "US"
}

# resource "google_storage_bucket_acl" "image-store-acl" {
#   bucket = google_storage_bucket.image_store.name

#   role_entity = [
#     "OWNER:user-hrm@local.com",
#     "OWNER:project-hrms-project-290520",
#     "OWNER:allUsers"
#     # "READER:group-mygroup",
#   ]
# }

# resource "google_storage_bucket_iam_binding" "binding" {
#   bucket = google_storage_bucket.image_store.name
#   role = "roles/storage.admin"
#   members = [
#     "user:hrm@local.com",
#   ]
# }

resource "google_container_registry" "registry" {
#   project  = "hrms-project-290520"
  location = "US"
}

resource "google_storage_bucket_iam_member" "viewer" {
  bucket = google_container_registry.registry.id
  role = "roles/storage.objectViewer"
  member = "user:hrm@local.com"
}

data "google_iam_policy" "admin" {
  binding {
    role = "roles/storage.admin"
    members = [
      "user:hrm@local.com",
    ]
  }
}

resource "google_storage_bucket_iam_policy" "policy" {
  bucket = google_storage_bucket.image_store.name
  policy_data = data.google_iam_policy.admin.policy_data
}

resource "google_storage_default_object_acl" "image-store-default-acl" {
  bucket = google_storage_bucket.image_store.name
  role_entity = [
    "OWNER:user-hrm@local.com",
    # "READER:group-mygroup",
  ]
}

resource "google_storage_bucket" "backup_bucket" {
  name          = "hrm-backup"
  storage_class = "NEARLINE"
}

# resource "google_storage_transfer_job" "s3-bucket-nightly-backup" {
#   description = "Nightly backup of S3 bucket"

#   transfer_spec {
#     object_conditions {
#       max_time_elapsed_since_last_modification = "600s"
#       exclude_prefixes = [
#         "requests.gz",
#       ]
#     }
#     transfer_options {
#       delete_objects_unique_in_sink = false
#     }

#     aws_s3_data_source {
#       bucket_name = var.aws_s3_bucket
#       aws_access_key {
#         access_key_id     = var.aws_access_key
#         secret_access_key = var.aws_secret_key
#       }
#     }
    
#     gcs_data_sink {
#       bucket_name = google_storage_bucket.image_store.name
#     }
#   }

#   schedule {
#     schedule_start_date {
#       year  = 2018
#       month = 10
#       day   = 1
#     }
#     schedule_end_date {
#       year  = 2019
#       month = 1
#       day   = 15
#     }
#     start_time_of_day {
#       hours   = 23
#       minutes = 30
#       seconds = 0
#       nanos   = 0
#     }
#   }

#   depends_on = [google_storage_bucket_iam_member.viewer]
# }