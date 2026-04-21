output "instance_id" {
  description = "EC2 インスタンス ID"
  value       = aws_instance.asterisk.id
}

output "elastic_ip" {
  description = "Elastic IP アドレス（Zoiper の接続先・pjsip.conf の external_*_address に設定する）"
  value       = aws_eip.asterisk.public_ip
}
