resource "cloudflare_zero_trust_access_identity_provider" "one_time_pin" {
  account_id = "626318c8e13be78d91dbb56330cc71e5"
  name       = "One Time Pin"
  type       = "onetimepin"
  config     = {}
}

resource "cloudflare_zero_trust_access_application" "argocd" {
  account_id                 = "626318c8e13be78d91dbb56330cc71e5"
  allowed_idps               = [cloudflare_zero_trust_access_identity_provider.one_time_pin.id]
  app_launcher_visible       = true
  auto_redirect_to_identity  = true
  domain                     = "argocd.riri-inferno.com"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "ArgoCD"
  options_preflight_bypass   = false
  service_auth_401_redirect  = true
  session_duration           = "24h"
  tags                       = []
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "argocd.riri-inferno.com"
  }]
  oauth_configuration = {
    dynamic_client_registration = {
      allow_any_on_localhost = true
      allow_any_on_loopback  = true
      allowed_uris           = []
      enabled                = true
    }
    enabled = false
  }
  policies = [{
    id         = cloudflare_zero_trust_access_policy.allow_me.id
    precedence = 1
  }]
}

resource "cloudflare_zero_trust_access_policy" "allow_me" {
  account_id = "626318c8e13be78d91dbb56330cc71e5"
  decision   = "allow"
  name       = "Allow me"
  connection_rules = {
    rdp = {
      allowed_clipboard_local_to_remote_formats = ["text"]
      allowed_clipboard_remote_to_local_formats = ["text"]
    }
  }
  exclude = []
  include = [{
    email = {
      email = "takayo.uenter36@gmail.com"
    }
  }]
  require = []
}
