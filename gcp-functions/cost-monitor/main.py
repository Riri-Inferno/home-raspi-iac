"""Daily GCP cost summary → Discord webhook.

Triggered by Pub/Sub (CloudEvent). Reads yesterday's billing data from the
GCP Billing Export BigQuery table and posts a formatted embed to Discord.

Env vars (set by Terraform):
    PROJECT_ID              GCP project to query / report on
    BILLING_DATASET         BigQuery dataset name (in PROJECT_ID) holding billing export
    BILLING_TABLE           Billing export table name (empty until export is enabled)
    DISCORD_WEBHOOK_SECRET  Full Secret Manager resource name, e.g.
                            projects/<num>/secrets/discord-webhook-cost-monitor/versions/latest
    REPORT_TIMEZONE         IANA tz (e.g. Asia/Tokyo). Used for "yesterday" boundary.
"""

import json
import logging
import os
import urllib.request
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

import functions_framework
from google.cloud import bigquery, secretmanager

logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

PROJECT_ID = os.environ["PROJECT_ID"]
BILLING_DATASET = os.environ["BILLING_DATASET"]
BILLING_TABLE = os.environ.get("BILLING_TABLE", "")
WEBHOOK_SECRET = os.environ["DISCORD_WEBHOOK_SECRET"]
TZ = ZoneInfo(os.environ.get("REPORT_TIMEZONE", "Asia/Tokyo"))

COLOR_OK = 0x2ECC71
COLOR_WARN = 0xF1C40F
COLOR_ERR = 0xE74C3C


def _fetch_webhook_url() -> str:
    client = secretmanager.SecretManagerServiceClient()
    resp = client.access_secret_version(name=WEBHOOK_SECRET)
    return resp.payload.data.decode("utf-8").strip()


def _yesterday_bounds():
    now = datetime.now(TZ)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    yesterday_start = today_start - timedelta(days=1)
    return yesterday_start, today_start


def _month_to_date_bounds():
    now = datetime.now(TZ)
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    return month_start, now


# Net cost = cost + SUM(credits.amount). Credits are negative numbers (discounts
# / free-tier offsets) so this matches GCP Console's billed-amount display.
# project.id IS NULL captures billing-account-level adjustments
# (rounding_error etc.) that don't belong to a specific project.
_NET_COST_EXPR = "cost + IFNULL((SELECT SUM(c.amount) FROM UNNEST(credits) c), 0)"
_PROJECT_FILTER = "(project.id = @project_id OR project.id IS NULL)"


def _query_yesterday_costs(client: bigquery.Client):
    start, end = _yesterday_bounds()
    table_fqn = f"`{PROJECT_ID}.{BILLING_DATASET}.{BILLING_TABLE}`"
    sql = f"""
    SELECT
      service.description AS service,
      SUM({_NET_COST_EXPR}) AS cost,
      ANY_VALUE(currency) AS currency
    FROM {table_fqn}
    WHERE usage_start_time >= @start
      AND usage_start_time <  @end
      AND {_PROJECT_FILTER}
    GROUP BY service
    HAVING cost != 0
    ORDER BY cost DESC
    """
    job = client.query(
        sql,
        job_config=bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter("start", "TIMESTAMP", start),
                bigquery.ScalarQueryParameter("end", "TIMESTAMP", end),
                bigquery.ScalarQueryParameter("project_id", "STRING", PROJECT_ID),
            ]
        ),
    )
    rows = list(job.result())
    return start, end, rows


def _query_month_to_date_total(client: bigquery.Client):
    start, end = _month_to_date_bounds()
    table_fqn = f"`{PROJECT_ID}.{BILLING_DATASET}.{BILLING_TABLE}`"
    sql = f"""
    SELECT
      SUM({_NET_COST_EXPR}) AS cost,
      ANY_VALUE(currency) AS currency
    FROM {table_fqn}
    WHERE usage_start_time >= @start
      AND usage_start_time <  @end
      AND {_PROJECT_FILTER}
    """
    job = client.query(
        sql,
        job_config=bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter("start", "TIMESTAMP", start),
                bigquery.ScalarQueryParameter("end", "TIMESTAMP", end),
                bigquery.ScalarQueryParameter("project_id", "STRING", PROJECT_ID),
            ]
        ),
    )
    row = next(iter(job.result()), None)
    total = float(row.cost) if row and row.cost is not None else 0.0
    currency = row.currency if row and row.currency else "JPY"
    return start, end, total, currency


