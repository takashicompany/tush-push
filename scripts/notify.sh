#!/bin/bash

# stdinからJSONを読み取る
INPUT=$(cat)

# 設定ファイルのパス
CONFIG_FILE="$HOME/.config/tush-push/config.json"

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
    echo "Error: Pushover credentials not configured. Use /tush-push:setup to set up." >&2
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

# イベント種別を取得
HOOK_EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)

# transcript_pathを取得
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)

# Pushover通知を送信する関数
send_notification() {
    local title="$1"
    local message="$2"
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" \
        --form-string "token=$APP_TOKEN" \
        --form-string "user=$USER_KEY" \
        --form-string "title=$title" \
        --form-string "message=$message" \
        https://api.pushover.net/1/messages.json)

    if [ "$response" -ne 200 ]; then
        echo "Error: Pushover API returned HTTP $response" >&2
    fi
}

# PermissionRequest: バックグラウンドで10秒待機後に通知
if [ "$HOOK_EVENT" = "PermissionRequest" ]; then
    # ツール情報を取得
    TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
    TOOL_INPUT_SUMMARY=$(echo "$INPUT" | jq -r '.tool_input // {} | to_entries | map(.key + ": " + (.value | tostring)) | join(", ")' 2>/dev/null)
    TOOL_INPUT_SUMMARY=$(echo "$TOOL_INPUT_SUMMARY" | cut -c1-100)

    (
        # transcript_pathの現在の行数を記録
        INITIAL_LINES=0
        if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
            INITIAL_LINES=$(wc -l < "$TRANSCRIPT_PATH" | tr -d ' ')
        fi

        # 10秒待機
        sleep 10

        # 行数を再チェック
        CURRENT_LINES=0
        if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
            CURRENT_LINES=$(wc -l < "$TRANSCRIPT_PATH" | tr -d ' ')
        fi

        # 行数が変化していなければ通知（まだ承認待ち）
        if [ "$INITIAL_LINES" -eq "$CURRENT_LINES" ]; then
            MESSAGE="${TOOL_NAME}
${TOOL_INPUT_SUMMARY}"
            send_notification "【承認要求】${FOLDER_NAME}" "$MESSAGE"
        fi
    ) &
    disown
    exit 0
fi

# Stop: payload の last_assistant_message を使用
ASSISTANT_TEXT=$(echo "$INPUT" | jq -r '.last_assistant_message // "" | gsub("\\s+"; " ") | ltrimstr(" ") | .[0:100]' 2>/dev/null)

# メッセージを生成
if [ -n "$ASSISTANT_TEXT" ]; then
    MESSAGE="$ASSISTANT_TEXT"
else
    MESSAGE="応答が完了しました"
fi

send_notification "【作業完了】${FOLDER_NAME}" "$MESSAGE"

exit 0
