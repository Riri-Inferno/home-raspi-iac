# pg_dump 保管用 GCS bucket。7 日経過した object は lifecycle で自動削除。
# kakeibo-db (kakeibo namespace の postgres) のバックアップが主な想定。
# 書き込み主体（k3s CronJob / Actions cron / 手動 gcloud）は別途決定時に IAM binding を追加。
resource "google_storage_bucket" "pg_backup" {
  name     = "riri-inferno-pg-backup"
  location = "asia-northeast1"

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  lifecycle_rule {
    condition {
      age = 7
    }
    action {
      type = "Delete"
    }
  }
}
