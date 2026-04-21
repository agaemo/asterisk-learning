# CLAUDE.md

## プロジェクト概要

AWS上にAsterisk PBXサーバーを構築し、SIP softphone（Zoiper）を使った内線通話・Twilio経由の実番号発着信を学習するためのIaCプロジェクト。

**プロジェクト:** asterisk-learning
**スタック:** Terraform / AWS EC2 / Asterisk 20 / Ubuntu 24.04
**目標:** 電話SaaSの基盤技術（Asterisk・SIP・RTP）を実際に動かして理解する

---

## アーキテクチャ

単一EC2インスタンスにAsteriskをインストールし、Elastic IPで固定。
SIP softphone（Zoiper）をクライアントとして使用する。

```
asterisk-learning/
├── terraform/           ← IaC（VPC・EC2・SG・Elastic IP）
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       ├── vpc/
│       ├── ec2/
│       └── sg/
├── asterisk/            ← Asterisk設定ファイル（EC2にrsyncまたはUser Dataで転送）
│   ├── extensions.conf  ← ダイヤルプラン
│   ├── pjsip.conf.template  ← SIPピア設定テンプレート（git管理。実ファイルはgitignore）
│   └── rtp.conf         ← RTPポート設定
├── scripts/
│   └── install.sh       ← Asteriskインストールスクリプト（User Dataで実行）
├── docs/
│   └── requirements.md
└── README.md
```

---

## 開発ワークフロー

```bash
# インフラ構築
terraform -chdir=terraform init
terraform -chdir=terraform plan
terraform -chdir=terraform apply

# 設定ファイルをEC2に転送
rsync -av asterisk/ ubuntu@<EC2_IP>:/etc/asterisk/

# Asterisk再起動
ssh ubuntu@<EC2_IP> "sudo systemctl restart asterisk"

# インフラ削除（学習終了後）
terraform -chdir=terraform destroy
```

---

## 必ず守るルール

### ワークフロー
- 新規機能・設定変更は必ず `planner` エージェントで計画を立ててから実施すること。
- 実装完了後は `verify` → `security-reviewer` → `code-reviewer` の順でレビューすること。
- `on-stop` フックがファイル変更を報告した場合、次のタスクの前に `code-reviewer` を実行すること。

### IaC・セキュリティ
- `terraform apply` 前に必ず `terraform plan` を確認すること。
- `terraform destroy` は必ずユーザーに確認を取ってから実行すること。
- Security Groupは最小権限（自分のIPのみ開放）を守ること。
- AWSクレデンシャル・Twilioトークンなどのシークレットは `.env` ファイルで管理し、絶対にgitにコミットしないこと。
- SSH秘密鍵はgitにコミットしないこと。

### コードスタイル
- Terraformは `terraform fmt` でフォーマットすること。
- シェルスクリプトは `bash` で書き、`set -euo pipefail` を冒頭に記載すること。

---

## 制約事項

- 無料枠（t3.micro / 750時間/月）の範囲で運用すること。
- 学習用途のため冗長構成不要。
- UIなし。管理はSSH経由のCLI操作のみ。
