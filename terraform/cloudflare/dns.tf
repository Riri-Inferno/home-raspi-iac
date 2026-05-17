resource "cloudflare_dns_record" "terraform_managed_resource_55d4c21d4f59f645415ac3d7b323e255_39" {
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

resource "cloudflare_dns_record" "terraform_managed_resource_da4cfe2c77df76aee7f349be44fc1557_40" {
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

resource "cloudflare_dns_record" "terraform_managed_resource_340047daf8badcbb3366329d7e4e2635_41" {
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

resource "cloudflare_dns_record" "terraform_managed_resource_bd8b78b664d08246f4aa1dbea6d5d4fd_42" {
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
