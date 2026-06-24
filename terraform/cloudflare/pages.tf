# Cloudflare Pages: riri-vector-search フロントエンド
#
# gcp-serverless-vector-search リポジトリの frontend/ ディレクトリをビルドなしで配信。
#
# 前提: GitHub OAuth の認可は CF ダッシュボード上で一回手動が必要。
#   Workers & Pages > Overview > Create > Connect to Git > GitHub でリポジトリを認可。
#   認可後は本リソースで管理できる。
#
# デプロイフロー:
#   develop ブランチへの push → 本番デプロイ (app.riri-inferno.com)
#   feature/* ブランチへの push → プレビューデプロイ (*.riri-vector-search.pages.dev)

resource "cloudflare_pages_project" "vector_search_frontend" {
  account_id        = var.account_id
  name              = "riri-vector-search"
  production_branch = "develop"

  source = {
    type = "github"
    config = {
      owner                         = "Riri-Inferno"
      repo_name                     = "gcp-serverless-vector-search"
      production_branch             = "develop"
      pr_comments_enabled           = true
      deployments_enabled           = true
      production_deployment_enabled = true
      preview_deployment_setting    = "custom"
      preview_branch_includes       = ["feature/*"]
    }
  }

  build_config = {
    build_command   = "cd frontend && npm install && npm run build"
    destination_dir = "frontend"
  }
}

# カスタムドメイン: app.riri-inferno.com → Pages プロジェクトに紐付け
resource "cloudflare_pages_domain" "vector_search_frontend" {
  account_id   = var.account_id
  project_name = cloudflare_pages_project.vector_search_frontend.name
  name         = "app.${var.zone_name}"

  depends_on = [cloudflare_pages_project.vector_search_frontend]
}

# DNS: app.riri-inferno.com → riri-vector-search.pages.dev
resource "cloudflare_dns_record" "vector_search_app" {
  zone_id = var.zone_id
  name    = "app.${var.zone_name}"
  type    = "CNAME"
  content = "${cloudflare_pages_project.vector_search_frontend.name}.pages.dev"
  proxied = true
  ttl     = 1
  tags    = []
  settings = {
    flatten_cname = false
  }
}
