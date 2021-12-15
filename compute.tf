resource "google_compute_instance" "instance" {
  name         = "hrminstance"
  machine_type = "n1-standard-1"
  zone         = "us-west1-a"

  tags = ["cloud", "configuration"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  scratch_disk {
    interface = "SCSI"
  }

  network_interface {
    network = "default"

    access_config {
    }
  }
  service_account {
    scopes = ["userinfo-email", "compute-ro", "storage-ro"]
  }
}

resource "google_compute_network" "network" {
  name = "hrm-network"
}

resource "google_compute_subnetwork" "subnetwork" {
  name          = "hrm-subnet"
  ip_cidr_range = "10.0.0.0/16"
  region        = "us-west1"
  network       = google_compute_network.network.id
}

resource "google_compute_address" "internal_with_subnet_and_address" {
  name         = "hrm-internal-address"
  subnetwork   = google_compute_subnetwork.subnetwork.id
  address_type = "INTERNAL"
  address      = "10.0.42.42"
  region       = "us-west1"
}

resource "google_compute_backend_bucket" "image_backend" {
  name        = "image-backend-bucket"
  description = "Contains ugly images"
  bucket_name = google_storage_bucket.image_bucket.name
  enable_cdn  = true
}

resource "google_storage_bucket" "image_bucket" {
  name     = "hrm-bucket"
  location = "US"
}

resource "google_compute_backend_service" "backend_service" {
  name          = "backend-service"
  health_checks = [google_compute_http_health_check.health.id]
}

resource "google_compute_backend_service" "backend_service2" {
  name          = "backend-service2"
  protocol    = "TCP"
  health_checks = [google_compute_health_check.health_check.id]
}

resource "google_compute_http_health_check" "health" {
  name               = "health-check"
  request_path       = "/"
  check_interval_sec = 1
  timeout_sec        = 1
}

resource "google_compute_https_health_check" "httpshealth" {
  name         = "authentication-health-check"
  request_path = "/health_check"

  timeout_sec        = 1
  check_interval_sec = 1
}

resource "google_compute_autoscaler" "autoscaler" {
  name   = "my-autoscaler"
  zone   = "us-west1-a"
  target = google_compute_instance_group_manager.instance_group_manager.id

  autoscaling_policy {
    max_replicas    = 5
    min_replicas    = 1
    cooldown_period = 60

    cpu_utilization {
      target = 0.5
    }
  }
}

resource "google_compute_instance_template" "template" {
  name           = "hrm-instance-template"
  machine_type   = "n1-standard-1"
  can_ip_forward = false

  tags = ["cloud", "configurations"]

  disk {
    source_image = data.google_compute_image.debian_9.id
  }

  network_interface {
    network = "default"
  }

  service_account {
    scopes = ["userinfo-email", "compute-ro", "storage-ro"]
  }
}

resource "google_compute_target_pool" "target_pool" {
  name = "hrm-target-pool"
}

resource "google_compute_instance_group" "instancegroup" {
  name        = "hrm-instancegroup"
  description = "Terraform test instance group"
  zone        = "us-west1-a"
  network     = google_compute_network.network.id
}

resource "google_compute_instance_group_manager" "instance_group_manager" {
  name = "my-igm"
  zone = "us-west1-a"

  version {
    instance_template  = google_compute_instance_template.template.id
    name               = "primary"
  }

  target_pools       = [google_compute_target_pool.target_pool.id]
  base_instance_name = "default"
}

data "google_compute_image" "debian_9" {
  family  = "debian-9"
  project = "debian-cloud"
}

resource "google_compute_disk" "disk" {
  name  = "hrminstance1"
  type  = "pd-standard"
  zone  = "us-west1-a"
  image = "https://www.googleapis.com/compute/v1/projects/debian-cloud/global/images/debian-9-stretch-v20200910"
  labels = {
    test = "cloud-res"
  }
  physical_block_size_bytes = 4096
}

# resource "google_compute_external_vpn_gateway" "external_gateway" {
#   provider        = google-beta
#   name            = "external-gateway"
#   redundancy_type = "SINGLE_IP_INTERNALLY_REDUNDANT"
#   description     = "An externally managed VPN gateway"
#   interface {
#     id         = 0
#     ip_address = "8.8.8.8"
#   }
# }

resource "google_compute_firewall" "firewall" {
  name    = "hrm-firewall"
  network = google_compute_network.network.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["80", "8080", "1000-2000"]
  }

  source_tags = ["web"]
}

resource "google_compute_health_check" "health_check" {
  name = "hrm-health-check"

  timeout_sec        = 1
  check_interval_sec = 1

  tcp_health_check {
    port = "80"
  }
}

