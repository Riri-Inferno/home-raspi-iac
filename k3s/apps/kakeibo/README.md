# kakeibo

家計簿アプリ（[Riri-Inferno/ServerlessKakeibo](https://github.com/Riri-Inferno/ServerlessKakeibo)）を k3s 上にデプロイするためのマニフェスト群。

## 構成

| パス | 役割 |
|---|---|
| `namespace.yaml` | `kakeibo` namespace |
| `serviceaccount.yaml` | `kakeibo-backend` ServiceAccount（WIF impersonation の subject） |
| `configmap.yaml` | backend / postgres 共有の非機密 env（k3s-env-vars.md 準拠） |
| `configmap-wif.yaml` | GCP WIF 設定 JSON（機密ではない、識別子の集合） |
| `sealedsecret.yaml` | DB password / JWT 鍵 / OAuth secret 等（kubeseal で暗号化済） |
| `postgres/` | DB Pod（postgres:16）+ PVC + Service |
| `backend/` | API Pod（GHCR から pull）+ Service |
| `frontend/` | UI Pod（GHCR から pull、build-time に API URL 焼き込み済）+ Service |

## 外部依存

| 依存先 | 内容 |
|---|---|
| GHCR (`ghcr.io/riri-inferno/serverlesskakeibo/{backend,frontend}`) | image の pull 元（public、arm64） |
| `k3s/apps/oidc/` | WIF 用 OIDC discovery（`oidc.riri-inferno.com`）。GCP STS が SA token 検証に使う |
| `k3s/apps/cloudflared/configmap.yaml` | `kakeibo.riri-inferno.com` / `api-kakeibo.riri-inferno.com` の routing |
| GCP Workload Identity Pool `kakeibo-pool` / Provider `kakeibo-k3s` | backend が GCP API を叩くときの認証経路 |

## アプリ側との分担

| home-raspi-iac 側 | kakeibo repo 側 |
|---|---|
| デプロイマニフェスト一式（このディレクトリ） | コード / Dockerfile / CI（GHCR push まで） |
| ConfigMap / SealedSecret の値管理 | `.env.example` / `k3s-env-vars.md`（仕分け表） |
| Cloudflare Tunnel ルーティング | — |
| WIF 用 ServiceAccount + projected SA token | WIF JSON を ADC で読み取る backend 実装 |

## 関連ドキュメント

- 親リポジトリ: [`../../../README.md`](../../../README.md)
- 運用ガイド（アプリ追加 / SealedSecret 化）: [`../../README.md`](../../README.md)
- env 仕分け表（kakeibo repo 側）: `k3s-env-vars.md`
- CI / image push フロー（kakeibo repo 側）: `ci-cd.md`

## 補足

- 新しい env 変数を増やすときは **kakeibo repo の `k3s-env-vars.md`** に仕分けを記録 → ここの `configmap.yaml` or `sealedsecret.yaml` に反映、の順で運用する
- backend の Pod は `kakeibo-backend` SA で動き、`audience=//iam.googleapis.com/.../kakeibo-pool/providers/kakeibo-k3s` の projected SA token で GCP に認証する。詳細は `configmap-wif.yaml` のコメント参照
