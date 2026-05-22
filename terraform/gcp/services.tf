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
    "cloudfunctions.googleapis.com",       # Cloud Functions Gen 2 (cost-monitor)
    "run.googleapis.com",                  # Gen 2 functions execute on Cloud Run under the hood
    "cloudbuild.googleapis.com",           # Build the function container image
    "artifactregistry.googleapis.com",     # Built images are stored in Artifact Registry
    "eventarc.googleapis.com",             # Pub/Sub → Function trigger plumbing
    "pubsub.googleapis.com",               # Scheduler → Function fan-out topic
    "cloudscheduler.googleapis.com",       # Daily cron that fires the cost-monitor
    "secretmanager.googleapis.com",        # Discord webhook URL storage
    "bigquery.googleapis.com",             # Billing export dataset + query target
    "billingbudgets.googleapis.com",       # Cloud Billing Budget (cost-alert Phase 2)
    "cloudbilling.googleapis.com",         # Billing account IAM (google_billing_account_iam_member)
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
