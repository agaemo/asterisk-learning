variable "project" {
  description = "プロジェクト名"
  type        = string
}

variable "subnet_id" {
  description = "EC2 を起動するサブネットの ID"
  type        = string
}

variable "sg_id" {
  description = "アタッチする Security Group の ID"
  type        = string
}

variable "key_name" {
  description = "SSH 接続に使用する EC2 Key Pair 名"
  type        = string
}

variable "instance_type" {
  description = "EC2 インスタンスタイプ"
  type        = string
  default     = "t3.micro"
}
