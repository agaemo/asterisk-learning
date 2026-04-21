---
name: iac
description: IaC（Infrastructure as Code）の導入・設計・運用手順。Terraform/OpenTofu を中心に、インフラをコード管理したいときに使う。
---

## このスキルの使い方

IaC は「設定を間違えると本番インフラが壊れる」リスクがある。
そのため、このスキルは **各ステップでユーザーの確認を取ってから次に進む** 設計になっている。
絶対に先回りしてリソースを作ったり `apply` を実行したりしないこと。

---

## ステップ0: ヒアリング（必ず最初に実施）

IaC 作業を始める前に、以下を確認してユーザーの回答を待つこと。

```
確認事項：
1. クラウドプロバイダーは何か？（AWS / GCP / Azure / その他）
2. 管理したいリソースは何か？（VPC・EC2・RDS・Lambda・Container など）
3. 既存インフラがある場合: Terraform 管理外のリソースはあるか？（import が必要）
4. 環境は何種類あるか？（dev / staging / prod など）
5. State の保存場所はどこにするか？（S3+DynamoDB / GCS / Terraform Cloud など）
6. チームで使うか、個人利用か？
```

すべての回答が揃うまで実装を始めないこと。

---

## ツール選定の目安

| ツール | 向いているケース |
|--------|----------------|
| **Terraform / OpenTofu** | マルチクラウド・チーム開発・OSS を優先したい |
| **Pulumi** | TypeScript/Python でインフラを書きたい・ロジックが複雑 |
| **AWS CDK** | AWS 専用・TypeScript/Python 既存チーム |
| **Ansible** | サーバー設定管理（プロビジョニング）に特化したい |

迷ったら **Terraform / OpenTofu** を選ぶ。エコシステムと情報量が最も豊富。
OpenTofu は Terraform の OSS fork で、ライセンス問題を避けたい場合に選択する。

---

## ステップ1: ディレクトリ構造の設計

ユーザーの環境数・規模に応じて提案する（変更可）。

### シンプル構成（環境1〜2、個人 or 小チーム）

```
infra/
├── main.tf          # メインのリソース定義
├── variables.tf     # 変数定義
├── outputs.tf       # 出力値
├── versions.tf      # provider バージョン固定
└── terraform.tfvars # 変数の値（.gitignore に入れること）
```

### 環境分離構成（環境3つ以上、チーム開発）

```
infra/
├── modules/
│   ├── network/     # 再利用可能なモジュール
│   ├── compute/
│   └── database/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   ├── staging/
│   └── prod/
└── versions.tf
```

**どちらにするか確認してから作成すること。**

---

## ステップ2: State の設定（リモートバックエンド）

State はインフラの現状を記録するファイル。**絶対に git にコミットしない**（シークレットが含まれる）。

### AWS（S3 + DynamoDB）の場合

```hcl
# versions.tf
terraform {
  backend "s3" {
    bucket         = "<your-state-bucket>"
    key            = "infra/<env>/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "<your-lock-table>"  # State ロック用
  }
}
```

バックエンド用リソース（S3バケット・DynamoDBテーブル）はコンソールで手動作成するか、
bootstrap 用の別ディレクトリ（`infra/bootstrap/`）で先に作る。
**「バックエンドリソースをどうするか」を確認してから進むこと。**

---

## ステップ3: Provider 設定

```hcl
# versions.tf
terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # マイナーバージョンまで固定する
    }
  }
}

provider "aws" {
  region = var.aws_region
  # アクセスキーをここに書かない。環境変数 AWS_PROFILE か IAM Role を使う。
}
```

---

## ステップ4: 変数・シークレット管理のルール

- **シークレット（DBパスワード・APIキー）は `terraform.tfvars` に書かず、AWS Secrets Manager / SSM Parameter Store から参照すること**
- `terraform.tfvars` は `.gitignore` に必ず追加する
- `variables.tf` に `sensitive = true` をつけてログへの出力を防ぐ

```hcl
# variables.tf
variable "db_password" {
  type      = string
  sensitive = true  # plan/apply の出力に値が表示されなくなる
}

# Secrets Manager からの参照例
data "aws_secretsmanager_secret_version" "db" {
  secret_id = "prod/myapp/db"
}
```

---

## ステップ5: Plan / Apply の手順

```bash
# 初期化（初回・provider 追加時）
terraform init

# 変更内容の確認（apply の前に必ず実行）
terraform plan -out=tfplan

# 内容を確認してから apply を実行する
# ↑ ここでユーザーに plan 結果を見せて確認を取ること

terraform apply tfplan

# 特定リソースだけ対象にする（影響範囲を絞りたいとき）
terraform apply -target=aws_instance.web tfplan
```

**`terraform apply` の前に必ずユーザーに plan の内容を提示して確認を取ること。**
特に `destroy` や `replace` が含まれる場合は赤字で警告すること。

---

## ステップ6: 既存リソースの Import

コンソールで手動作成済みのリソースを Terraform 管理下に入れる手順。

```bash
# リソースアドレスと実際のID を指定する
terraform import aws_instance.web i-0123456789abcdef0

# Terraform 1.5 以降: import ブロックでコードから宣言できる
import {
  to = aws_instance.web
  id = "i-0123456789abcdef0"
}
```

Import 後は必ず `terraform plan` で差分がないことを確認すること（差分があると次回 apply で上書きされる）。

---

## 破壊的変更の警告

`plan` 結果にこれらが含まれていたら、**実行前にユーザーへ明示的に警告すること**：

```
# 危険度: 高（データ消失・ダウンタイムのリスク）
- destroy     → リソース削除
- replace     → 削除 & 再作成（forces replacement）
- recreate    → 同上

# 危険度: 中（設定変更による影響）
- update      → 再起動が必要な場合あり（EC2 タイプ変更など）
```

---

## .gitignore のテンプレート

```gitignore
# State ファイル（シークレットを含む）
*.tfstate
*.tfstate.*
.terraform/

# ローカル変数値（シークレットを含む可能性）
terraform.tfvars
*.auto.tfvars

# Plan ファイル（バイナリ）
*.tfplan
tfplan
```

---

## チェックリスト

### 設計フェーズ
- [ ] ヒアリング（ステップ0）が完了している
- [ ] ディレクトリ構造を決定してユーザーの承認を得た
- [ ] State のリモートバックエンドを決定した

### 実装フェーズ
- [ ] `*.tfstate` / `terraform.tfvars` / `.terraform/` が `.gitignore` に入っている
- [ ] provider バージョンが `~>` で固定されている（メジャーバージョン固定）
- [ ] シークレットが `variables.tf` に `sensitive = true` で定義されている
- [ ] シークレットの値が `.tfvars` ではなく Secrets Manager / SSM から参照されている

### 実行フェーズ
- [ ] `terraform init` を実行した
- [ ] `terraform plan` の結果をユーザーに確認してもらった
- [ ] `destroy` / `replace` が含まれる場合はユーザーへ警告した
- [ ] `terraform apply` 後に `terraform plan` で差分がゼロになることを確認した
