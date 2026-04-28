# タスク一覧

## 内線通話を動かす

### 事前準備

- [ ] **AWS アカウントを作成する**
  - https://aws.amazon.com/jp/ でアカウント登録
  - クレジットカード登録が必要（フリーティア範囲内なら無料）

- [ ] **IAM ユーザーを作成する**（ルートアカウントのキーは使わないこと）
  - AWS コンソール → IAM → ユーザー → 「ユーザーの作成」
  - ユーザー名を決める（例: `terraform-user`）
  - 「AWS マネジメントコンソールへのアクセス」は不要
  - 権限: 「既存のポリシーを直接アタッチ」→ `AdministratorAccess`（学習用）
  - 作成後 → 「セキュリティ認証情報」タブ → 「アクセスキーの作成」
  - 用途: 「コマンドラインインターフェース（CLI）」を選択
  - アクセスキー ID とシークレットアクセスキーを安全な場所に保存

- [ ] **AWS CLI をインストール・設定する**
  ```bash
  # インストール（Mac）
  brew install awscli

  # 設定（上で作成した IAM ユーザーのアクセスキーを入力）
  aws configure
  # AWS Access Key ID: （IAM ユーザーのキー ID）
  # AWS Secret Access Key: （IAM ユーザーのシークレット）
  # Default region name: ap-northeast-1
  # Default output format: json

  # 動作確認
  aws sts get-caller-identity
  ```

- [ ] **Terraform をインストールする**
  ```bash
  brew tap hashicorp/tap
  brew install hashicorp/tap/terraform

  # 確認
  terraform version
  ```

- [ ] **EC2 Key Pair を作成する**
  - AWS コンソール → EC2 → 左メニュー「キーペア」→「キーペアの作成」
  - 名前を決める（例: `asterisk-key`）
  - `.pem` ファイルをダウンロードして安全な場所に保存
  - `chmod 400 asterisk-key.pem` でパーミッションを設定

- [ ] **Zoiper をインストールする**
  - スマートフォン: App Store / Google Play で「Zoiper」を検索してインストール（無料版で可）
  - PC: https://www.zoiper.com/en/voip-softphone/download/current からダウンロード

---

### インフラ構築

- [ ] **自分の IP アドレスを確認する**
  ```bash
  curl https://checkip.amazonaws.com
  # 例: 203.0.113.1
  ```

- [ ] **terraform.tfvars を作成する**
  ```bash
  cp terraform/terraform.tfvars.example terraform/terraform.tfvars
  ```
  `terraform/terraform.tfvars` を編集:
  ```hcl
  my_ip    = "203.0.113.1/32"   # ↑ で確認したIP + /32
  key_name = "asterisk-key"      # 作成した Key Pair 名
  ```

- [ ] **Terraform を初期化する**
  ```bash
  terraform -chdir=terraform init
  ```

- [ ] **作成されるリソースを確認する（plan）**
  ```bash
  terraform -chdir=terraform plan
  ```

- [ ] **インフラを構築する（apply）**
  ```bash
  terraform -chdir=terraform apply
  # "yes" を入力して実行
  ```
  → 完了後に `elastic_ip` が表示されます（例: `13.112.xxx.xxx`）

- [ ] **EC2 が SSH 接続できるまで待つ**（apply 完了後 1〜2 分）
  ```bash
  # SSH が通るまでリトライ
  until ssh -i asterisk-key.pem -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@<EIP> "echo ok"; do
    echo "待機中..."; sleep 10
  done
  echo "SSH 接続可能になりました"
  ```

---

### Asterisk 設定

- [ ] **Asterisk のインストール完了を待つ**（apply 後 10〜15 分）
  ```bash
  # ログを確認（"インストール完了" が出たらOK）
  ssh -i asterisk-key.pem ubuntu@<EIP> "tail -f /var/log/asterisk-install.log"
  ```

- [ ] **pjsip.conf を作成する**
  ```bash
  cp asterisk/pjsip.conf.template asterisk/pjsip.conf
  ```
  `asterisk/pjsip.conf` を編集:
  - `<ELASTIC_IP>` を apply で出力された IP に置き換える（2箇所）
  - `<STRONG_PASSWORD_1001>` と `<STRONG_PASSWORD_1002>` を強いパスワードに変更
    ```bash
    # パスワード生成の例
    openssl rand -base64 16
    ```
  編集後、プレースホルダーが残っていないか確認する:
  ```bash
  grep "<" asterisk/pjsip.conf
  # 何も表示されなければOK
  ```

- [ ] **設定ファイルを EC2 に転送する**
  ```bash
  # --rsync-path="sudo rsync": /etc/asterisk/ は asterisk:asterisk 所有のため sudo が必要
  rsync -av --rsync-path="sudo rsync" -e "ssh -i asterisk-key.pem" asterisk/ ubuntu@<EIP>:/etc/asterisk/
  ssh -i asterisk-key.pem ubuntu@<EIP> "sudo systemctl restart asterisk"
  ```

- [ ] **Asterisk の動作を確認する**
  ```bash
  ssh -i asterisk-key.pem ubuntu@<EIP> "sudo asterisk -rx 'pjsip show endpoints'"
  # 1001 と 1002 が表示されればOK
  ```

---

### 通話テスト

- [ ] **Zoiper（スマホ）に 1001 を登録する**
  - アカウント追加 → SIP を選択
  - ユーザー名: `1001`
  - パスワード: pjsip.conf で設定した 1001 のパスワード
  - サーバー: `<Elastic IP>`
  - ポート: `5060` / UDP
  - 「Registered」と表示されれば成功

- [ ] **Zoiper（PC）に 1002 を登録する**
  - 同様に 1002 で登録

- [ ] **通話テストをする**
  - スマホ（1001）から PC（1002）にダイヤル
  - PC 側に着信が来ればフェーズ1完了！

---

### 後片付け（学習終了時）

- [ ] **インフラを削除する**
  ```bash
  terraform -chdir=terraform destroy
  # "yes" を入力して実行
  ```
  > **注意**: インスタンスを「停止（stop）」するだけでは不十分です。Elastic IP はインスタンスに関連付けられていても、インスタンスが停止中は課金（$0.005/時間）が発生します。学習が終わったら必ず `destroy` してください。

---

## 拡張（任意）: Twilio で実番号発着信

- [ ] Twilio アカウントを作成する（無料トライアルで可）
- [ ] 電話番号を取得する
- [ ] pjsip.conf に Twilio SIP トランクを追加する
- [ ] extensions.conf に発着信のダイヤルプランを追加する
