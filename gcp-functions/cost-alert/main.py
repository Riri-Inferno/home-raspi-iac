"""Cloud Billing Budget threshold notification → Discord.

Triggered by Pub/Sub (CloudEvent) from Cloud Billing Budget's all_updates_rule.
Receives a JSON payload describing the budget threshold crossed, classifies it
into info/warn/crit, formats a Discord embed, and posts via webhook with
optional @everyone mention.

Pub/Sub payload schema (Cloud Billing Budget v1.0):
    budgetDisplayName       Budget name (used to route warn vs crit)
    alertThresholdExceeded  Threshold that fired (None for periodic updates → skip)
    costAmount              Current actual spend
    costIntervalStart       Start of the budget interval (e.g. "2026-05-01T00:00:00Z")
    budgetAmount            Configured budget
    currencyCode            "JPY" expected

Env vars (set by Terraform):
    PROJECT_ID              GCP project (display only)
    DISCORD_WEBHOOK_SECRET  Full Secret Manager resource name for webhook URL
    CRITICAL_BUDGET_JPY     Critical budget amount in JPY (used in message text)
    REPORT_TIMEZONE         IANA tz (e.g. Asia/Tokyo)

Dry-run: include `"_test": true` in the payload (use dry_run.sh). This skips
the @everyone mention and prefixes the embed title with "[TEST]".
"""

import base64
import json
import logging
import os
import urllib.request
from datetime import datetime
from zoneinfo import ZoneInfo

import functions_framework
from google.cloud import secretmanager

logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

PROJECT_ID = os.environ["PROJECT_ID"]
WEBHOOK_SECRET = os.environ["DISCORD_WEBHOOK_SECRET"]
TZ = ZoneInfo(os.environ.get("REPORT_TIMEZONE", "Asia/Tokyo"))
CRITICAL_BUDGET_JPY = float(os.environ.get("CRITICAL_BUDGET_JPY", "1000"))

COLOR_INFO = 0x3498DB
COLOR_WARN = 0xF1C40F
COLOR_ERR = 0xE74C3C


def _fetch_webhook_url() -> str:
    client = secretmanager.SecretManagerServiceClient()
    resp = client.access_secret_version(name=WEBHOOK_SECRET)
    return resp.payload.data.decode("utf-8").strip()


def _format_yen(amount: float) -> str:
    return f"¥{amount:,.0f}"


def _classify(payload: dict):
    """Pick the right (level, title, message, mention_everyone) for this budget event.

    Returns None for events we don't want to notify on (periodic updates,
    forecast-only crossings, unknown budgets).
    """
    name = payload.get("budgetDisplayName", "")
    threshold = payload.get("alertThresholdExceeded")

    # Periodic budget update messages (no threshold crossed). Skip — they come
    # multiple times a day and would spam the channel.
    if threshold is None:
        return None

    if name == "free-tier-exceeded" and threshold >= 1.0:
        return (
            "warn",
            "⚠️ 無料枠超過",
            "ｽﾋﾟｷｦｲｼﾞﾒﾇﾝﾃﾞ…!\n無料枠を超過しました。これ以降は課金が発生する場合があります。",
            True,
        )

    if name == "monthly-spend-cap":
        if threshold >= 1.0:
            return (
                "crit",
                "🚨 月次予算超過",
                (
                    f"ｳｱｱ！ｽﾋﾟｷﾃﾞﾙｼﾞﾊﾞｯｾﾖ！！\n"
                    f"{_format_yen(CRITICAL_BUDGET_JPY)}を超過しました。"
                    "スピッキーの昼食代が～！！"
                ),
                True,
            )
        if threshold >= 0.8:
            return (
                "warn",
                "⚠️ 月次予算 80% 到達",
                f"月次予算 {_format_yen(CRITICAL_BUDGET_JPY)} の 80% に到達しました。",
                False,
            )
        if threshold >= 0.5:
            return (
                "info",
                "📊 月次予算 50% 到達",
                f"月次予算 {_format_yen(CRITICAL_BUDGET_JPY)} の 50% に到達しました。",
                False,
            )

    log.info("unhandled budget notification: name=%s threshold=%s", name, threshold)
    return None


def _build_embed(level: str, title: str, message: str, payload: dict) -> dict:
    color = {
        "info": COLOR_INFO,
        "warn": COLOR_WARN,
        "crit": COLOR_ERR,
    }.get(level, COLOR_INFO)

    cost = payload.get("costAmount", 0) or 0
    budget = payload.get("budgetAmount", 0) or 0
    interval_start = payload.get("costIntervalStart", "")
    interval_label = interval_start.split("T")[0] if interval_start else "-"

    return {
        "title": title,
        "description": message,
        "color": color,
        "fields": [
            {"name": "現在の消費", "value": _format_yen(cost), "inline": True},
            {"name": "予算", "value": _format_yen(budget), "inline": True},
            {"name": "集計開始", "value": interval_label, "inline": True},
        ],
        "footer": {"text": f"project: {PROJECT_ID}"},
        "timestamp": datetime.now(TZ).isoformat(),
    }


def _post_discord(webhook_url: str, embed: dict, mention_everyone: bool) -> None:
    body = {
        "username": "GCP Cost Alert",
        "embeds": [embed],
    }
    if mention_everyone:
        body["content"] = "@everyone"
        # Discord webhooks suppress pings by default; allowed_mentions.parse
        # must explicitly include "everyone" for the mention to actually ring.
        body["allowed_mentions"] = {"parse": ["everyone"]}

    req = urllib.request.Request(
        webhook_url,
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "User-Agent": "home-raspi-iac-cost-alert (+https://github.com/Riri-Inferno/home-raspi-iac, 1.0)",
        },
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        resp.read()


@functions_framework.cloud_event
def main(cloud_event) -> None:
    raw = cloud_event.data.get("message", {}).get("data", "")
    if not raw:
        log.warning("empty pub/sub message data, skipping")
        return

    try:
        payload = json.loads(base64.b64decode(raw))
    except Exception:
        log.exception("failed to decode pub/sub payload")
        return

    log.info("budget notification: %s", json.dumps(payload, ensure_ascii=False))

    classified = _classify(payload)
    if classified is None:
        return

    level, title, message, mention = classified

    if payload.get("_test"):
        title = f"[TEST] {title}"
        mention = False

    embed = _build_embed(level, title, message, payload)
    webhook_url = _fetch_webhook_url()
    _post_discord(webhook_url, embed, mention)
