# 要件定義

## 背景・目的

Asterisk・SIP・RTP・SIPトランクなど電話SaaSの基盤技術を自分で動かして理解することが目的。
本番運用ではなく学習専用環境。

---

## スコープ

### フェーズ1（必須）: 内線通話

- AWS EC2上にAsteriskサーバーを構築する
- スマートフォン（Zoiper）をSIP softphoneとして接続する
- PC softphone（Zoiper PC版）も合わせて使用可
- softphone間で内線通話ができること

### フェーズ2（任意・後から追加）: 実番号発着信

- Twilio SIPトランクをAsteriskに接続する
- Twilioが発行する電話番号で着信できること
- AsteriskからTwilio経由で外部番号に発信できること

---

## 非機能要件

| 項目 | 内容 |
|------|------|
| コスト | AWSフリーティア（t3.micro・750時間/月）の範囲内 |
| 可用性 | 単一インスタンス。冗長化不要 |
| UI | なし。管理はSSH CLI操作のみ |
| 外部連携 | なし（フェーズ2でTwilio追加） |
| セキュリティ | Security GroupはSSH・SIP・RTPを自分のIPのみ開放 |

---

## インフラ構成

### AWSリソース

| リソース | 仕様 |
|----------|------|
| EC2 | t3.micro、Ubuntu 24.04 LTS |
| Elastic IP | 1つ（IPを固定してsoftphoneの接続先を安定させる） |
| VPC | 新規作成、パブリックサブネット1つ |
| Security Group | SSH(22)・SIP UDP(5060)・RTP UDP(10000-20000) を自分のIPのみ許可 |

### Asterisk設定

| 項目 | 内容 |
|------|------|
| バージョン | Asterisk 20（LTS） |
| プロトコル | SIP（chan_pjsip） |
| 内線番号 | 1001（スマートフォン）、1002（PC softphone） |
| RTPポート | 10000-20000 |

---

## IaC

- ツール: Terraform
- 状態管理: ローカル（S3バックエンドは学習後に検討）
- モジュール分割: vpc / ec2 / sg

---

## 除外事項

- 管理画面（FreePBX等）は不要
- データベース不要
- CI/CD不要
- 録音・通話ログ保存不要（フェーズ2以降で検討可）
