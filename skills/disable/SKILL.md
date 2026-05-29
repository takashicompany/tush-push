---
name: disable
description: 現在のプロジェクトのPushover通知を無効化する
disable-model-invocation: true
---

# tush-push:disable

現在のプロジェクト（作業ディレクトリ）の通知を**無効**にします。
`default_enabled` の値によって編集するリストが変わります（=「このプロジェクトは通知しない」という意図に統一）。

## 手順

1. 現在の作業ディレクトリ（cwd）のパスを取得する
2. `~/.config/tush-push/config.json` を読み込む（存在しない場合はデフォルト値で新規作成する）
3. `default_enabled` を確認する（キーが無い／`true` の場合は「基本ON」、`false` の場合は「基本OFF」）
4. 分岐:
   - **基本ON（除外リスト方式）の場合**: `disabled_projects` 配列に cwd を追加する（既にあれば「既に無効化されています」と表示）
   - **基本OFF（許可リスト方式）の場合**: `enabled_projects` 配列から cwd を削除する（元々無ければ「既に無効化されています」と表示）
5. 保存して結果を表示する

## 補足

- 特定の Claude Code インスタンス単位で確実に黙らせたい場合は、設定ファイルではなく起動時に環境変数 `TUSH_PUSH=off` を立てる方法もある（プロジェクト設定やデフォルトより優先される）。

## 実行方法

Bashツールで `jq` を使って `~/.config/tush-push/config.json` を読み書きする。
