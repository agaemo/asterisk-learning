output "sg_id" {
  description = "作成した Security Group の ID"
  value       = aws_security_group.asterisk.id
}
