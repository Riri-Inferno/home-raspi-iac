terraform {
  backend "gcs" {
    bucket = "riri-inferno-tfstate"
    prefix = "gcp"
  }
}
