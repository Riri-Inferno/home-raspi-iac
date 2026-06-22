# Cloudflare Cache Rules (docs/security.md D1 参照 / gcp-serverless-vector-search リポ側)
#
# /health のレスポンスを Edge で短時間キャッシュし、外形監視ループの origin 到達を減らす。
# Cloud Functions のコールドスタートと利用料を抑制する目的。
#
# 200 のみキャッシュ。401/403 など認証失敗レスポンスをキャッシュしてしまうと
# 正規 API Key のリクエストにも誤って 401 が返るため、status_code_ttl で 200 のみ TTL を持たせる。
# (API Key 検証は Cloudflare の前段ではなく GCP API Gateway 側で行われるため、Cloudflare 側は
#  認証状態を知らずに応答をキャッシュする可能性がある)

resource "cloudflare_ruleset" "cache_rules" {
  zone_id = var.zone_id
  name    = "Cache Rules"
  kind    = "zone"
  phase   = "http_request_cache_settings"

  rules = [
    {
      description = "/health の 200 レスポンスを Edge で 30 秒キャッシュ"
      expression  = "http.request.uri.path eq \"/health\""
      action      = "set_cache_settings"
      enabled     = true
      action_parameters = {
        cache = true
        edge_ttl = {
          mode    = "override_origin"
          default = 0
          status_code_ttl = [
            {
              status_code = 200
              value       = 30
            }
          ]
        }
      }
    }
  ]
}
