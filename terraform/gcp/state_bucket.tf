resource "google_storage_bucket" "tfstate" {
  name     = var.tfstate_bucket_name
  location = var.tfstate_bucket_location

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  force_destroy = false
}
