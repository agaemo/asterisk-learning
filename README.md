# asterisk-learning

AWS EC2 上に Asterisk 20 PBX を構築し、SIP softphone（Zoiper）で内線通話を体験するための学習用 IaC プロジェクト。

---

## 前提条件

| ツール | バージョン |
|--------|-----------|
| Terraform | >= 1.6 |
| AWS CLI | 設定済み（`aws configure`） |
| AWS アカウント | フリーティア利用可能なもの |
| EC2 Key Pair | AWS コンソールで事前に作成し、`.pem` を手元に保存 |
| Zoiper | スマートフォン・PC にインストール（無料版で可） |

---

## セットアップ手順

### 1. tfvars を準備する

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

`terraform/terraform.tfvars` を編集して自分の IP と Key Pair 名を入力:

```hcl
# 自分の IP を確認して /32 形式で入力
my_ip    = "203.0.113.1/32"   # curl https://checkip.amazonaws.com
key_name = "my-keypair"       # AWS コンソールで作成した Key Pair 名
```

### 2. インフラを構築する

```bash
terraform -chdir=terraform init
terraform -chdir=terraform plan
terraform -chdir=terraform apply
```

apply 完了後、Elastic IP が出力されます:

```
elastic_ip = "x.x.x.x"
```

> **注意:** Asterisk のインストールは User Data で実行されます。EC2 起動後、完了まで約 10〜15 分かかります。
> 進捗確認: `ssh ubuntu@<EIP> "tail -f /var/log/asterisk-install.log"`

### 3. Asterisk 設定ファイルを準備する

```bash
cp asterisk/pjsip.conf.template asterisk/pjsip.conf
```

`asterisk/pjsip.conf` を編集して Elastic IP とパスワードを設定:

```ini
external_media_address=<apply で出力された Elastic IP>
external_signaling_address=<apply で出力された Elastic IP>
```

パスワードは 12 文字以上のランダム文字列を設定してください（例: `openssl rand -base64 16`）。

### 4. 設定ファイルを EC2 に転送する

```bash
rsync -av asterisk/ ubuntu@<EIP>:/etc/asterisk/
ssh ubuntu@<EIP> "sudo systemctl restart asterisk"
```

### 5. 動作確認

```bash
# エンドポイント登録状態を確認
ssh ubuntu@<EIP> "sudo asterisk -rx 'pjsip show endpoints'"
```

---

## Zoiper の設定（内線登録）

| 項目 | 値 |
|------|-----|
| サーバー | `<Elastic IP>` |
| ポート | `5060` |
| プロトコル | UDP |
| ユーザー名 | `1001`（スマホ）または `1002`（PC） |
| パスワード | `pjsip.conf` で設定した値 |

スマホを 1001、PC を 1002 で登録し、互いにダイヤルすると通話できます。

---

## トラブルシューティング

### 登録できない
```bash
# Asterisk のログをリアルタイム確認
ssh ubuntu@<EIP> "sudo asterisk -rvvv"
```

### 音声が片方しか聞こえない（ワンウェイオーディオ）
`pjsip.conf` の `external_media_address` と `external_signaling_address` に Elastic IP が正しく設定されているか確認。

### インストールが完了しているか確認
```bash
ssh ubuntu@<EIP> "cat /var/log/asterisk-install.log | tail -20"
```

---

## インフラ削除

```bash
terraform -chdir=terraform destroy
```

> **注意:** Elastic IP は削除されるまで課金されます。学習終了後は必ず destroy してください。

---

## フェーズ2（今後の拡張）

Twilio SIP トランクを接続して実際の電話番号（日本の番号）での発着信を試す。
→ `docs/requirements.md` のフェーズ2を参照