resource "google_compute_health_check" "http_health_check" {
  name = "http-health-check"

  timeout_sec        = 1
  check_interval_sec = 1

  http_health_check {
    port = "80"
  }
}

resource "google_compute_region_backend_service" "region_backend_service" {
  name                  = "region-backend"
  region                = "us-west1"
  protocol              = "TCP"
  health_checks         = [google_compute_health_check.http_health_check.id]
}

resource "google_compute_forwarding_rule" "forwarding_rule" {
  name                  = "hrm-forwarding-rule"
  region                = "us-west1"
  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.region_backend_service.id
  all_ports             = true
  allow_global_access   = true
  network               = google_compute_network.network.name
  subnetwork            = google_compute_subnetwork.subnetwork.name
}

resource "google_compute_global_address" "global_address" {
  name = "global-appserver-ip"
}

# resource "google_compute_global_forwarding_rule" "global_forwarding_rule" {
#   name       = "global-rule"
#   target     = google_compute_target_http_proxy.target_proxy.id
#   port_range = "80"
# }

# resource "google_compute_target_http_proxy" "target_proxy" {
#   name        = "target-proxy"
#   description = "a description"
#   url_map     = google_compute_url_map.url_map.id
# }

# resource "google_compute_url_map" "url_map" {
#   name            = "url-map-target-proxy"
#   description     = "a description"
#   default_service = google_compute_backend_service.backend_service.id

#   host_rule {
#     hosts        = ["mysite.com"]
#     path_matcher = "allpaths"
#   }

#   path_matcher {
#     name            = "allpaths"
#     default_service = google_compute_backend_service.backend_service.id

#     path_rule {
#       paths   = ["/*"]
#       service = google_compute_backend_service.backend_service.id
#     }
#   }
# }

# resource "google_compute_interconnect_attachment" "interconnect_attachment" {
#   name         = "on-prem-attachment"
#   interconnect = "http://www.example.com/index.html"
#   router       = google_compute_router.router.id
# }

resource "google_compute_router" "router" {
  name    = "router"
  network = google_compute_network.network.name
}

resource "google_compute_network_endpoint_group" "neg" {
  name         = "my-lb-neg"
  network      = google_compute_network.network.id
  subnetwork   = google_compute_subnetwork.subnetwork.id
  default_port = "90"
  zone         = "us-west1-a"
}

resource "google_compute_node_template" "soletenant_tmpl" {
  name      = "soletenant-tmpl"
  region    = "us-west1"
  node_type = "n1-node-96-624"
}

# resource "google_compute_node_group" "nodes" {
#   name        = "soletenant-group"
#   zone        = "us-central1-a"
#   description = "example google_compute_node_group for Terraform Google Provider"
#   size          = 1
#   node_template = google_compute_node_template.soletenant_tmpl.id
# }

resource "google_compute_region_instance_group_manager" "region_instance_group_manager" {
  name   = "my-region-igm"
  region = "us-west1"

  version {
    instance_template  = google_compute_instance_template.template.id
    name               = "primary"
  }

  target_pools       = [google_compute_target_pool.target_pool.id]
  base_instance_name = "hrm"
}

resource "google_compute_region_autoscaler" "region_autoscaler" {
  name   = "my-region-autoscaler"
  region = "us-west1"
  target = google_compute_region_instance_group_manager.region_instance_group_manager.id

  autoscaling_policy {
    max_replicas    = 5
    min_replicas    = 1
    cooldown_period = 60

    cpu_utilization {
      target = 0.5
    }
  }
}

resource "google_compute_snapshot" "snapdisk" {
  name        = "hrm-snapshot"
  source_disk = google_compute_disk.disk.name
  zone        = "us-west1-a"
}

resource "google_compute_region_disk" "region_disk" {
  name                      = "hrm-region-disk"
  snapshot                  = google_compute_snapshot.snapdisk.id
  type                      = "pd-ssd"
  region                    = "us-west1"
  physical_block_size_bytes = 4096

  replica_zones = ["us-west1-a", "us-west1-b"]
}

resource "google_compute_region_health_check" "tcp-region-health-check" {
  name     = "tcp-region-health-check"

  timeout_sec        = 1
  check_interval_sec = 1

  tcp_health_check {
    port = "80"
  }
}

resource "google_compute_region_backend_service" "http_region_backend_service" {
  name                  = "http-region-backend"
  region                = "us-west1"
  protocol              = "HTTP"
  health_checks         = [google_compute_health_check.http_health_check.id]
}

# resource "google_compute_region_url_map" "region_url_map" {
#   region      = "us-west1"
#   name        = "url-map"
#   description = "a description"

#   default_service = google_compute_region_backend_service.http_region_backend_service.id
# }

