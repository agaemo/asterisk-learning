#!/bin/bash
# EC2 が SSH 接続できるようになるまで待機するスクリプト
set -euo pipefail

EIP="${1:?引数1: Elastic IP アドレスを指定してください}"
KEY="${2:-$HOME/.ssh/asterisk-key.pem}"

echo "SSH 接続を待機中: $EIP"
until ssh -i "$KEY" -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@"$EIP" "echo ok" 2>/dev/null; do
  echo "待機中..."
  sleep 10
done
echo "SSH 接続できました: $EIP"
