---
name: disable
description: 現在のプロジェクトのPushover通知を無効化する
disable-model-invocation: true
---

# tush-push:disable

現在のプロジェクト（作業ディレクトリ）をtush-pushの通知無効リストに追加します。

## 手順

1. 現在の作業ディレクトリ（cwd）のパスを取得する
2. `~/.config/tush-push/config.json` を読み込む（存在しない場合はデフォルト値で新規作成する）
3. `disabled_projects` 配列に現在のcwdが既に含まれているか確認する
4. 含まれていない場合はcwdを `disabled_projects` に追加して保存する
5. 既に含まれている場合は「既に無効化されています」と表示する
6. 完了したら結果を表示する

## 実行方法

Bashツールで `jq` を使って `~/.config/tush-push/config.json` を読み書きする。
