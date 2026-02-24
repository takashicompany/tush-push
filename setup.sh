#!/bin/bash

# jqの存在確認
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed." >&2
    exit 1
fi

# notify.shの絶対パスを取得
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NOTIFY_PATH="$SCRIPT_DIR/notify.sh"

if [ ! -f "$NOTIFY_PATH" ]; then
    echo "Error: notify.sh not found at $NOTIFY_PATH" >&2
    exit 1
fi

SETTINGS_FILE="$HOME/.claude/settings.json"
SETTINGS_DIR="$HOME/.claude"

# .claudeディレクトリがなければ作成
if [ ! -d "$SETTINGS_DIR" ]; then
    mkdir -p "$SETTINGS_DIR"
fi

# 新しいhookエントリ
HOOK_ENTRY=$(jq -n --arg cmd "$NOTIFY_PATH" '{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": $cmd
          }
        ]
      }
    ]
  }
}')

if [ ! -f "$SETTINGS_FILE" ]; then
    # settings.jsonが存在しない場合、新規作成
    echo "$HOOK_ENTRY" > "$SETTINGS_FILE"
    echo "settings.json を作成し、Stop hookを登録しました。"
else
    # 既存のsettings.jsonとマージ
    EXISTING=$(cat "$SETTINGS_FILE")

    # 既にnotify.shが登録されているか確認
    if echo "$EXISTING" | jq -e --arg cmd "$NOTIFY_PATH" '
        .hooks.Stop[]?.hooks[]? | select(.command == $cmd)
    ' > /dev/null 2>&1; then
        echo "notify.sh は既にStop hookに登録されています。"
        exit 0
    fi

    # 既存のStop hookがあるかチェック
    if echo "$EXISTING" | jq -e '.hooks.Stop' > /dev/null 2>&1; then
        # 既存のStop hook配列に新しいエントリを追加
        MERGED=$(echo "$EXISTING" | jq --arg cmd "$NOTIFY_PATH" '
            .hooks.Stop += [
                {
                    "hooks": [
                        {
                            "type": "command",
                            "command": $cmd
                        }
                    ]
                }
            ]
        ')
    else
        # hooksキーがあるがStopがない、またはhooksキー自体がない場合
        MERGED=$(echo "$EXISTING" | jq --arg cmd "$NOTIFY_PATH" '
            .hooks.Stop = [
                {
                    "hooks": [
                        {
                            "type": "command",
                            "command": $cmd
                        }
                    ]
                }
            ]
        ')
    fi

    echo "$MERGED" > "$SETTINGS_FILE"
    echo "既存のsettings.jsonにStop hookを追加しました。"
fi
