variable "project_id" {
  type        = string
  description = "GCP project ID"
  default     = "portfolio-472717"
}

variable "project_number" {
  type        = string
  description = "GCP project number. Used to build WIF principalSet member strings."
  default     = "831303094058"
}

variable "github_repo" {
  type        = string
  description = "GitHub repo in 'owner/name' form. Scopes WIF impersonation to this repo only."
  default     = "Riri-Inferno/home-raspi-iac"
}

variable "tfstate_bucket_name" {
  type    = string
  default = "riri-inferno-tfstate"
}

variable "tfstate_bucket_location" {
  type    = string
  default = "asia-northeast1"
}

variable "admin_user_email" {
  type        = string
  description = "Google account allowed to impersonate the App Engine default SA (for local dev / manual ops)."
  default     = "takayo.uenter36@gmail.com"
}

# --- cost-monitor (Phase 1: daily cost summary → Discord) ----------------------

variable "cost_monitor_region" {
  type        = string
  description = "Region for Cloud Functions / Scheduler / source bucket."
  default     = "asia-northeast1"
}

variable "cost_monitor_schedule" {
  type        = string
  description = "Cron expression for the daily cost summary. Default: 09:00 every day."
  default     = "0 9 * * *"
}

variable "cost_monitor_timezone" {
  type        = string
  description = "IANA timezone for the Cloud Scheduler cron."
  default     = "Asia/Tokyo"
}

variable "billing_export_dataset" {
  type        = string
  description = "BigQuery dataset (in this project) that GCP Billing Export writes to. Created here by TF; Billing Export config itself is enabled manually in the GCP console (no TF resource exists)."
  default     = "billing_export"
}

variable "billing_export_table" {
  type        = string
  description = "Table name within billing_export_dataset that GCP populates (e.g. 'gcp_billing_export_v1_XXXXXX_XXXXXX_XXXXXX'). Empty until Billing Export is enabled — the function logs a clear error and skips the query when empty."
  default     = ""
}
