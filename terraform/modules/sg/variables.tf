variable "project" {
  description = "プロジェクト名"
  type        = string
}

variable "vpc_id" {
  description = "Security Group を作成する VPC の ID"
  type        = string
}

variable "my_ip" {
  description = "アクセスを許可する IP アドレス（/32 CIDR 形式）例: \"203.0.113.1/32\""
  type        = string
}
