# Cloudflare D1 多層防御 (docs/security.md D1 参照)
#
#   - Bot Fight Mode  : 無料。自動化ボット・スキャナーを Cloudflare エッジで遮断
#   - Rate Limiting   : 無料1ルール。重い /v1/search を 30 req/min/IP に制限
#   - Custom Rules    : 無料5ルール。空 UA・既知攻撃ツールを遮断

# ---------------------------------------------------------------------------
# Bot Fight Mode
# ---------------------------------------------------------------------------
resource "cloudflare_bot_management" "riri_inferno" {
  zone_id    = var.zone_id
  fight_mode = true
  enable_js  = true
}

# ---------------------------------------------------------------------------
# Rate Limiting — /v1/search (Free プランで使える 1 ルール)
#
# Gemini API 呼出を伴う重いエンドポイントに絞る。
# /health は API Key + Bot Fight Mode で十分と判断 (docs/security.md D1)。
# ---------------------------------------------------------------------------
resource "cloudflare_ruleset" "rate_limit" {
  zone_id     = var.zone_id
  name        = "Rate Limiting Rules"
  kind        = "zone"
  phase       = "http_ratelimit"

  rules = [
    {
      description = "/v1/search を 30 req/min/IP に制限"
      expression  = "http.request.uri.path eq \"/v1/search\""
      action      = "block"
      enabled     = true
      ratelimit = {
        characteristics     = ["ip.src"]
        period              = 60
        requests_per_period = 30
        mitigation_timeout  = 60
      }
    }
  ]
}

# ---------------------------------------------------------------------------
# Custom Rules — 空 UA と既知攻撃ツールをブロック (Free プランで 5 ルールまで)
#
# 正規の API クライアントは必ず UA を送る。空 UA はスキャナーの特徴。
# sqlmap / nikto / masscan 等は API に対する攻撃ツールとして既知。
# ---------------------------------------------------------------------------
resource "cloudflare_ruleset" "custom_rules" {
  zone_id     = var.zone_id
  name        = "Custom Security Rules"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  rules = [
    {
      description = "空 UA と既知攻撃ツールをブロック"
      expression  = "(http.user_agent eq \"\") or (http.user_agent matches \"(?i)(sqlmap|nikto|masscan|nmap|dirbuster|gobuster|nuclei)\")"
      action      = "block"
      enabled     = true
    }
  ]
}
