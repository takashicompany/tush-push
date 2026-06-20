---
name: setup
description: Pushoverの認証情報（アプリトークンとユーザーキー）を設定する
argument-hint: <app_token> <user_key>
disable-model-invocation: false
---

# tush-push:setup

Pushoverの認証情報を `~/.config/tush-push/config.json` に保存します。

## 手順

1. 引数からアプリトークン(`$0`)とユーザーキー(`$1`)を受け取る
2. 両方の引数が指定されていない場合はエラーメッセージを表示して終了する
3. `~/.config/tush-push/` ディレクトリが存在しなければ作成する
4. `~/.config/tush-push/config.json` が既に存在する場合は読み込み、`pushover_app_token` と `pushover_user_key` のみを上書きする（`disabled_projects` 等の既存設定は維持する）
5. 存在しない場合は新規に作成する:
   ```json
   {
     "pushover_app_token": "<app_token>",
     "pushover_user_key": "<user_key>",
     "default_enabled": true,
     "disabled_projects": [],
     "enabled_projects": []
   }
   ```
6. 保存が完了したら成功メッセージを表示する

## 実行方法

Bashツールで `jq` を使って `~/.config/tush-push/config.json` を読み書きする。

## 引数

- `$0`: Pushoverアプリトークン（必須）
- `$1`: Pushoverユーザーキー（必須）
