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

# App Engine default SA (GCP auto-created on App Engine API enablement).
# Lifecycle is GCP-managed; we only manage IAM bindings on it.
# Email domain is appspot.gserviceaccount.com (NOT iam.gserviceaccount.com),
# so google_service_account data source can't lookup by account_id alone.
locals {
  appspot_sa_name = "projects/${var.project_id}/serviceAccounts/${var.project_id}@appspot.gserviceaccount.com"
}

# kakeibo-backend pod (k8s SA: kakeibo/kakeibo-backend) is allowed to
# impersonate the appspot SA via WIF. Scoped to the specific subject claim,
# not the broader namespace/repository attribute — narrowest possible.
resource "google_service_account_iam_member" "appspot_kakeibo_k3s" {
  service_account_id = local.appspot_sa_name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/projects/${var.project_number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.main.workload_identity_pool_id}/subject/system:serviceaccount:kakeibo:kakeibo-backend"
}

# Personal admin grant: lets user impersonate appspot SA via
# `gcloud --impersonate-service-account` for local dev / manual ops.
resource "google_service_account_iam_member" "appspot_user_token_creator" {
  service_account_id = local.appspot_sa_name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "user:${var.admin_user_email}"
}

# Project-level roles needed for Terraform to manage GCP resources.
# Granted to terraform-state SA so CI (and local) plan/apply work.

resource "google_project_iam_member" "terraform_state_sa_admin" {
  project = var.project_id
  role    = "roles/iam.serviceAccountAdmin"
  member  = "serviceAccount:${google_service_account.terraform_state.email}"
}

resource "google_project_iam_member" "terraform_state_wif_admin" {
  project = var.project_id
  role    = "roles/iam.workloadIdentityPoolAdmin"
  member  = "serviceAccount:${google_service_account.terraform_state.email}"
}

# Broad write access across resource types. Defense-in-depth で role を細かく分けるより、
# WIF Provider 側の attribute_condition（repo pin）+ SA 側 IAM binding（repo pin）の
# impersonation gate を境界線として運用する方針。IAM 管理は editor に含まれないため、
# projectIamAdmin / serviceAccountAdmin / workloadIdentityPoolAdmin は別途必要。
resource "google_project_iam_member" "terraform_state_editor" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.terraform_state.email}"
}

resource "google_storage_bucket_iam_member" "terraform_state_bucket_admin" {
  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.terraform_state.email}"
}

# Allow terraform-state SA to read/write project IAM policy itself.
# Required by google_project_iam_member.* refresh / apply (calls resourcemanager.projects.{get,set}IamPolicy).
resource "google_project_iam_member" "terraform_state_project_iam_admin" {
  project = var.project_id
  role    = "roles/resourcemanager.projectIamAdmin"
  member  = "serviceAccount:${google_service_account.terraform_state.email}"
}

# Allow terraform-state SA to use enabled services (call API endpoints) — most service
# accounts need this explicitly when the API call's quota consumer is the same project.
resource "google_project_iam_member" "terraform_state_service_usage_consumer" {
  project = var.project_id
  role    = "roles/serviceusage.serviceUsageConsumer"
  member  = "serviceAccount:${google_service_account.terraform_state.email}"
}
