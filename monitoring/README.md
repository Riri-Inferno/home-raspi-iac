# Monitoring Stack - Home Raspi

ラズパイ5（ホストマシン）の監視スタック。

## 構成

| サービス       | 役割                              | ポート  |
|---------------|----------------------------------|--------|
| node-exporter | ホストの CPU/メモリ/ディスク/温度   | :9100  |
| cAdvisor      | Docker コンテナごとのリソース監視   | :8081  |
| Prometheus    | メトリクス収集・保存（30日保持）     | :9090  |
| Grafana       | ダッシュボード・可視化・アラート     | :3001  |

## 起動

```bash
cd monitoring
docker compose up -d
```

## アクセス

- Grafana: http://raspi5:3001 (初期: admin / changeme)
- Prometheus: http://raspi5:9090

## ダッシュボード

Grafana に自動プロビジョニングされる。  
カスタムダッシュボードは `grafana/provisioning/dashboards/json/` に JSON を置く。

おすすめの公式ダッシュボード（Grafana.com から Import）:
- **Node Exporter Full** (ID: 1860) — ホストのメトリクス全部入り
- **Docker Container & Host Metrics** (ID: 10619) — コンテナ監視

## ネットワーク

監視スタックは独立した `monitoring` ネットワークで動く。  
他のアプリコンテナのメトリクスは cAdvisor がホスト経由で収集する。

## 今後の追加予定

- [ ] オーケストレーション選定（k8s / k3s / Portainer 等）— ホストにソースを置かず、イメージ pull 運用へ移行
- [ ] Alertmanager（Slack/LINE 通知）
- [ ] Loki + Promtail（ログ収集）
- [ ] Cloudflare Tunnel 経由で Grafana を外部公開
