---
name: enable
description: 現在のプロジェクトのPushover通知を有効化する（無効リストから削除）
disable-model-invocation: true
---

# ccpush:enable

現在のプロジェクト（作業ディレクトリ）をccpushの通知無効リストから削除し、通知を再度有効にします。

## 手順

1. 現在の作業ディレクトリ（cwd）のパスを取得する
2. `~/.config/ccpush/config.json` を読み込む（存在しない場合は「設定ファイルがありません」と表示する）
3. `disabled_projects` 配列から現在のcwdを削除して保存する
4. cwdが `disabled_projects` に含まれていなかった場合は「既に有効化されています」と表示する
5. 完了したら結果を表示する

## 実行方法

Bashツールで `jq` を使って `~/.config/ccpush/config.json` を読み書きする。
