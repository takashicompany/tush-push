#!/bin/bash

# stdinからJSONを読み取る
INPUT=$(cat)

# 設定ファイルのパス
CONFIG_FILE="$HOME/.config/ccpush/config.json"

# 認証情報の取得（環境変数 → config.json の順で優先）
APP_TOKEN="${PUSHOVER_APP_TOKEN:-}"
USER_KEY="${PUSHOVER_USER_KEY:-}"

if [ -f "$CONFIG_FILE" ]; then
    if [ -z "$APP_TOKEN" ]; then
        APP_TOKEN=$(jq -r '.pushover_app_token // empty' "$CONFIG_FILE" 2>/dev/null)
    fi
    if [ -z "$USER_KEY" ]; then
        USER_KEY=$(jq -r '.pushover_user_key // empty' "$CONFIG_FILE" 2>/dev/null)
    fi
fi

# 認証情報が未設定ならエラーを出して終了
if [ -z "$APP_TOKEN" ] || [ -z "$USER_KEY" ]; then
    echo "Error: Pushover credentials not configured. Use /ccpush:setup to set up." >&2
    exit 0
fi

# cwdの取得
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
if [ -z "$CWD" ]; then
    CWD="$PWD"
fi

# disabled_projectsのチェック
if [ -f "$CONFIG_FILE" ]; then
    DISABLED=$(jq -r --arg cwd "$CWD" '
        .disabled_projects // [] | map(select(. == $cwd)) | length
    ' "$CONFIG_FILE" 2>/dev/null)
    if [ "$DISABLED" -gt 0 ] 2>/dev/null; then
        exit 0
    fi
fi

# フォルダ名を取得
FOLDER_NAME=$(basename "$CWD")

# transcript_pathから最後のアシスタントテキストを取得（先頭100文字）
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
ASSISTANT_TEXT=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    ASSISTANT_TEXT=$(grep '"type":"assistant"' "$TRANSCRIPT_PATH" | jq -rs '[.[] | (.message.content // [])[] | select(.type=="text") | .text] | last // "" | gsub("\\n+"; " ") | gsub("\\s+"; " ") | ltrimstr(" ") | .[0:100]' 2>/dev/null)
fi

# メッセージを生成
if [ -n "$ASSISTANT_TEXT" ]; then
    MESSAGE="$ASSISTANT_TEXT"
else
    MESSAGE="応答が完了しました"
fi

# Pushover APIにプッシュ通知を送信
response=$(curl -s -o /dev/null -w "%{http_code}" \
    --form-string "token=$APP_TOKEN" \
    --form-string "user=$USER_KEY" \
    --form-string "title=${FOLDER_NAME} : Claude Code" \
    --form-string "message=$MESSAGE" \
    https://api.pushover.net/1/messages.json)

if [ "$response" -ne 200 ]; then
    echo "Error: Pushover API returned HTTP $response" >&2
fi

exit 0
