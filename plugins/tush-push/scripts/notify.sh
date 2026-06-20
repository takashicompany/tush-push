#!/bin/bash

# stdinからJSONを読み取る
INPUT=$(cat)

# 認証情報の設定ファイル
CONFIG_FILE="$HOME/.config/tush-push/config.json"

# メッセージテンプレートファイル
GLOBAL_MESSAGES="$HOME/.config/tush-push/messages.json"

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
CWD=$(echo "$INPUT" | jq -r '.cwd // .workdir // .workspace.current_dir // empty' 2>/dev/null)
if [ -z "$CWD" ]; then
    CWD="$PWD"
fi

# 通知可否の判定
# 優先順位:
#   1. 環境変数 TUSH_PUSH (on/off) があればそれで確定（インスタンス単位の上書き）
#   2. なければ default_enabled に従う
#        true  → cwd が disabled_projects に含まれなければ通知（除外リスト方式）
#        false → cwd が enabled_projects に含まれていれば通知（許可リスト方式）

# 真偽値を on/off/空 に正規化する
normalize_bool() {
    case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
        on|1|true|yes|enable|enabled) echo "on" ;;
        off|0|false|no|disable|disabled) echo "off" ;;
        *) echo "" ;;
    esac
}

# config.json の指定キーの配列に CWD が含まれるか（含まれれば true=0）
cwd_in_list() {
    local key="$1"
    [ -f "$CONFIG_FILE" ] || return 1
    local cnt
    cnt=$(jq -r --arg cwd "$CWD" --arg k "$key" \
        '.[$k] // [] | map(select(. == $cwd)) | length' "$CONFIG_FILE" 2>/dev/null)
    [ "$cnt" -gt 0 ] 2>/dev/null
}

# 通知すべきなら 0、抑制すべきなら 1 を返す
should_notify() {
    # 1. 環境変数による上書き（最優先）
    local override
    override=$(normalize_bool "${TUSH_PUSH:-}")
    if [ "$override" = "on" ]; then return 0; fi
    if [ "$override" = "off" ]; then return 1; fi

    # 2. default_enabled に従う（省略時は true = 従来どおり基本ON）
    # 注意: jq の `//` は false を null 同様に扱い false→デフォルト値に化けるため使わない。
    # キー未設定(null)・true は "基本ON"、明示的な false のときだけ "基本OFF"。
    local default_enabled="true"
    if [ -f "$CONFIG_FILE" ]; then
        if [ "$(jq -r '.default_enabled' "$CONFIG_FILE" 2>/dev/null)" = "false" ]; then
            default_enabled="false"
        fi
    fi

    if [ "$default_enabled" = "true" ]; then
        # 除外リスト方式: disabled_projects に入っていれば抑制
        cwd_in_list "disabled_projects" && return 1
        return 0
    else
        # 許可リスト方式: enabled_projects に入っているときだけ通知
        cwd_in_list "enabled_projects" && return 0
        return 1
    fi
}

if ! should_notify; then
    exit 0
fi

# フォルダ名を取得
FOLDER_NAME=$(basename "$CWD")

# イベント種別を取得
normalize_event() {
    case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' _-')" in
        stop) echo "Stop" ;;
        permissionrequest) echo "PermissionRequest" ;;
        *) echo "" ;;
    esac
}

HOOK_EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // .hookEventName // .event // empty' 2>/dev/null)
if [ -z "$HOOK_EVENT" ]; then
    HOOK_EVENT="${TUSH_PUSH_HOOK_EVENT:-}"
fi
HOOK_EVENT=$(normalize_event "$HOOK_EVENT")
if [ -z "$HOOK_EVENT" ]; then
    exit 0
fi

# transcript_pathを取得
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // .transcriptPath // empty' 2>/dev/null)

# ホスト名を取得
HOSTNAME_VAL=$(hostname -s 2>/dev/null || hostname)

