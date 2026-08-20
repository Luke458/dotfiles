#!/usr/bin/env bash
set -u

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell"
CACHE_FILE="$CACHE_DIR/btc_chart.json"

read_cache_or_error() {
    if [ -s "$CACHE_FILE" ] && jq -e '.error == false and (.prices | length > 1)' "$CACHE_FILE" >/dev/null 2>&1; then
        jq -c '. + {stale: true}' "$CACHE_FILE"
    else
        printf '%s\n' '{"error":true}'
    fi
}

fail_with_cache() {
    read_cache_or_error
    exit 0
}

command -v curl >/dev/null 2>&1 || fail_with_cache
command -v jq >/dev/null 2>&1 || fail_with_cache

fetch() {
    curl -fsSL --connect-timeout 5 --max-time 12 --retry 1 "$1"
}

# Fetch 24h price history from CoinGecko.
CHART=$(fetch "https://api.coingecko.com/api/v3/coins/bitcoin/market_chart?vs_currency=usd&days=1&precision=0") || fail_with_cache

# Fetch current stats (price, change, high, low).
STATS=$(fetch "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&ids=bitcoin&price_change_percentage=24h") || fail_with_cache

# Fetch AUD spot price from Coinbase.
AUD_JSON=$(fetch "https://api.coinbase.com/v2/prices/BTC-AUD/spot") || fail_with_cache

# Extract price-only array from chart [[ts, price], ...] -> [price, ...].
PRICES=$(jq -c '[.prices[][1] | select(type == "number")]' <<<"$CHART") || fail_with_cache

# Extract stats fields.
CURRENT=$(jq -r '.[0].current_price // empty' <<<"$STATS") || fail_with_cache
CHANGE=$(jq -r '.[0].price_change_percentage_24h // 0' <<<"$STATS") || fail_with_cache
HIGH=$(jq -r '.[0].high_24h // empty' <<<"$STATS") || fail_with_cache
LOW=$(jq -r '.[0].low_24h // empty' <<<"$STATS") || fail_with_cache

# AUD price (round to integer).
AUD=$(jq -r '(.data.amount | tonumber | floor) // empty' <<<"$AUD_JSON") || fail_with_cache

# Validate we got sensible data.
if [ -z "$CURRENT" ] || [ -z "$HIGH" ] || [ -z "$LOW" ] || [ -z "$AUD" ] || [ "$(jq 'length' <<<"$PRICES")" -le 1 ]; then
    fail_with_cache
fi

OUTPUT=$(jq -n -c \
    --argjson prices  "$PRICES"  \
    --argjson current "$CURRENT" \
    --argjson change  "$CHANGE"  \
    --argjson high    "$HIGH"    \
    --argjson low     "$LOW"     \
    --argjson aud     "$AUD"     \
    --argjson fetched "$(date +%s)" \
    '{prices: $prices, current_usd: $current, change_pct: $change, high_24h: $high, low_24h: $low, current_aud: $aud, error: false, stale: false, fetched_at: $fetched}') || fail_with_cache

mkdir -p "$CACHE_DIR" 2>/dev/null && {
    TMP_FILE="$CACHE_FILE.$$"
    printf '%s\n' "$OUTPUT" >"$TMP_FILE" && mv "$TMP_FILE" "$CACHE_FILE"
}

printf '%s\n' "$OUTPUT"