def _format_money(amount: float, currency: str) -> str:
    if currency == "JPY":
        return f"¥{amount:,.0f}"
    return f"{amount:,.2f} {currency}"


def _build_embed_unconfigured() -> dict:
    return {
        "title": "⚙️ GCP Cost Monitor — 設定未完了",
        "description": (
            "Billing Export の BigQuery テーブル名が未設定です。\n"
            "`terraform/gcp/variables.tf` の `billing_export_table` を実テーブル名に更新し、"
            "GCP コンソールで Billing Export を有効化してください。"
        ),
        "color": COLOR_WARN,
        "footer": {"text": f"project: {PROJECT_ID}"},
        "timestamp": datetime.now(TZ).isoformat(),
    }


def _build_embed_error(err: Exception) -> dict:
    return {
        "title": "❌ GCP Cost Monitor — 集計失敗",
        "description": f"```\n{type(err).__name__}: {err}\n```",
        "color": COLOR_ERR,
        "footer": {"text": f"project: {PROJECT_ID}"},
        "timestamp": datetime.now(TZ).isoformat(),
    }


def _build_embed_summary(start, end, rows, mtd_start, mtd_total, mtd_currency) -> dict:
    currency = rows[0].currency if rows else mtd_currency
    total = sum(r.cost for r in rows)
    top = rows[:10]

    if top:
        breakdown = "\n".join(
            f"`{_format_money(r.cost, r.currency):>10}`  {r.service}"
            for r in top
        )
    else:
        breakdown = "_(該当データなし)_"

    date_label = start.strftime("%Y-%m-%d")
    mtd_label = mtd_start.strftime("%Y-%m")
    return {
        "title": f"📊 GCP 日次コスト — {date_label}",
        "description": (
            f"**昨日: {_format_money(total, currency)}** / "
            f"**当月累計 ({mtd_label}): {_format_money(mtd_total, mtd_currency)}**"
        ),
        "color": COLOR_OK if total > 0 else COLOR_WARN,
        "fields": [
            {
                "name": "昨日のサービス別 (上位10件)",
                "value": breakdown,
                "inline": False,
            }
        ],
        "footer": {"text": f"project: {PROJECT_ID} • {start.tzinfo}"},
        "timestamp": datetime.now(TZ).isoformat(),
    }


def _post_discord(webhook_url: str, embed: dict) -> None:
    payload = {"username": "GCP Cost Monitor", "embeds": [embed]}
    req = urllib.request.Request(
        webhook_url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",

            # ユーザーエージェントを明示的に指定しないとDiscord側にはじかれる
            "User-Agent": "home-raspi-iac-cost-monitor (+https://github.com/Riri-Inferno/home-raspi-iac, 1.0)",
        },
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        resp.read()


@functions_framework.cloud_event
def main(_cloud_event) -> None:
    webhook_url = _fetch_webhook_url()

    if not BILLING_TABLE:
        log.warning("BILLING_TABLE not set; posting setup-required notice")
        _post_discord(webhook_url, _build_embed_unconfigured())
        return

    try:
        client = bigquery.Client(project=PROJECT_ID)
        start, end, rows = _query_yesterday_costs(client)
        mtd_start, _mtd_end, mtd_total, mtd_currency = _query_month_to_date_total(client)
        embed = _build_embed_summary(start, end, rows, mtd_start, mtd_total, mtd_currency)
    except Exception as e:
        log.exception("cost query failed")
        embed = _build_embed_error(e)

    _post_discord(webhook_url, embed)
