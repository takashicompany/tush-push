#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# .envファイルから環境変数を読み込む
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
fi

# 必須パラメータのチェック
if [ -z "$PUSHOVER_APP_TOKEN" ] || [ -z "$PUSHOVER_USER_KEY" ]; then
    echo "Error: PUSHOVER_APP_TOKEN and PUSHOVER_USER_KEY must be set" >&2
    exit 0
fi

# Pushover APIにプッシュ通知を送信
response=$(curl -s -o /dev/null -w "%{http_code}" \
    --form-string "token=$PUSHOVER_APP_TOKEN" \
    --form-string "user=$PUSHOVER_USER_KEY" \
    --form-string "title=Claude Code" \
    --form-string "message=Claude Codeの応答が完了しました" \
    https://api.pushover.net/1/messages.json)

if [ "$response" -ne 200 ]; then
    echo "Error: Pushover API returned HTTP $response" >&2
fi

exit 0
