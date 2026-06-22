# Cloudflare Worker: vector-search-proxy
#
# GCP API Gateway は Host: *.gateway.dev のリクエストしか受け付けない。
# Cloudflare のプロキシ経由では Host が vector-search.riri-inferno.com のまま
# 転送されるため 404 になる。本 Worker で URL hostname を書き換え、
# Workers runtime が自動的に Host ヘッダを gateway.dev に設定するようにする。
#
# Origin Rules での Host 上書きは Enterprise プラン専用のため Worker で代替する。
# 詳細: gcp-serverless-vector-search docs/adr/0014-cloudflare-worker-host-rewrite.md

resource "cloudflare_workers_script" "vector_search_proxy" {
  account_id         = var.account_id
  script_name        = "vector-search-proxy"
  main_module        = "worker.js"
  content            = file("${path.module}/workers/vector-search-proxy.js")
  compatibility_date = "2025-01-01"
}

resource "cloudflare_workers_route" "vector_search" {
  zone_id = var.zone_id
  pattern = "vector-search.${var.zone_name}/*"
  script  = cloudflare_workers_script.vector_search_proxy.script_name

  depends_on = [cloudflare_workers_script.vector_search_proxy]
}
