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
