# Kubernetes Stack - Home Raspi

ラズパイ5（ホストマシン）の k3s クラスタおよび GitOps スタック。  
このリポジトリのマニフェストを source of truth とし、ラズパイ側は ArgoCD で pull 同期する。

## 構成

| コンポーネント       | 役割                                       | 備考                  |
|--------------------|-------------------------------------------|----------------------|
| k3s                | 軽量 Kubernetes ディストリビューション        | API: `:6443`         |
| ArgoCD             | GitOps コントローラ（Web UI 付き）           | Ingress 経由で公開    |
| sealed-secrets     | Git に乗せる Secret の暗号化コントローラ      | Bitnami              |
| Ansible            | k3s 本体・基盤コンポーネントの初期インストール | `bootstrap/` 配下    |

## レイヤ分担

| レイヤ                              | ツール                       |
|------------------------------------|-----------------------------|
| ハードウェア / OS インストール        | 手動（Raspberry Pi Imager）  |
| k3s インストール / ノード設定         | **Ansible**                 |
| ArgoCD / sealed-secrets の初期投入   | Ansible                     |
| アプリ・監視スタック等                | k3s マニフェスト + ArgoCD    |

## ブートストラップ

```bash
cd k3s/bootstrap
ansible-playbook -i inventory.ini site.yml
```

これで以下が冪等にインストールされる:

- k3s（サーバノード）
- ArgoCD
- sealed-secrets コントローラ
- 本リポジトリを監視する ArgoCD `Application` リソース

以降、`k3s/apps/` 配下のマニフェストを push すれば ArgoCD が自動で同期する。

## アクセス

- ArgoCD UI: `http://raspi5/<argocd-ingress>`（初期 admin パスワード: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`）
- kubectl: `/etc/rancher/k3s/k3s.yaml` を `~/.kube/config` に取り込む

## シークレット管理

平文 Secret は **絶対にコミットしない**。  
`kubeseal` で暗号化した `SealedSecret` リソースのみコミットする。

```bash
kubectl create secret generic <name> --from-literal=key=value --dry-run=client -o yaml \
  | kubeseal --controller-name=sealed-secrets-controller --controller-namespace=kube-system -o yaml \
  > k3s/apps/<app>/sealedsecret.yaml
```

復号鍵はクラスタ内のみで保持され、リポジトリには出ない。

## ディレクトリ構成（予定）

```
k3s/
├── README.md
├── bootstrap/                # Ansible: k3s + クラスタ基盤の初期構築
│   ├── inventory.ini
│   ├── site.yml
│   └── roles/
│       ├── k3s/
│       ├── argocd/
│       └── sealed-secrets/
└── apps/                     # ArgoCD が同期するマニフェスト
    └── <app-name>/
        ├── deployment.yaml
        ├── service.yaml
        └── sealedsecret.yaml
```

## 今後の追加予定

- [ ] Ansible playbook 実装（k3s / ArgoCD / sealed-secrets インストール）
- [ ] ArgoCD Application マニフェスト（自リポジトリ監視）
- [ ] Ingress Controller 選定（k3s 同梱 Traefik or nginx）
- [ ] `monitoring/` を docker-compose から k3s マニフェストへ移行
- [ ] コンテナレジストリ確定（GHCR or セルフホスト）
