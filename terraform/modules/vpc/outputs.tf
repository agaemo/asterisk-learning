output "vpc_id" {
  description = "作成した VPC の ID"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "作成したパブリックサブネットの ID"
  value       = aws_subnet.public.id
}

output "vpc_cidr" {
  description = "VPC の CIDR ブロック（pjsip.conf の local_net に使用）"
  value       = aws_vpc.main.cidr_block
}
