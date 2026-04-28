# asterisk-learning

AWS EC2 上に Asterisk 20 PBX を構築し、SIP softphone（Zoiper）で内線通話を体験するための学習用 IaC プロジェクト。

---

## このリポジトリの使い方

```bash
git clone git@github.com:agaemo/asterisk-learning.git my-asterisk-learning
cd my-asterisk-learning
```

**初めて進める場合は [`docs/tasks.md`](docs/tasks.md) を最初から順に進めてください。**
AWSアカウントの初期設定から後片付けまでチェックリスト形式で記載しています。

---

## ドキュメント

| ファイル | 内容 |
|---|---|
| [docs/tasks.md](docs/tasks.md) | セットアップから後片付けまでの手順チェックリスト |
| [docs/terraform-intro.md](docs/terraform-intro.md) | Terraform の仕組み・コードの読み方・各 AWS リソースの役割 |
| [docs/asterisk-guide.md](docs/asterisk-guide.md) | pjsip.conf・extensions.conf・rtp.conf の解説・通話の流れ・NAT対策の理由 |
| [docs/requirements.md](docs/requirements.md) | プロジェクトの要件定義 |

---

## トラブルシューティング

> 以下のコマンドで `<EIP>` と書かれている箇所は、`terraform apply` 完了時に表示された `elastic_ip` の値に置き換えてください。

### terraform plan/apply が "timeout while waiting for plugin to start" になる

**対象:** Intel Mac から Apple Silicon Mac（M1/M2/M3）に移行したユーザー

Intel Mac 時代に Homebrew をインストールしていた場合、移行後も Intel 版の Homebrew（`/usr/local`）が残り続けます。その状態で Terraform をインストールすると Intel 版（`darwin_amd64`）が入り、Apple Silicon 上で正常に動かないことがあります。

まず自分が該当するか確認してください。

```bash
uname -m          # arm64 なら Apple Silicon
terraform version # darwin_amd64 と表示されていれば問題あり
which brew        # /usr/local/bin/brew なら Intel 版 Homebrew
```

3つとも該当する場合、以下の手順で ARM 版に入れ直してください。

```bash
# ARM 版 Homebrew をインストール
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"

# ARM 版 Terraform をインストール
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# .terraform を削除して再初期化
rm -rf terraform/.terraform
terraform -chdir=terraform init

# 確認（darwin_arm64 と表示されれば OK）
terraform version
```

### terraform apply で "InvalidKeyPair.NotFound" になる

AWS コンソールのリージョンが東京（`ap-northeast-1`）以外でキーペアを作成した場合に発生します。キーペアはリージョンごとに管理されており、EC2 と同じリージョンで作成する必要があります。

AWS コンソール右上のリージョンを **「アジアパシフィック（東京）」** に切り替えてから、EC2 → キーペア → 「キーペアの作成」で作成してください。

> AWS コンソールはデフォルトで「米国東部（バージニア北部）」になっていることが多いため注意が必要です。

### 登録できない
```bash
# Asterisk のログをリアルタイム確認
ssh -i ~/.ssh/asterisk-key.pem ubuntu@<EIP> "sudo tail -f /var/log/asterisk/messages.log"
```

### 音声が片方しか聞こえない（ワンウェイオーディオ）
`pjsip.conf` の `external_media_address` と `external_signaling_address` に Elastic IP が正しく設定されているか確認。

### インストールが完了しているか確認
```bash
ssh -i ~/.ssh/asterisk-key.pem ubuntu@<EIP> "tail -20 /var/log/asterisk-install.log"
```

### IP アドレスが変わって SSH・SIP が接続できなくなった
```bash
# 現在の IP を確認
curl https://checkip.amazonaws.com

# terraform.tfvars の my_ip を更新して apply
terraform -chdir=terraform apply
```

---

## 今後の拡張（任意）

Twilio SIP トランクを接続して実際の電話番号（日本の番号）での発着信を試す。
→ `docs/requirements.md` を参照
