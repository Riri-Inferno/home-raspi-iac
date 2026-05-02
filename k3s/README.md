# Kubernetes Stack - Home Raspi

ラズパイ5（ホストマシン）の k3s クラスタおよび GitOps スタック。  
このリポジトリのマニフェストを source of truth とし、ラズパイ側は ArgoCD で pull 同期する。

## 構成

| コンポーネント       | 役割                                       | 備考                  |
|--------------------|-------------------------------------------|----------------------|
| k3s                | 軽量 Kubernetes ディストリビューション        | API: `:6443`         |
| ArgoCD             | GitOps コントローラ（Web UI 付き）           | port-forward で公開    |
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

### 前提

- 操作端末（コントローラ）に **Ansible** がインストールされている
- ラズパイへ SSH 公開鍵認証で接続できる（ユーザー: `riri-inferno`）
- ラズパイ側で `sudo` がパスワードなしで使える（または `--ask-become-pass` を付けて実行）

### 実行

```bash
cd k3s/bootstrap
ansible-playbook -i inventory.ini site.yml
# sudo パスワードが必要な場合:
# ansible-playbook -i inventory.ini site.yml --ask-become-pass
```

これで以下が冪等にインストールされる:

- k3s（サーバノード）
- sealed-secrets コントローラ
- ArgoCD
- 本リポジトリを監視する ArgoCD `Application`（`root`）

以降、`k3s/apps/` 配下のマニフェストを push すれば ArgoCD が自動で同期する。

## アクセス

- ArgoCD UI: port-forward 経由で `https://raspi5.local:8443/`
  - 初期パスワード（リセット前）: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`
  - 現状: SealedSecret 管理（個人パスワードマネージャ）
- kubectl: `/etc/rancher/k3s/k3s.yaml` を `~/.kube/config` に取り込む（または raspi 上で `sudo k3s kubectl ...`）

## ディレクトリ構成

```
k3s/
├── README.md
├── bootstrap/                # Ansible: k3s + クラスタ基盤の初期構築
│   ├── inventory.ini
│   ├── site.yml
│   ├── group_vars/
│   │   └── all.yml           # repo URL / ブランチ / 各種バージョン
│   └── roles/
│       ├── k3s/
│       ├── sealed-secrets/
│       └── argocd/           # 本体 install + 自リポジトリ監視 root Application
└── apps/                     # ArgoCD が同期するマニフェスト
    ├── argocd/               # ArgoCD 自身の SealedSecret（admin password）
    └── monitoring/           # Prometheus / Grafana / node-exporter / cAdvisor
