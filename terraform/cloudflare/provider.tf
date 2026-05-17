# api_token は環境変数 CLOUDFLARE_API_TOKEN から読み取られる。
# - ローカル: `export CLOUDFLARE_API_TOKEN=<token>`
# - GitHub Actions: env 経由で GHA Secrets から渡す
# token を .tf に書かないことで Git への漏洩を防ぐ。
provider "cloudflare" {
}
