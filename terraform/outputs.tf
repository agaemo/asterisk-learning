output "elastic_ip" {
  description = "Asterisk サーバーの Elastic IP（Zoiper の接続先・pjsip.conf に設定する値）"
  value       = module.ec2.elastic_ip
}

output "ssh_command" {
  description = "SSH 接続コマンド"
  value       = "ssh -i <your-key.pem> ubuntu@${module.ec2.elastic_ip}"
}

output "rsync_command" {
  description = "Asterisk 設定ファイルの転送コマンド（sudoでrsyncを実行してパーミッションエラーを回避）"
  value       = "rsync -av --rsync-path='sudo rsync' -e 'ssh -i <your-key.pem>' asterisk/ ubuntu@${module.ec2.elastic_ip}:/etc/asterisk/"
}
