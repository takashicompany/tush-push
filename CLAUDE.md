# tush-push

Claude Codeの応答完了時・承認待ち時にPushover経由でプッシュ通知を送るプラグイン。

## 概要

Claude Codeプラグインとして動作し、以下の2つのイベントでPushover通知を送信する:
- **Stop**: 応答完了時に即座に通知。メッセージには返答の先頭100文字が含まれる。
- **PermissionRequest**: ツール使用の承認待ち時に通知。10秒間未応答の場合のみ通知を送信する。

## ディレクトリ構成

```
tush-push/
├── .claude-plugin/
│   └── plugin.json              # プラグインマニフェスト
├── hooks/
│   └── hooks.json               # Stop / PermissionRequest hookの定義
├── skills/
│   ├── setup/
│   │   └── SKILL.md             # /tush-push:setup — 認証情報の設定
│   ├── disable/
│   │   └── SKILL.md             # /tush-push:disable — 通知の無効化
│   └── enable/
│       └── SKILL.md             # /tush-push:enable — 通知の有効化
├── scripts/
│   └── notify.sh                # 通知スクリプト
├── .env.example                 # 認証情報テンプレート（参考用）
├── messages.example.json        # メッセージテンプレートのサンプル
├── .gitignore
└── CLAUDE.md
```

## 認証情報

認証情報は以下の優先順で取得される:
1. 環境変数 (`PUSHOVER_APP_TOKEN`, `PUSHOVER_USER_KEY`)
2. 設定ファイル (`~/.config/tush-push/config.json`)

設定ファイルのフォーマット:
```json
{
  "pushover_app_token": "xxx",
  "pushover_user_key": "yyy",
  "disabled_projects": []
}
```

## スキル

- `/tush-push:setup <app_token> <user_key>` — 認証情報を設定ファイルに保存
- `/tush-push:disable` — 現在のプロジェクトの通知を無効化
- `/tush-push:enable` — 現在のプロジェクトの通知を有効化

## メッセージテンプレート

通知のタイトルと本文をプロジェクトごと・端末ごとにカスタマイズできる。
2枚構成（ローカル / グローバル）で、Claude Code本体の設定と同様にローカル優先。

### 探索順（**ファイル単位**で先勝ち）
1. ローカル: `<cwd>/.claude/tush-push/messages.json`
2. グローバル: `~/.config/tush-push/messages.json`
3. デフォルト（notify.sh内のハードコード）

ローカルファイルが存在する場合、その内容のみが使われる（グローバルとフィールド単位のマージはしない）。

### フォーマット

```json
{
  "stop": {
    "title": "【作業完了】{project}",
    "message": "{response}"
  },
  "permission_request": {
    "title": "【承認要求】{project}",
    "message": "{tool_name}\n{tool_input}"
  }
}
```

各イベントで `title` / `message` のいずれかが欠けている場合、その欠けたフィールドのみデフォルトにフォールバックする。

### プレースホルダ

| キー | 内容 | 利用可能イベント |
|---|---|---|
| `{project}` | cwdのbasename | 全イベント |
| `{cwd}` | cwdのフルパス | 全イベント |
| `{response}` | 最後のアシスタント応答（先頭100文字） | Stop |
| `{hostname}` | 端末のホスト名（`hostname -s`） | 全イベント |
| `{event}` | hook_event_name | 全イベント |
| `{tool_name}` | 承認対象ツール名 | PermissionRequest |
| `{tool_input}` | tool_inputのkey:value一覧（先頭100文字） | PermissionRequest |

## 通知スクリプト (scripts/notify.sh)

- stdinからhook JSONを受け取る
- `hook_event_name` でイベント種別を判別
- `cwd` の `basename` でフォルダ名を取得
- `disabled_projects` に含まれるプロジェクトは通知をスキップ
- エラー時はstderrに出力し、常にexit 0で終了

### Stopイベント
- `last_assistant_message` から応答テキストを取得（先頭100文字）→ `{response}`
- メッセージテンプレートを展開して即座にPushover通知を送信

### PermissionRequestイベント
- バックグラウンドプロセスをforkして即座にexit 0
- バックグラウンド: `transcript_path` の行数を記録し、10秒sleep
- 10秒後に行数が変化していなければメッセージテンプレートを展開して通知
- 行数が増えていれば既に操作済みなので通知スキップ
