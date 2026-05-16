resource "google_service_account" "terraform_state" {
  account_id   = "terraform-state"
  display_name = "Terraform State (GitHub Actions)"
}

resource "google_storage_bucket_iam_member" "terraform_state_object_admin" {
  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.terraform_state.email}"
}

resource "google_service_account_iam_member" "terraform_state_wif" {
  service_account_id = google_service_account.terraform_state.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${var.project_number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.main.workload_identity_pool_id}/attribute.repository/${var.github_repo}"
}
