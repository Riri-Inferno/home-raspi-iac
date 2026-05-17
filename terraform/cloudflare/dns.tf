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