# 使用するテンプレートファイルを決定（ローカル → グローバル → デフォルト）
LOCAL_CODEX_MESSAGES="$CWD/.codex/tush-push/messages.json"
LOCAL_CLAUDE_MESSAGES="$CWD/.claude/tush-push/messages.json"
RUNTIME="${TUSH_PUSH_RUNTIME:-}"
if [ -z "$RUNTIME" ] && [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    RUNTIME="claude"
fi

MESSAGES_FILE=""
if [ "$RUNTIME" = "claude" ]; then
    if [ -f "$LOCAL_CLAUDE_MESSAGES" ]; then
        MESSAGES_FILE="$LOCAL_CLAUDE_MESSAGES"
    elif [ -f "$LOCAL_CODEX_MESSAGES" ]; then
        MESSAGES_FILE="$LOCAL_CODEX_MESSAGES"
    fi
else
    if [ -f "$LOCAL_CODEX_MESSAGES" ]; then
        MESSAGES_FILE="$LOCAL_CODEX_MESSAGES"
    elif [ -f "$LOCAL_CLAUDE_MESSAGES" ]; then
        MESSAGES_FILE="$LOCAL_CLAUDE_MESSAGES"
    fi
fi
if [ -z "$MESSAGES_FILE" ] && [ -f "$GLOBAL_MESSAGES" ]; then
    MESSAGES_FILE="$GLOBAL_MESSAGES"
fi

# テンプレートのキーから値を取得（イベント種別.フィールド形式）
# 引数: $1 = event key (stop / permission_request), $2 = field (title / message), $3 = default
get_template() {
    local event="$1"
    local field="$2"
    local default="$3"
    local value=""
    if [ -n "$MESSAGES_FILE" ]; then
        value=$(jq -r --arg e "$event" --arg f "$field" '.[$e][$f] // empty' "$MESSAGES_FILE" 2>/dev/null)
    fi
    if [ -z "$value" ]; then
        value="$default"
    fi
    echo "$value"
}

# プレースホルダ展開
# 引数: $1 = テンプレート文字列
expand_placeholders() {
    local template="$1"
    local result="$template"
    result="${result//\{project\}/$FOLDER_NAME}"
    result="${result//\{cwd\}/$CWD}"
    result="${result//\{response\}/$RESPONSE_TEXT}"
    result="${result//\{hostname\}/$HOSTNAME_VAL}"
    result="${result//\{event\}/$HOOK_EVENT}"
    result="${result//\{tool_name\}/$TOOL_NAME}"
    result="${result//\{tool_input\}/$TOOL_INPUT_SUMMARY}"
    echo "$result"
}

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

# プレースホルダ用変数の初期化
RESPONSE_TEXT=""
TOOL_NAME=""
TOOL_INPUT_SUMMARY=""

# PermissionRequest: バックグラウンドで10秒待機後に通知
if [ "$HOOK_EVENT" = "PermissionRequest" ]; then
    TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // .toolName // empty' 2>/dev/null)
    TOOL_INPUT_SUMMARY=$(echo "$INPUT" | jq -r '.tool_input // .toolInput // {} | to_entries | map(.key + ": " + (.value | tostring)) | join(", ")' 2>/dev/null)
    TOOL_INPUT_SUMMARY=$(echo "$TOOL_INPUT_SUMMARY" | cut -c1-100)

    TITLE_TPL=$(get_template "permission_request" "title" "【承認要求】{project}")
    MESSAGE_TPL=$(get_template "permission_request" "message" "{tool_name}
{tool_input}")

    TITLE=$(expand_placeholders "$TITLE_TPL")
    MESSAGE=$(expand_placeholders "$MESSAGE_TPL")

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

        # transcript_path がない場合は状態確認できないため通知する。
        # ある場合は行数が変化していなければ通知（まだ承認待ち）。
        if [ -z "$TRANSCRIPT_PATH" ] || [ "$INITIAL_LINES" -eq "$CURRENT_LINES" ]; then
            send_notification "$TITLE" "$MESSAGE"
        fi
    ) &
    disown
    exit 0
fi

# Stop: payload の last_assistant_message を使用
RESPONSE_TEXT=$(echo "$INPUT" | jq -r '.last_assistant_message // .lastAssistantMessage // .assistant_message // "" | gsub("\\s+"; " ") | ltrimstr(" ") | .[0:100]' 2>/dev/null)
if [ -z "$RESPONSE_TEXT" ]; then
    RESPONSE_TEXT="応答が完了しました"
fi

TITLE_TPL=$(get_template "stop" "title" "【作業完了】{project}")
MESSAGE_TPL=$(get_template "stop" "message" "{response}")

TITLE=$(expand_placeholders "$TITLE_TPL")
MESSAGE=$(expand_placeholders "$MESSAGE_TPL")

send_notification "$TITLE" "$MESSAGE"

exit 0
