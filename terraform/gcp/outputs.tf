output "tfstate_bucket" {
  value       = google_storage_bucket.tfstate.name
  description = "GCS bucket holding terraform state for this repo"
}

output "github_actions_wif_provider" {
  value       = "projects/${var.project_number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.main.workload_identity_pool_id}/providers/${google_iam_workload_identity_pool_provider.github_actions.workload_identity_pool_provider_id}"
  description = "Full WIF provider resource path. Pass as workload_identity_provider to google-github-actions/auth in workflows."
}

output "terraform_state_sa_email" {
  value       = google_service_account.terraform_state.email
  description = "SA that GitHub Actions impersonates for state read/write"
}
