# Firewall Rule: SSH
resource "google_compute_firewall" "fw_ssh" {
  name = "${local.name}-fwrule-allow-ssh22"
  allow {
    ports    = ["22"]
    protocol = "tcp"
  }
  direction     = "INGRESS"
  network       = google_compute_network.myvpc.id 
  priority      = 1000
  #source_ranges = ["0.0.0.0/0"]
  source_ranges = ["35.235.240.0/20"] # IAP IP Range
  target_tags   = ["ssh-tag"]
}

# 1. Allows ingress traffic from the IP range 35.235.240.0/20
# 2. This range contains all IP addresses that IAP uses for TCP forwarding.
# 3. Allows connections to port 22 that you want to be accessible by using IAP TCP forwarding.
