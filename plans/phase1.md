# フェーズ1 実装計画: AWS Asterisk 内線通話環境構築

## 目標
Terraform で AWS インフラを構築し、Zoiper（SIP softphone）で内線通話できる環境を作る。

## 実装ステップ

### Step 1: .gitignore
秘密情報がコミットされないよう最初に作成。

### Step 2: Terraform - vpc モジュール
- `aws_vpc` (10.0.0.0/16)
- `aws_subnet` (パブリック)
- `aws_internet_gateway`
- `aws_route_table` + `aws_route_table_association`
- outputs: `vpc_id`, `subnet_id`

### Step 3: Terraform - sg モジュール
- TCP 22 (SSH) → `var.my_ip`
- UDP 5060 (SIP) → `var.my_ip`
- UDP 10000-20000 (RTP) → `var.my_ip`
- egress: all

### Step 4: scripts/install.sh
- Asterisk 20 ソースビルド（Ubuntu 24.04 リポジトリにAsterisk 20 がないため）
- 依存パッケージインストール
- systemd 登録

### Step 5: Terraform - ec2 モジュール
- `data "aws_ami"` (Ubuntu 24.04 最新を動的取得)
- `aws_instance` (t3.micro, user_data=install.sh)
- `aws_eip` + `aws_eip_association`
- outputs: `public_ip`

### Step 6: Terraform - ルートモジュール (main.tf / variables.tf / outputs.tf)
- モジュール呼び出し
- 変数: `my_ip`, `aws_region`, `key_name`
- `terraform.tfvars.example` を git 管理

### Step 7: terraform apply
```bash
terraform -chdir=terraform init
terraform -chdir=terraform plan
terraform -chdir=terraform apply
```

### Step 8: Asterisk 設定ファイル
- `asterisk/rtp.conf` (10000-20000)
- `asterisk/extensions.conf` (internal コンテキスト)
- `asterisk/pjsip.conf.template` (git管理用テンプレート)
- `asterisk/pjsip.conf` (実ファイル・gitignore)
- rsync で EC2 へ転送
- `sudo systemctl restart asterisk`

### Step 9: 動作確認
```bash
# Asterisk CLI でエンドポイント確認
ssh ubuntu@<EIP> "sudo asterisk -rx 'pjsip show endpoints'"

# Zoiper 設定
# サーバー: <Elastic IP>:5060 / UDP
# 1001 → スマホ, 1002 → PC
```

## 重要な注意点

### NAT 対策（音声疎通の要）
`pjsip.conf` の transport セクションで必須:
```ini
external_media_address=<ELASTIC_IP>
external_signaling_address=<ELASTIC_IP>
local_net=10.0.0.0/16
```
これを設定しないとワンウェイオーディオ（片方しか聞こえない）になる。

### セキュリティ
- `pjsip.conf` はパスワードを含むため gitignore
- `terraform.tfvars` も gitignore
- SIP パスワードは 12 文字以上のランダム文字列を使うこと
- Security Group は必ず `/32` CIDR（自分の IP のみ）