# resource "google_compute_region_ssl_certificate" "ssl_certificate" {
#   region      = "us-west1"
#   name_prefix = "hrm-certificate-"
#   description = "a description"
#   private_key = file("path/to/private.key")
#   certificate = file("path/to/certificate.crt")

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# resource "google_compute_region_target_https_proxy" "https_proxy" {
#   region           = "us-west1"
#   name             = "https-proxy"
#   url_map          = google_compute_region_url_map.region_url_map.id
#   ssl_certificates = [google_compute_region_ssl_certificate.ssl_certificate.id]
# }

# resource "google_compute_region_target_http_proxy" "http_proxy" {
#   region           = "us-west1"
#   name             = "http-proxy"
#   url_map          = google_compute_region_url_map.region_url_map.id
#   ssl_certificates = [google_compute_region_ssl_certificate.ssl_certificate.id]
# }

# resource "google_compute_target_ssl_proxy" "default" {
#   name             = "test-proxy"
#   backend_service  = google_compute_backend_service.default.id
#   ssl_certificates = [google_compute_ssl_certificate.default.id]
# }

resource "google_compute_reservation" "gce_reservation" {
  name = "gce-reservation"
  zone = "us-west1-a"

  specific_reservation {
    count = 1
    instance_properties {
      min_cpu_platform = "Intel Cascade Lake"
      machine_type     = "n2-standard-2"
    }
  }
}

resource "google_compute_resource_policy" "resource_policy" {
  name   = "policy"
  region = "us-west1"
  snapshot_schedule_policy {
    schedule {
      daily_schedule {
        days_in_cycle = 1
        start_time    = "04:00"
      }
    }
  }
}

resource "google_compute_route" "compute_route" {
  name        = "network-route"
  dest_range  = "15.0.0.0/24"
  network     = google_compute_network.network.name
  next_hop_ip = "10.132.1.5"
  priority    = 100
}

resource "google_compute_security_policy" "security_policy" {
  name = "hrm-policy"

  rule {
    action   = "deny(403)"
    priority = "1000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["9.9.9.0/24"]
      }
    }
    description = "Deny access to IPs in 9.9.9.0/24"
  }

  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "default rule"
  }
}

resource "google_compute_ssl_policy" "custom-ssl-policy" {
  name            = "hrm-custom-ssl-policy"
  min_tls_version = "TLS_1_2"
  profile         = "CUSTOM"
  custom_features = ["TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384", "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"]
}

resource "google_compute_target_instance" "target_instance" {
  name     = "target"
  instance = google_compute_instance.instance.id
  zone         = "us-west1-a"
}

resource "google_compute_target_tcp_proxy" "tcp_proxy" {
  name            = "hrm-proxy"
  backend_service = google_compute_backend_service.backend_service2.id
}

resource "google_compute_vpn_gateway" "target_gateway" {
  name    = "vpn1"
  network = google_compute_network.network.id
}

resource "google_compute_vpn_tunnel" "tunnel1" {
  name          = "tunnel1"
  peer_ip       = "15.0.0.120"
  shared_secret = "a secret message"
  local_traffic_selector = ["192.168.0.0/16"]

  target_vpn_gateway = google_compute_vpn_gateway.target_gateway2.id

  depends_on = [
    google_compute_forwarding_rule.fr_esp,
    google_compute_forwarding_rule.fr_udp500,
    google_compute_forwarding_rule.fr_udp4500,
  ]
}

resource "google_compute_vpn_gateway" "target_gateway2" {
  name    = "vpn2"
  network = google_compute_network.network.id
}

resource "google_compute_address" "vpn_static_ip" {
  name = "vpn-static-ip"
}

resource "google_compute_forwarding_rule" "fr_esp" {
  name        = "fr-esp"
  ip_protocol = "ESP"
  ip_address  = google_compute_address.vpn_static_ip.address
  target      = google_compute_vpn_gateway.target_gateway2.id
}

resource "google_compute_forwarding_rule" "fr_udp500" {
  name        = "fr-udp500"
  ip_protocol = "UDP"
  port_range  = "500"
  ip_address  = google_compute_address.vpn_static_ip.address
  target      = google_compute_vpn_gateway.target_gateway2.id
}

resource "google_compute_forwarding_rule" "fr_udp4500" {
  name        = "fr-udp4500"
  ip_protocol = "UDP"
  port_range  = "4500"
  ip_address  = google_compute_address.vpn_static_ip.address
  target      = google_compute_vpn_gateway.target_gateway2.id
}

resource "google_compute_route" "route1" {
  name       = "route1"
  network    = google_compute_network.network.name
  dest_range = "15.0.0.0/24"
  priority   = 1000

  next_hop_vpn_tunnel = google_compute_vpn_tunnel.tunnel1.id
}