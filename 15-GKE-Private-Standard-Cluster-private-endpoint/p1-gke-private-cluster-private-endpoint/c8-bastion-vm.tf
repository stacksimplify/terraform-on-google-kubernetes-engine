# Resource Block: Reserver Internal IP Address for Bastion Host
resource "google_compute_address" "bastion_internal_ip" {
  name         = "${local.name}-bastion-internal-ip"
  description  = "Internal IP address reserved for Bastion VM"
  address_type = "INTERNAL"
  region       = var.gcp_region1
  subnetwork   = google_compute_subnetwork.mysubnet.id 
  address      = "10.128.15.15"  # Use subnet slicer to understand better https://www.davidc.net/sites/default/subnets/subnets.html
}

# COPY FROM terraform-on-google-kubernetes-engine/03-Terraform-Language-Basics/terraform-manifests/c5-vminstance.tf and Update as needed
# Resource Block: Create a single Compute Engine instance
resource "google_compute_instance" "bastion" {
  name         = "${local.name}-bastion-vm"
  machine_type = var.machine_type
  zone         = "us-central1-a"
  tags        = [tolist(google_compute_firewall.fw_ssh.target_tags)[0]]
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.mysubnet.id 
    network_ip = google_compute_address.bastion_internal_ip.address
  }
  metadata_startup_script = <<-EOT
      #!/bin/bash
      sudo apt update
      sudo apt install -y telnet
      sudo apt-get install -y kubectl
      sudo apt-get install -y google-cloud-sdk-gke-gcloud-auth-plugin
      sudo apt update
      sudo apt install -y gnupg software-properties-common
      curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
      sudo apt update
      sudo apt install -y terraform
    EOT
}

