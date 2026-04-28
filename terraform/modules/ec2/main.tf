# Ubuntu 24.04 LTS の最新 AMI を動的取得
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "asterisk" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.sg_id]
  key_name               = var.key_name

  # Asterisk インストールスクリプトを起動時に実行
  user_data = file("${path.root}/../scripts/install.sh")

  # フリーティア対象のストレージ（gp3 は gp2 より高性能で同価格）
  root_block_device {
    volume_type = "gp3"
    volume_size = 20
  }

  tags = {
    Name    = "${var.project}-asterisk"
    Project = var.project
  }
}

resource "aws_eip" "asterisk" {
  domain = "vpc"

  tags = {
    Name    = "${var.project}-eip"
    Project = var.project
  }
}

resource "aws_eip_association" "asterisk" {
  instance_id   = aws_instance.asterisk.id
  allocation_id = aws_eip.asterisk.id
}
