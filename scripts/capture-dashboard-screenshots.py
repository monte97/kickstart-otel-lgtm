#!/usr/bin/env python3
"""
capture-dashboard-screenshots.py

Captures 1920x1080 WebP screenshots of all Grafana dashboards and saves them
to docs/dashboards/images/. Run after a k6 load test so panels have data.

Usage:
    python3 scripts/capture-dashboard-screenshots.py [--time-range 30m]

Requirements:
    pip install playwright
    playwright install chromium
"""

import argparse
import io
import sys
from pathlib import Path
from PIL import Image
from playwright.sync_api import sync_playwright, TimeoutError as PWTimeout

# ── Configuration ────────────────────────────────────────────────────────────

GRAFANA_URL = "http://localhost:3000"
USERNAME    = "admin"
PASSWORD    = "admin"
VIEWPORT    = {"width": 1920, "height": 1080}
OUTPUT_DIR  = Path(__file__).parent.parent / "docs" / "dashboards" / "images"

# Each entry: (filename_stem, grafana_path, extra_params)
DASHBOARDS = [
    (
        "service-overview",
        "/d/service-overview/service-overview",
        {},
    ),
    (
        "traces-explorer",
        "/d/traces-explorer-tempo/traces-explorer",
        {},
    ),
    (
        "logs-explorer",
        "/d/logs-explorer-loki/logs-explorer",
        {"var-app": "shop-api"},
    ),
    (
        "slo-dashboard",
        "/d/slo-dashboard-mimir/slo-dashboard",
        {"var-window": "30d", "from": "now-1h", "to": "now"},
    ),
    (
        "alerting-overview",
        "/d/alerting-overview/alerting-overview",
        {},
    ),
    (
        "infrastructure",
        "/d/infrastructure/infrastructure",
        {},
    ),
    (
        "infra-full-observability",
        "/d/infra-full-observability/infrastructure-full-observability",
        {},
    ),
    (
        "otel-collector-health",
        "/d/otel-collector-health/otel-collector-health",
        {},
    ),
]


# ── Helpers ──────────────────────────────────────────────────────────────────

def build_url(path: str, time_range: str, extra: dict) -> str:
    params = {"from": f"now-{time_range}", "to": "now", "theme": "dark"}
    params.update(extra)
    qs = "&".join(f"{k}={v}" for k, v in params.items())
    return f"{GRAFANA_URL}{path}?{qs}"


def dismiss_overlays(page) -> None:
    """Close any Grafana modals or cookie banners that block the view."""
    for selector in [
        "button[aria-label='Close']",
        "button[data-testid='data-testid Close']",
        "button:has-text('Got it')",
        "button:has-text('Dismiss')",
        "button:has-text('No, keep existing')",
    ]:
        try:
            btn = page.locator(selector).first
            if btn.is_visible(timeout=500):
                btn.click()
                page.wait_for_timeout(300)
        except Exception:
            pass


def wait_for_panels(page, timeout_ms: int = 45_000) -> None:
    """Wait until Grafana panels are rendered."""
    # Wait for at least one panel header to appear (Grafana 12)
    # Uses *=  (contains) because data-testid is "Panel header <title>"
    try:
        page.wait_for_selector("[data-testid*='Panel header']", timeout=timeout_ms)
    except PWTimeout:
        print("    ⚠  No panels found — dashboard may be empty or still loading")
        return

    # Wait for uplot canvases (time series charts) to render
    try:
        page.wait_for_selector(".uplot-main-div canvas, svg.uplot-select", timeout=15_000)
    except PWTimeout:
        pass  # stat/table panels have no canvas — that's fine

    # Extra settle time for animations and chart rendering
    page.wait_for_timeout(2500)


def login(page) -> None:
    """Log in to Grafana (only needed if anonymous access is off)."""
    page.goto(f"{GRAFANA_URL}/login", wait_until="networkidle")
    if page.url.endswith("/login"):
        page.fill("input[name='user']", USERNAME)
        page.fill("input[name='password']", PASSWORD)
        page.click("button[type='submit']")
        page.wait_for_url(f"{GRAFANA_URL}/**", timeout=10_000)
        print("  ✓ Logged in")


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Capture Grafana dashboard screenshots")
    parser.add_argument(
        "--time-range",
        default="30m",
        help="Grafana time range for all dashboards (default: 30m). E.g. '1h', '6h'.",
    )
    parser.add_argument(
        "--only",
        default=None,
        help="Capture only this dashboard stem (e.g. 'service-overview'). Useful for retakes.",
    )
    args = parser.parse_args()

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    dashboards = DASHBOARDS
    if args.only:
        dashboards = [d for d in DASHBOARDS if d[0] == args.only]
        if not dashboards:
            print(f"❌ Dashboard '{args.only}' not found. Valid names:")
            for stem, _, _ in DASHBOARDS:
                print(f"   {stem}")
            sys.exit(1)

    print(f"📸 Capturing {len(dashboards)} dashboard(s) → {OUTPUT_DIR}\n")

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            viewport=VIEWPORT,
            device_scale_factor=1,
        )
        page = context.new_page()

        # Log in once
        login(page)

        for stem, path, extra in dashboards:
            url = build_url(path, args.time_range, extra)
            out_file = OUTPUT_DIR / f"{stem}.webp"

            print(f"  → {stem}")
            print(f"     {url}")

            try:
                page.goto(url, wait_until="domcontentloaded", timeout=30_000)
                dismiss_overlays(page)
                wait_for_panels(page)
                dismiss_overlays(page)  # catch any deferred modals

                # Playwright doesn't support webp natively — capture PNG then convert
                png_bytes = page.screenshot(
                    type="png",
                    full_page=False,  # viewport only — keeps 1920×1080
                )
                img = Image.open(io.BytesIO(png_bytes))
                img.save(str(out_file), "webp", quality=90, method=6)
                print(f"     ✓ saved {out_file.name}")

            except PWTimeout:
                print(f"     ✗ timeout loading {url}")
            except Exception as e:
                print(f"     ✗ error: {e}")

        browser.close()

    print(f"\n✅ Done. Screenshots saved to {OUTPUT_DIR}")
    print("   Uncomment the <!-- screenshot --> lines in each .md file to activate them.")


if __name__ == "__main__":
    main()
