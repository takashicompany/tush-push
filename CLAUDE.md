# ccpush

Claude Codeの応答完了時にPushover経由でプッシュ通知を送るプラグイン。

## 概要

Claude Codeプラグインとして動作し、`Stop` hookで応答完了時にPushover通知を送信する。通知メッセージには `<フォルダ名> 返答の先頭100文字...` が含まれる。

## ディレクトリ構成

```
ccpush/
├── .claude-plugin/
│   └── plugin.json              # プラグインマニフェスト
├── hooks/
│   └── hooks.json               # Stop hookの定義
├── skills/
│   ├── setup/
│   │   └── SKILL.md             # /ccpush:setup — 認証情報の設定
│   ├── disable/
│   │   └── SKILL.md             # /ccpush:disable — 通知の無効化
│   └── enable/
│       └── SKILL.md             # /ccpush:enable — 通知の有効化
├── scripts/
│   └── notify.sh                # 通知スクリプト
├── .env.example                 # 認証情報テンプレート（参考用）
├── .gitignore
└── CLAUDE.md
```

## 認証情報

認証情報は以下の優先順で取得される:
1. 環境変数 (`PUSHOVER_APP_TOKEN`, `PUSHOVER_USER_KEY`)
2. 設定ファイル (`~/.config/ccpush/config.json`)

設定ファイルのフォーマット:
```json
{
  "pushover_app_token": "xxx",
  "pushover_user_key": "yyy",
  "disabled_projects": []
}
```

## スキル

- `/ccpush:setup <app_token> <user_key>` — 認証情報を設定ファイルに保存
- `/ccpush:disable` — 現在のプロジェクトの通知を無効化
- `/ccpush:enable` — 現在のプロジェクトの通知を有効化

## 通知スクリプト (scripts/notify.sh)

- stdinからStop hookのJSONを受け取る
- `cwd` の `basename` でフォルダ名を取得
- `last_assistant_message` の先頭100文字を切り出しメッセージに含める
- `disabled_projects` に含まれるプロジェクトは通知をスキップ
- エラー時はstderrに出力し、常にexit 0で終了
