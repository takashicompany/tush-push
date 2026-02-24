# ccpush

Claude Codeの応答完了時にPushover経由でプッシュ通知を送るツール。

## 概要

Claude Codeの`Stop` hookを利用し、Claudeがレスポンスを返し終わったタイミングでPushoverにプッシュ通知を送信する。

## 要件

### 通知スクリプト
- シェルスクリプト(`notify.sh`)でPushover APIを呼び出す
- エンドポイント: `POST https://api.pushover.net/1/messages.json`
- 必須パラメータ: `token`(アプリAPIトークン), `user`(ユーザーキー), `message`(通知メッセージ)
- トークン等の認証情報は環境変数(`PUSHOVER_APP_TOKEN`, `PUSHOVER_USER_KEY`)から読み取る
- `.env`ファイルからも読み込めるようにする（`.env.example`をテンプレートとして用意）
- curlを使用して送信する
- 通知メッセージは「Claude Codeの応答が完了しました」程度のシンプルなもの
- titleは「Claude Code」とする
- APIエラー時は標準エラー出力にログを出す（hookの動作を妨げないようexit 0で終了する）

### セットアップスクリプト
- `setup.sh`を用意し、Claude Codeの`Stop` hookに`notify.sh`を登録する処理を行う
- hookの設定先は `~/.claude/settings.json`
- 既存のsettings.jsonがある場合はマージする（既存設定を壊さない）
- jqを使用してJSONを操作する

### hookの設定形式
Claude Codeの`Stop` hookは以下の形式:
```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/absolute/path/to/notify.sh"
          }
        ]
      }
    ]
  }
}
```

### その他
- `.gitignore`に`.env`を含める
- READMEは不要（CLAUDE.mdで十分）
- gitリポジトリとして初期化する
- 完成したらコミットする
