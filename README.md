# asterisk-learning

AWS EC2 上に Asterisk 20 PBX を構築し、SIP softphone（Zoiper）で内線通話を体験するための学習用 IaC プロジェクト。

---

## このリポジトリの使い方

```bash
git clone git@github.com:agaemo/asterisk-learning.git my-asterisk-learning
cd my-asterisk-learning
```

以降の手順は `my-asterisk-learning/` 内で作業します。

---

## AWSアカウントの初期セキュリティ設定（最初に必ずやること）

### 1. ルートアカウントに MFA を設定する

不正ログインを防ぐ最重要設定です。

1. AWS コンソール右上のアカウント名 →「セキュリティ認証情報」
2.「多要素認証（MFA）」→「MFA デバイスを割り当てる」
3. スマホの認証アプリ（Google Authenticator / Authy など）でスキャンして登録

### 2. 請求アラートを設定する

不正利用や予期せぬ課金を早期発見するための設定です。

1. AWS コンソール →「Budgets（予算）」を検索
2.「予算を作成」→「コスト予算」を選択
3. 予算額を `$5`（月）に設定
4. アラートのしきい値を `実際のコストが予算の80%` に設定
5. 通知先メールアドレスを入力して作成

> フリーティア範囲内なら $5 を超えることはほぼありません。超えた場合は不審なリソースが起動していないか確認してください。

---

## ドキュメント

| ファイル | 内容 |
|---|---|
| [docs/terraform-intro.md](docs/terraform-intro.md) | Terraform の仕組み・コードの読み方・各 AWS リソースの役割 |
| [docs/asterisk-guide.md](docs/asterisk-guide.md) | pjsip.conf・extensions.conf・rtp.conf の解説・通話の流れ・NAT対策の理由 |
| [docs/requirements.md](docs/requirements.md) | プロジェクトの要件定義 |
| [docs/tasks.md](docs/tasks.md) | フェーズ1の手順チェックリスト |

> セットアップ手順だけでなく、設定の意味や仕組みを理解したい場合は上記ドキュメントを参照してください。

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

EC2 が SSH 接続できるまで待機する（apply 直後は接続不可）:

```bash
bash scripts/wait-for-ssh.sh <EIP> ~/.ssh/asterisk-key.pem
```

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
rsync -av --rsync-path="sudo rsync" -e "ssh -i ~/.ssh/asterisk-key.pem" asterisk/ ubuntu@<EIP>:/etc/asterisk/
ssh -i ~/.ssh/asterisk-key.pem ubuntu@<EIP> "sudo systemctl restart asterisk"
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

## インフラ削除

```bash
terraform -chdir=terraform destroy
```

> **注意:** Elastic IP は削除されるまで課金されます。学習終了後は必ず destroy してください。

---

## フェーズ2（今後の拡張）

Twilio SIP トランクを接続して実際の電話番号（日本の番号）での発着信を試す。
→ `docs/requirements.md` のフェーズ2を参照
