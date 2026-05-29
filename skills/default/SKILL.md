---
name: default
description: 通知のグローバルなデフォルトモード（基本ON / 基本OFF）を切り替える
argument-hint: <on|off>
disable-model-invocation: true
---

# tush-push:default

このPC全体の通知のデフォルト挙動（`default_enabled`）を切り替えます。

- `on`  … 基本ON。`disabled_projects` に登録したプロジェクトだけ黙る（**除外リスト方式**・従来の挙動）。
- `off` … 基本OFF。`enabled_projects` に登録したプロジェクトだけ通知する（**許可リスト方式**）。

いずれのモードでも、起動時の環境変数 `TUSH_PUSH=on|off` はプロジェクト設定やデフォルトより優先される。

## 手順

1. 引数 `$0` を受け取る（`on` または `off`）。それ以外・未指定ならエラーメッセージを表示して終了する
2. `~/.config/tush-push/` が無ければ作成する
3. `~/.config/tush-push/config.json` を読み込む（無ければデフォルト値で新規作成）
4. `default_enabled` を `on→true` / `off→false` に設定して保存する（他のキーは維持する）
5. 結果を表示する。基本OFFに切り替えた場合は「通知したいプロジェクトは `/tush-push:enable` で登録するか、起動時に `TUSH_PUSH=on` を立ててください」と案内する

## 引数

- `$0`: `on` または `off`（必須）

## 実行方法

Bashツールで `jq` を使って `~/.config/tush-push/config.json` を読み書きする。
