# cost-monitor (Phase 1): daily GCP cost summary → Discord webhook.
#
# Trigger chain:
#   Cloud Scheduler (cron)
#     → Pub/Sub topic (cost-monitor-daily)
#       → Cloud Functions Gen 2 (cost-monitor)
#         → BigQuery (billing_export.<table>)
#         → Secret Manager (discord-webhook-cost-monitor)  ← URL
#         → Discord webhook (POST embed)
#
# Manual one-off setup outside Terraform (no TF resource exists for billing
# export config itself, only the receiving dataset):
#   1) GCP Console → Billing → Billing export → BigQuery export →
#      Detailed usage cost, dataset = google_bigquery_dataset.billing_export.
#   2) Update terraform/gcp/variables.tf billing_export_table with the table
#      name GCP auto-creates (gcp_billing_export_v1_<billing_account_id>).
#   3) Add a version to google_secret_manager_secret.discord_webhook_cost_monitor
#      with the Discord webhook URL:
#        echo -n "<URL>" | gcloud secrets versions add discord-webhook-cost-monitor \
#          --project=portfolio-472717 --data-file=-

# --- BigQuery dataset (receives billing export) -------------------------------
# Created here so the dataset is IaC-managed and IAM can target it precisely.
# The Billing Export config in GCP must be pointed at this dataset (manual step).
resource "google_bigquery_dataset" "billing_export" {
  dataset_id = var.billing_export_dataset
  location   = "US" # Billing export defaults to US multi-region; match to avoid cross-region pain.

  description = "GCP Billing Export sink. Populated by Cloud Billing → BigQuery export (configured manually in GCP Console)."

  # Billing export tables hold raw cost history — don't auto-delete.
  delete_contents_on_destroy = false

  depends_on = [google_project_service.required]
}

# --- Service account for the function ----------------------------------------
resource "google_service_account" "cost_monitor" {
  account_id   = "cost-monitor"
  display_name = "Cost Monitor (daily Discord summary)"
}

# Read billing export tables.
resource "google_bigquery_dataset_iam_member" "cost_monitor_data_viewer" {
  dataset_id = google_bigquery_dataset.billing_export.dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.cost_monitor.email}"
}

# Run BigQuery jobs (project-level requirement, dataset-level dataViewer is not enough).
resource "google_project_iam_member" "cost_monitor_bq_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.cost_monitor.email}"
}

# Read the Discord webhook URL secret.
resource "google_secret_manager_secret_iam_member" "cost_monitor_secret_accessor" {
  secret_id = google_secret_manager_secret.discord_webhook_cost_monitor.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cost_monitor.email}"
}

# --- Discord webhook secret (value populated out-of-band) ---------------------
# Only the secret container is in Terraform. The actual URL is added as a
# secret version manually (`gcloud secrets versions add ...`) so the value
# never appears in Git or in tfstate.
resource "google_secret_manager_secret" "discord_webhook_cost_monitor" {
  secret_id = "discord-webhook-cost-monitor"

  replication {
    auto {}
  }

  depends_on = [google_project_service.required]
}

# --- Pub/Sub topic (Scheduler → Function fanout) -----------------------------
resource "google_pubsub_topic" "cost_monitor_daily" {
  name = "cost-monitor-daily"

  depends_on = [google_project_service.required]
}

# --- Source bucket + zipped function code ------------------------------------
resource "google_storage_bucket" "functions_src" {
  name     = "riri-inferno-functions-src"
  location = var.cost_monitor_region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Old versions of the zip pile up on every deploy; expire them.
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.required]
}

data "archive_file" "cost_monitor_src" {
  type        = "zip"
  source_dir  = "${path.module}/../../gcp-functions/cost-monitor"
  output_path = "${path.module}/.build/cost_monitor.zip"
}

# Object name embeds the source hash so any code change forces a new upload
# and the function picks it up via source.storage_source.object.
resource "google_storage_bucket_object" "cost_monitor_src" {
  name   = "cost-monitor/${data.archive_file.cost_monitor_src.output_sha256}.zip"
  bucket = google_storage_bucket.functions_src.name
  source = data.archive_file.cost_monitor_src.output_path
}

# --- Cloud Functions Gen 2 ---------------------------------------------------
resource "google_cloudfunctions2_function" "cost_monitor" {
  name     = "cost-monitor"
  location = var.cost_monitor_region

  build_config {
    runtime     = "python313"
    entry_point = "main"
    source {
      storage_source {
        bucket = google_storage_bucket.functions_src.name
        object = google_storage_bucket_object.cost_monitor_src.name
      }
    }
  }

  service_config {
    max_instance_count    = 1
    available_memory      = "256M"
    timeout_seconds       = 120
    service_account_email = google_service_account.cost_monitor.email

    environment_variables = {
      PROJECT_ID             = var.project_id
      BILLING_DATASET        = var.billing_export_dataset
      BILLING_TABLE          = var.billing_export_table
      DISCORD_WEBHOOK_SECRET = "${google_secret_manager_secret.discord_webhook_cost_monitor.id}/versions/latest"
      REPORT_TIMEZONE        = var.cost_monitor_timezone
    }
  }

  event_trigger {
    trigger_region        = var.cost_monitor_region
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic          = google_pubsub_topic.cost_monitor_daily.id
    retry_policy          = "RETRY_POLICY_DO_NOT_RETRY"
    service_account_email = google_service_account.cost_monitor.email
  }

  depends_on = [
    google_project_service.required,
    google_project_iam_member.cost_monitor_bq_job_user,
    google_project_iam_member.cost_monitor_eventarc_receiver,
  ]
}

# Gen 2 functions run as Cloud Run services. The Eventarc trigger uses the
# function SA to invoke the underlying run service, so grant it run.invoker
# on the function and eventarc.eventReceiver on the project.
resource "google_cloud_run_service_iam_member" "cost_monitor_invoker" {
  location = google_cloudfunctions2_function.cost_monitor.location
  service  = google_cloudfunctions2_function.cost_monitor.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.cost_monitor.email}"
}

resource "google_project_iam_member" "cost_monitor_eventarc_receiver" {
  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.cost_monitor.email}"
}

# Pub/Sub service agent mints auth tokens for push delivery → Cloud Run.
# Auto-granted on most projects, but explicit binding avoids first-deploy
# 403s on projects where the implicit grant never happened.
resource "google_project_iam_member" "pubsub_token_creator" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:service-${var.project_number}@gcp-sa-pubsub.iam.gserviceaccount.com"

  depends_on = [google_project_service.required]
}

# --- Cloud Scheduler (daily trigger) -----------------------------------------
resource "google_cloud_scheduler_job" "cost_monitor_daily" {
  name      = "cost-monitor-daily"
  region    = var.cost_monitor_region
  schedule  = var.cost_monitor_schedule
  time_zone = var.cost_monitor_timezone

  pubsub_target {
    topic_name = google_pubsub_topic.cost_monitor_daily.id
    # Payload is unused by the function but Pub/Sub requires a non-empty body.
    data = base64encode(jsonencode({ trigger = "scheduled" }))
  }

  depends_on = [google_project_service.required]
}
