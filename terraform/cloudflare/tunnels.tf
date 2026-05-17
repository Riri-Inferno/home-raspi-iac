resource "cloudflare_zero_trust_tunnel_cloudflared" "k3s" {
  account_id = "626318c8e13be78d91dbb56330cc71e5"
  config_src = "local"
  name       = "k3s"
}
