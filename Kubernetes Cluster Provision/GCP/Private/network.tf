provider "google" {
  project     = "my-project-id"
  region      = "us-central1"
}

resource "google_compute_network" "vpc_network" {
  project                      = "ds-team-384807"
  name                         = "katonic-tf-vpc"
  auto_create_subnetworks      = false
  mtu                          = 1460
  routing_mode                 = "REGIONAL"
}

resource "google_compute_subnetwork" "katonic_subnet" {
  name                         = "katonic-tf-subnet"
  ip_cidr_range                = "10.140.0.0/20"
  region                       = "us-east1"
  network                      = google_compute_network.vpc_network.id
  private_ip_google_access     = true
  stack_type                   = "IPV4_ONLY"
}

resource "google_compute_router" "my-router" {
  name                          = "katonic-tf-router" 
  network                       = google_compute_network.vpc_network.name
  region                        = google_compute_subnetwork.katonic_subnet.region
  encrypted_interconnect_router = true
  bgp {
    asn = 64514
  }    
}


resource "google_compute_router_nat" "nat" {
  name                               = "katonic-tf-cloud-nat"
  router                             = google_compute_router.my-router.name
  region                             = google_compute_router.my-router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

}

