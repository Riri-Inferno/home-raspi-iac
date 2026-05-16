# Pool is shared between kakeibo (k3s OIDC) and CI (GitHub Actions OIDC).
# Originally created out-of-band for kakeibo backend; the github-actions provider
# was added when this terraform module was bootstrapped.
resource "google_iam_workload_identity_pool" "main" {
  workload_identity_pool_id = "kakeibo-pool"
  display_name              = "Kakeibo k3s Pool"
}

resource "google_iam_workload_identity_pool_provider" "k3s" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.main.workload_identity_pool_id
  workload_identity_pool_provider_id = "kakeibo-k3s"
  display_name                       = "Kakeibo k3s OIDC"

  # Pins token to a specific k8s namespace + service account.
  # Removing this widens trust to any pod in the cluster — keep.
  attribute_condition = "assertion['kubernetes.io']['namespace']=='kakeibo' && assertion['kubernetes.io']['serviceaccount']['name']=='kakeibo-backend'"

  attribute_mapping = {
    "google.subject"           = "assertion.sub"
    "attribute.namespace"      = "assertion['kubernetes.io']['namespace']"
    "attribute.serviceaccount" = "assertion['kubernetes.io']['serviceaccount']['name']"
  }

  oidc {
    issuer_uri = "https://oidc.riri-inferno.com/"
  }
}

resource "google_iam_workload_identity_pool_provider" "github_actions" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.main.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-actions"
  display_name                       = "GitHub Actions"

  attribute_condition = "assertion.repository == '${var.github_repo}'"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}
