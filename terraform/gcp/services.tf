# Project services (API enablements) required for Terraform to operate.
# Each Google API the provider touches must be enabled before resources of
# that API can be managed. Enabling these idempotently from Terraform avoids
# silent breakage on cluster rebuild / fresh project setup.
locals {
  required_services = toset([
    "cloudresourcemanager.googleapis.com", # google_project_iam_member.* read/write project IAM policy
    "iam.googleapis.com",                  # service accounts, custom roles
    "iamcredentials.googleapis.com",       # impersonation (generateAccessToken)
    "sts.googleapis.com",                  # WIF token exchange
    "storage.googleapis.com",              # GCS buckets (state backend, etc.)
    "serviceusage.googleapis.com",         # enable/disable other services
  ])
}

resource "google_project_service" "required" {
  for_each = local.required_services
  project  = var.project_id
  service  = each.value

  # API を Terraform destroy で消されると、その後の運用で破滅的に詰むので保護。
  # 個別 API を外したい時は disable_on_destroy を一時的に true にして apply、もしくは手動 disable。
  disable_on_destroy = false
}
