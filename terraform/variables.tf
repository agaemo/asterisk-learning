variable "project" {
  description = "プロジェクト名（リソース名のプレフィックス）"
  type        = string
  default     = "asterisk-learning"
}

variable "aws_region" {
  description = "AWS リージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "my_ip" {
  description = "SSH・SIP・RTP アクセスを許可する IP アドレス（/32 CIDR 形式）\n例: \"203.0.113.1/32\"\n確認方法: curl https://checkip.amazonaws.com"
  type        = string
}

variable "key_name" {
  description = "SSH 接続に使用する EC2 Key Pair 名（AWS コンソールで事前に作成すること）"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC の CIDR ブロック"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "パブリックサブネットの CIDR ブロック"
  type        = string
  default     = "10.0.1.0/24"
}

variable "instance_type" {
  description = "EC2 インスタンスタイプ（フリーティア: t3.micro）"
  type        = string
  default     = "t3.micro"
}
