# cost-alert (Phase 2): Cloud Billing Budget threshold notifications → Discord.
#
# Trigger chain:
#   Cloud Billing Budget × 2 (free-tier-exceeded ¥1, monthly-spend-cap ¥1000)
#     → Pub/Sub topic (cost-alert)
#       → Cloud Functions Gen 2 (cost-alert)
#         → Secret Manager (discord-webhook-cost-monitor)  ← reused from Phase 1
#         → Discord webhook (POST embed + @everyone mention on warn/crit)
#
# Dry-run: publish a fake payload with `"_test": true`. The function prefixes
# title with "[TEST]" and skips the @everyone mention.
#
#   gcloud pubsub topics publish cost-alert \
#     --project=portfolio-472717 \
#     --message='{"budgetDisplayName":"free-tier-exceeded","alertThresholdExceeded":1.0,"costAmount":2.5,"budgetAmount":1.0,"currencyCode":"JPY","_test":true}'

# --- Service account for the function ----------------------------------------
resource "google_service_account" "cost_alert" {
  account_id   = "cost-alert"
  display_name = "Cost Alert (Budget threshold → Discord)"
}

# Reuse the existing Discord webhook secret from Phase 1.
resource "google_secret_manager_secret_iam_member" "cost_alert_secret_accessor" {
  secret_id = google_secret_manager_secret.discord_webhook_cost_monitor.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cost_alert.email}"

  depends_on = [google_project_iam_member.terraform_state_secretmanager_admin]
}

# --- Pub/Sub topic (Budget notifications fan-in) -----------------------------
resource "google_pubsub_topic" "cost_alert" {
  name = "cost-alert"

  depends_on = [google_project_service.required]
}

# GCP claims that the billing-budgets service principal manages its own
# permissions on the topic since 2022, so this binding may be redundant.
# Granting it defensively to avoid first-fire 403 if the auto-grant fails.
resource "google_pubsub_topic_iam_member" "billing_budget_publisher" {
  topic  = google_pubsub_topic.cost_alert.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:billing-budgets@system.gserviceaccount.com"

  depends_on = [google_project_iam_member.terraform_state_pubsub_admin]
}

# --- Cloud Billing Budgets ---------------------------------------------------
# Budget 1: free-tier exceeded — fires when net spend > ¥1 (≈ free tier broken).
# Scope: omit budget_filter → billing account-wide (covers all projects under
# the billing account, matching the "future multi-project" requirement).
resource "google_billing_budget" "free_tier_exceeded" {
  billing_account = var.billing_account_id
  display_name    = "free-tier-exceeded"

  amount {
    specified_amount {
      currency_code = "JPY"
      units         = tostring(var.cost_alert_free_tier_budget_jpy)
    }
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "CURRENT_SPEND"
  }

  all_updates_rule {
    pubsub_topic   = google_pubsub_topic.cost_alert.id
    schema_version = "1.0"
  }

  depends_on = [google_billing_account_iam_member.terraform_state_billing_admin]
}

# Budget 2: monthly spend cap — info/warn/crit at 50/80/100%.
resource "google_billing_budget" "monthly_spend_cap" {
  billing_account = var.billing_account_id
  display_name    = "monthly-spend-cap"

  amount {
    specified_amount {
      currency_code = "JPY"
      units         = tostring(var.cost_alert_critical_budget_jpy)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
    spend_basis       = "CURRENT_SPEND"
  }
  threshold_rules {
    threshold_percent = 0.8
    spend_basis       = "CURRENT_SPEND"
  }
  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "CURRENT_SPEND"
  }

  all_updates_rule {
    pubsub_topic   = google_pubsub_topic.cost_alert.id
    schema_version = "1.0"
  }

  depends_on = [google_billing_account_iam_member.terraform_state_billing_admin]
}

# --- Source zip + Cloud Function ----------------------------------------------
data "archive_file" "cost_alert_src" {
  type        = "zip"
  source_dir  = "${path.module}/../../gcp-functions/cost-alert"
  output_path = "${path.module}/.build/cost_alert.zip"
}

resource "google_storage_bucket_object" "cost_alert_src" {
  name   = "cost-alert/${data.archive_file.cost_alert_src.output_sha256}.zip"
  bucket = google_storage_bucket.functions_src.name
  source = data.archive_file.cost_alert_src.output_path
}

resource "google_cloudfunctions2_function" "cost_alert" {
  name     = "cost-alert"
  location = var.cost_monitor_region

  build_config {
    runtime     = "python313"
    entry_point = "main"
    source {
      storage_source {
        bucket = google_storage_bucket.functions_src.name
        object = google_storage_bucket_object.cost_alert_src.name
      }
    }
  }

  service_config {
    max_instance_count    = 1
    available_memory      = "256M"
    timeout_seconds       = 60
    service_account_email = google_service_account.cost_alert.email

    environment_variables = {
      PROJECT_ID             = var.project_id
      DISCORD_WEBHOOK_SECRET = "${google_secret_manager_secret.discord_webhook_cost_monitor.id}/versions/latest"
      REPORT_TIMEZONE        = var.cost_monitor_timezone
      CRITICAL_BUDGET_JPY    = tostring(var.cost_alert_critical_budget_jpy)
    }
  }

  event_trigger {
    trigger_region        = var.cost_monitor_region
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic          = google_pubsub_topic.cost_alert.id
    retry_policy          = "RETRY_POLICY_DO_NOT_RETRY"
    service_account_email = google_service_account.cost_alert.email
  }

  depends_on = [
    google_project_service.required,
    google_project_iam_member.cost_alert_eventarc_receiver,
  ]
}

resource "google_cloud_run_service_iam_member" "cost_alert_invoker" {
  location = google_cloudfunctions2_function.cost_alert.location
  service  = google_cloudfunctions2_function.cost_alert.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.cost_alert.email}"

  depends_on = [google_project_iam_member.terraform_state_run_admin]
}

resource "google_project_iam_member" "cost_alert_eventarc_receiver" {
  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.cost_alert.email}"
}
