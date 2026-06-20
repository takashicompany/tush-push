# tush-push

Claude Code と Codex の応答完了時・承認待ち時にPushover経由でプッシュ通知を送るプラグイン。

## 概要

Claude Code / Codex プラグインとして動作し、以下の2つのイベントでPushover通知を送信する:
- **Stop**: 応答完了時に即座に通知。メッセージには返答の先頭100文字が含まれる。
- **PermissionRequest**: ツール使用の承認待ち時に通知。10秒間未応答の場合のみ通知を送信する。

## ディレクトリ構成

```
tush-push/
├── .claude-plugin/
│   └── plugin.json              # Claude Codeプラグインマニフェスト
├── .codex-plugin/
│   └── plugin.json              # Codexプラグインマニフェスト
├── .agents/plugins/
│   └── marketplace.json         # Codex personal marketplace定義
├── hooks/
│   └── hooks.json               # Stop / PermissionRequest hookの定義
├── plugins/
│   └── tush-push/              # Codex marketplace向け配布bundle
├── tools/
│   └── sync-codex-bundle.sh     # Codex配布bundleの再生成
├── skills/
│   ├── setup/
│   │   └── SKILL.md             # /tush-push:setup — 認証情報の設定
│   ├── disable/
│   │   └── SKILL.md             # /tush-push:disable — 通知の無効化
│   ├── enable/
│   │   └── SKILL.md             # /tush-push:enable — 通知の有効化
│   └── default/
│       └── SKILL.md             # /tush-push:default — デフォルトモード切替
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
  "default_enabled": true,
  "disabled_projects": [],
  "enabled_projects": []
}
```

## 通知可否の判定

通知を送るかどうかは以下の優先順で決まる（上が優先）:

1. **環境変数 `TUSH_PUSH`**（インスタンス単位の上書き・最優先）
   - `on`/`1`/`true`/`yes`/`enable`/`enabled` → 必ず通知
   - `off`/`0`/`false`/`no`/`disable`/`disabled` → 必ず黙る
   - 未設定 → 下のロジックへ
2. **`default_enabled`**（このPCのデフォルト。キーが無い／`true` なら基本ON、`false` なら基本OFF）
   - 基本ON（**除外リスト方式**）: cwd が `disabled_projects` に含まれれば黙る、それ以外は通知
   - 基本OFF（**許可リスト方式**）: cwd が `enabled_projects` に含まれれば通知、それ以外は黙る

環境変数方式は headlenss などの起動ラッパーが「このtmux内のClaude Codeだけ通知ON」を実現するための汎用フック。tush-push 自体は特定ツールに依存しない（`TUSH_PUSH=on claude` のように誰でも使える）。

> 注: jq の `//` 演算子は `false` を null 同様に扱うため、`default_enabled` の判定では `.default_enabled // true` を使わず明示的に `false` 判定している。

## Codex配布

Codex marketplace は repo root ではなく plugin folder を指す必要があるため、`plugins/tush-push/` をCodex向け配布bundleとして管理する。

- Claude Code向けの既存構成はrepo rootに残す
- Codex向け marketplace は `.agents/plugins/marketplace.json` から `./plugins/tush-push` を指す
- root側の `.codex-plugin`、`hooks`、`scripts`、`skills` などを更新したら、`tools/sync-codex-bundle.sh` を実行して配布bundleを再生成する

## スキル

- `/tush-push:setup <app_token> <user_key>` — 認証情報を設定ファイルに保存
- `/tush-push:disable` — 現在のプロジェクトの通知を無効化（モードに応じて編集リストが変わる）
- `/tush-push:enable` — 現在のプロジェクトの通知を有効化（モードに応じて編集リストが変わる）
- `/tush-push:default <on\|off>` — グローバルのデフォルトモードを切り替え

## メッセージテンプレート

通知のタイトルと本文をプロジェクトごと・端末ごとにカスタマイズできる。
実行元ごとのローカル設定、もう一方のローカル設定、グローバルの順で、ファイル単位で先勝ち。

### 探索順（**ファイル単位**で先勝ち）
Codex実行時:
1. Codexローカル: `<cwd>/.codex/tush-push/messages.json`
2. Claudeローカル: `<cwd>/.claude/tush-push/messages.json`
3. グローバル: `~/.config/tush-push/messages.json`
4. デフォルト（notify.sh内のハードコード）

Claude実行時:
1. Claudeローカル: `<cwd>/.claude/tush-push/messages.json`
2. Codexローカル: `<cwd>/.codex/tush-push/messages.json`
3. グローバル: `~/.config/tush-push/messages.json`
4. デフォルト（notify.sh内のハードコード）

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
- `hook_event_name`、`hookEventName`、`event`、または hook 定義から渡される `TUSH_PUSH_HOOK_EVENT` でイベント種別を判別し、未知イベントは通知せず終了
- `cwd`、`workdir`、`workspace.current_dir` のいずれかの `basename` でフォルダ名を取得
- 「通知可否の判定」（環境変数 `TUSH_PUSH` → `default_enabled` + プロジェクトリスト）に従い、抑制対象なら即 exit 0
- エラー時はstderrに出力し、常にexit 0で終了

### Stopイベント
- `last_assistant_message`、`lastAssistantMessage`、`assistant_message` のいずれかから応答テキストを取得（先頭100文字）→ `{response}`
- メッセージテンプレートを展開して即座にPushover通知を送信

### PermissionRequestイベント
- バックグラウンドプロセスをforkして即座にexit 0
- バックグラウンド: `transcript_path` の行数を記録し、10秒sleep
- 10秒後に行数が変化していなければメッセージテンプレートを展開して通知
- 行数が増えていれば既に操作済みなので通知スキップ
