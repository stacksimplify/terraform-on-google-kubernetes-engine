resource "google_service_account" "gke_sa" {
  account_id   = "${local.name}-gke-sa"
  display_name = "${local.name} GKE Service Account"
}