```

---

## 運用ガイド

### 新しいアプリを追加する

1. **feature ブランチ作成**:
   ```bash
   git checkout -b feature/<app-name>
   ```

2. **マニフェストを `k3s/apps/<app-name>/` に配置**:
   - 必要に応じて `namespace.yaml` / `deployment.yaml` / `service.yaml` / `pvc.yaml` 等
   - シークレットが必要なら次セクション「Secret を SealedSecret 化する」を参照

3. **構文チェック（任意だが推奨）**:
   ```bash
   ssh riri-inferno@raspi5.local 'sudo k3s kubectl apply --dry-run=server -f -' \
     < k3s/apps/<app-name>/deployment.yaml
   ```
   `created (server dry run)` が出れば API 検証 OK。

4. **PR 作成 → develop マージ**:
   ```bash
   git add k3s/apps/<app-name>
   git commit -m "..."
   git push -u origin feature/<app-name>
   gh pr create --base develop ...
   ```

5. **ArgoCD 同期確認**:
   - 自動 sync は **3 分間隔** のポーリング。急ぎなら手動 refresh:
     ```bash
     ssh riri-inferno@raspi5.local \
       'sudo k3s kubectl -n argocd annotate application root argocd.argoproj.io/refresh=hard --overwrite'
     ```
   - 状態確認:
     ```bash
     ssh riri-inferno@raspi5.local 'sudo k3s kubectl -n argocd get application root'
     ssh riri-inferno@raspi5.local 'sudo k3s kubectl get all -n <namespace>'
     ```

### Secret を SealedSecret 化する

平文 Secret は **絶対にコミットしない**。`kubeseal` で暗号化した `SealedSecret` だけが Git に乗る。

#### 前提（初回のみ）

- `kubeseal` CLI を controller と同じバージョンで install（現状 `v0.27.3`）:
  ```bash
  URL='https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.27.3/kubeseal-0.27.3-linux-amd64.tar.gz'
  curl -L "$URL" -o /tmp/kubeseal.tar.gz
  tar -xzf /tmp/kubeseal.tar.gz -C /tmp/ kubeseal
  sudo install -m 755 /tmp/kubeseal /usr/local/bin/kubeseal
  ```
- クラスタの公開鍵を取得しローカル保存:
  ```bash
  mkdir -p ~/.config/sealed-secrets
  ssh riri-inferno@raspi5.local \
    "sudo k3s kubectl -n kube-system get secret -l sealedsecrets.bitnami.com/sealed-secrets-key=active -o jsonpath='{.items[0].data.tls\.crt}'" \
    | base64 -d > ~/.config/sealed-secrets/cert.pem
  ```

#### 毎回の手順

1. **平文 Secret を `/tmp/` に作成**（リポジトリには絶対置かない）:
   ```bash
   cat > /tmp/<name>-secret.yaml <<'EOF'
   apiVersion: v1
   kind: Secret
   metadata:
     name: <name>
     namespace: <ns>
   type: Opaque
   stringData:
     key: '<value>'   # bcrypt ハッシュ等の `$` を含む値はシングルクォート必須
   EOF
   ```

2. **kubeseal で暗号化**:
   ```bash
   kubeseal --cert ~/.config/sealed-secrets/cert.pem -o yaml \
     < /tmp/<name>-secret.yaml \
     > k3s/apps/<app>/<name>.yaml
   ```

3. **平文ファイルを削除**:
   ```bash
   rm -f /tmp/<name>-secret.yaml
   ```

4. **コミット → PR → merge** すると、ArgoCD 同期で SealedSecret が cluster に届き、controller が復号して通常の Secret を作成。Pod から `secretKeyRef` で参照。

#### 既存の Secret を乗っ取る場合（注意）

ArgoCD install で先に作られた `argocd-secret` のような **既に存在するが SealedSecret 管理ではない Secret** を乗っ取りたいときは、初手で衝突する。確実な方法は：

1. SealedSecret マニフェストに annotation を追加:
   ```yaml
   metadata:
     annotations:
       sealedsecrets.bitnami.com/managed: "true"
   ```
2. 既存 Secret を **削除** + sealed-secrets controller を **再起動**:
   ```bash
   ssh riri-inferno@raspi5.local '
     sudo k3s kubectl -n <ns> delete secret <name>
     sudo k3s kubectl -n kube-system rollout restart deployment sealed-secrets-controller
   '
   ```
   → controller が「SealedSecret あり、Secret 無し」を検知して新規作成（owner reference 付き）

#### 重要: master key のオフラインバックアップ

クラスタを再構築すると sealed-secrets の private key も再生成され、**既存の SealedSecret は復号できなくなる**。鍵をオフライン（パスワードマネージャ等）に必ず保管すること。

```bash
ssh riri-inferno@raspi5.local \
  "sudo k3s kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key=active -o yaml" \
  > ~/sealed-secrets-master-key.yaml
# ↑ 安全な場所に保存後、開発マシンから消す（Git 厳禁）
```

復旧:
```bash
ssh riri-inferno@raspi5.local 'sudo k3s kubectl apply -f -' < <backup>.yaml
ssh riri-inferno@raspi5.local 'sudo k3s kubectl -n kube-system rollout restart deployment sealed-secrets-controller'
```

---

## 今後の追加予定

- [ ] Ingress Controller 整備（k3s 同梱 Traefik で正式 URL 化、port-forward 撤去）
- [ ] ArgoCD の Cloudflare Tunnel 経由公開（Cloudflare Access で認証ゲート）
- [ ] コンテナレジストリ確定（GHCR or セルフホスト）
