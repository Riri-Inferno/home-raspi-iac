resource "cloudflare_dns_record" "api_kakeibo" {
  content = "4c26acb4-6ab9-4fcc-961b-53968db80666.cfargotunnel.com"
  name    = "api-kakeibo.riri-inferno.com"
  proxied = true
  tags    = []
  ttl     = 1
  type    = "CNAME"
  zone_id = "9eb9dc36b4e0fb39efda0fa5632d8e79"
  settings = {
    flatten_cname = false
  }
}

resource "cloudflare_dns_record" "argocd" {
  content = "4c26acb4-6ab9-4fcc-961b-53968db80666.cfargotunnel.com"
  name    = "argocd.riri-inferno.com"
  proxied = true
  tags    = []
  ttl     = 1
  type    = "CNAME"
  zone_id = "9eb9dc36b4e0fb39efda0fa5632d8e79"
  settings = {
    flatten_cname = false
  }
}

resource "cloudflare_dns_record" "kakeibo" {
  content = "4c26acb4-6ab9-4fcc-961b-53968db80666.cfargotunnel.com"
  name    = "kakeibo.riri-inferno.com"
  proxied = true
  tags    = []
  ttl     = 1
  type    = "CNAME"
  zone_id = "9eb9dc36b4e0fb39efda0fa5632d8e79"
  settings = {
    flatten_cname = false
  }
}

resource "cloudflare_dns_record" "oidc" {
  content = "4c26acb4-6ab9-4fcc-961b-53968db80666.cfargotunnel.com"
  name    = "oidc.riri-inferno.com"
  proxied = true
  tags    = []
  ttl     = 1
  type    = "CNAME"
  zone_id = "9eb9dc36b4e0fb39efda0fa5632d8e79"
  settings = {
    flatten_cname = false
  }
}

# Vector Search API (gcp-serverless-vector-search repo)
# GCP API Gateway の hostname を指す。Cloudflare Tunnel ではなく外部公開エンドポイントへの CNAME。
# Cloudflare SSL は "Full" 以上が必要 (gateway.dev は TLS 終端済みのため "Full Strict" でも可)。
resource "cloudflare_dns_record" "vector_search_api" {
  content = "vector-search-gateway-dzqjqk3y.an.gateway.dev"
  name    = "vector-search.api.riri-inferno.com"
  proxied = true
  tags    = []
  ttl     = 1
  type    = "CNAME"
  zone_id = "9eb9dc36b4e0fb39efda0fa5632d8e79"
  settings = {
    flatten_cname = false
  }
}
