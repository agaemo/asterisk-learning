resource "aws_security_group" "asterisk" {
  name        = "${var.project}-sg"
  description = "Asterisk サーバー用 Security Group"
  vpc_id      = var.vpc_id

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # SIP シグナリング
  ingress {
    description = "SIP"
    from_port   = 5060
    to_port     = 5060
    protocol    = "udp"
    cidr_blocks = [var.my_ip]
  }

  # RTP 音声ストリーム
  ingress {
    description = "RTP"
    from_port   = 10000
    to_port     = 20000
    protocol    = "udp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    description = "すべての送信トラフィックを許可"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project}-sg"
    Project = var.project
  }
}
