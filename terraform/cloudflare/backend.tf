terraform {
  backend "gcs" {
    bucket = "riri-inferno-tfstate"
    prefix = "cloudflare"
  }
}
