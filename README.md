# home-raspi-iac

自宅サーバ（Raspberry Pi 5）を **IaC + GitOps** で再現可能に管理するリポジトリ。
このリポジトリのマニフェストを source of truth とし、ラズパイ側は ArgoCD 経由で pull 同期するモデル。

## 構成

ArgoCD は **App of Apps** パターン構成。`root` Application が `k3s/apps/_apps/` 配下の **子 Application 群のみ** を管理し、各子 Application が自分の担当ディレクトリを同期する。

```mermaid
flowchart TD
    subgraph GH["GitHub: Riri-Inferno/home-raspi-iac (source of truth)"]
        subgraph K3S_REPO["k3s/"]
            B["bootstrap/<br/>Ansible: k3s + ArgoCD + sealed-secrets"]
            subgraph APPS["apps/"]
                APPSDIR["_apps/<br/>子 Application マニフェスト群"]
                ARGOCFG["argocd/<br/>(SealedSecret)"]
                CFD["cloudflared/"]
                MON["monitoring/"]
                OIDC["oidc/"]
                KAK["kakeibo/"]
            end
        end
    end

    subgraph PI["Raspberry Pi 5 (raspi5.local)"]
        subgraph K3S_CL["k3s クラスタ"]
            ROOT["root Application<br/>(_apps/ を監視)"]
            ROOT --> APPA["Application: argocd"]
            ROOT --> APPC["Application: cloudflared"]
            ROOT --> APPM["Application: monitoring"]
            ROOT --> APPO["Application: oidc"]
            ROOT --> APPK["Application: kakeibo"]
            ROOT --> APPR["Application: reloader"]
            APPA -.-> RESA["argocd ns の<br/>SealedSecret"]
            APPC -.-> RESC["cloudflared Pod<br/>(k3s tunnel)"]
            APPM -.-> RESM["Prometheus / Grafana<br/>node-exporter / cAdvisor"]
            APPO -.-> RESO["nginx<br/>OIDC discovery 配信"]
            APPK -.-> RESK["kakeibo-frontend / backend / db"]
            APPR -.-> RESRL["Reloader controller"]
        end
    end

    USER[Browser] -->|argocd / kakeibo<br/>.riri-inferno.com| CFE[Cloudflare Edge]
    CFE -.-> RESC
    GCP[GCP STS] -->|OIDC discovery| CFE
    GH -.->|pull| ROOT
```

## 採用技術と役割

| レイヤ | ツール | 役割 |
|---|---|---|
| ハードウェア / OS | Raspberry Pi 5 + Raspberry Pi OS | 物理ホスト（手動セットアップ） |
| プロビジョニング | **Ansible** | k3s 本体 + 基盤コンポーネントの初期構築（冪等） |
| オーケストレーション | **k3s** | 軽量 Kubernetes |
| GitOps | **ArgoCD** | リポジトリ → クラスタの同期、UI 付き |
| シークレット管理 | **sealed-secrets**（Bitnami） | Git に乗せられる暗号化 Secret |
| 監視 | Prometheus + Grafana + node-exporter + cAdvisor | k3s 上で運用、PVC 永続化 |

## ディレクトリ

- [`k3s/`](k3s/) — Kubernetes 関連。詳細・運用ガイドは [k3s/README.md](k3s/README.md)
  - `k3s/bootstrap/` — Ansible playbook（k3s + ArgoCD + sealed-secrets を install）
  - `k3s/apps/` — ArgoCD が同期する Kubernetes マニフェスト
    - `k3s/apps/_apps/` — **子 Application** マニフェスト群（root が同期する対象）
    - `k3s/apps/argocd/` — ArgoCD 自身の SealedSecret
    - `k3s/apps/cloudflared/` — Cloudflare Tunnel（外部公開ルーティング）
    - `k3s/apps/oidc/` — WIF 用 OIDC discovery 静的配信
    - `k3s/apps/monitoring/` — Prometheus / Grafana / exporter 群
    - `k3s/apps/kakeibo/` — 家計簿アプリ（[詳細](k3s/apps/kakeibo/README.md)）
- [`.github/`](.github/) — PR テンプレート

## クイックスタート（クラスタ構築）

開発マシン側に Ansible が必要（`pipx install --include-deps ansible` 等）。
ラズパイへの SSH 公開鍵認証が通ること（`ssh-copy-id riri-inferno@raspi5.local`）。

```bash
cd k3s/bootstrap
ansible-playbook -i inventory.ini site.yml
```

これで k3s クラスタ + sealed-secrets + ArgoCD + 本リポジトリを監視する root Application が立ち上がる。以降 `k3s/apps/` にマニフェストを push すれば自動同期。

## アクセス

| サービス | アクセス |
|---|---|
| ArgoCD UI | `https://argocd.riri-inferno.com/`（Cloudflare Access 認証 + admin / SealedSecret 管理） |
| 家計簿アプリ | `https://kakeibo.riri-inferno.com/` |
| 家計簿 API | `https://api-kakeibo.riri-inferno.com/` |
| Grafana | `http://raspi5.local:30001/`（NodePort、admin / SealedSecret 管理） |
| Prometheus | `http://raspi5.local:30002/`（NodePort） |

> Grafana / Prometheus も将来 Cloudflare Tunnel 経由公開化を予定（要 Cloudflare Access）。

## 運用方針

- **実機にソースを置かない**: イメージは外部レジストリから pull する pull 型運用
- **シークレットは平文で commit しない**: `kubeseal` で暗号化した SealedSecret のみリポジトリへ
- **再構築前提**: Ansible playbook + sealed-secrets 鍵バックアップで全体を再現可能に保つ

## 今後の追加予定

- [ ] cloudflared metrics endpoint を Prometheus 監視対象に追加
- [ ] Grafana / Prometheus も Cloudflare Tunnel + Access 経由公開
- [ ] Cloudflare 設定の Terraform 化（Tunnel / DNS / Access を IaC 化）
- [ ] kakeibo nginx config テンプレ化（kakeibo repo 側、`backend` Service alias 撤去のため）
- [ ] dashboard JSON の IaC 化（必要になったら、UI 完結でも可）
