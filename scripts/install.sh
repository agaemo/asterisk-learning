#!/bin/bash
set -euo pipefail

LOG=/var/log/asterisk-install.log
exec > >(tee -a "$LOG") 2>&1

echo "=== Asterisk 20 インストール開始: $(date) ==="

# タイムゾーン設定
timedatectl set-timezone Asia/Tokyo

# システム更新
apt-get update -y
apt-get upgrade -y

# ビルド依存パッケージ
apt-get install -y \
  build-essential \
  libssl-dev \
  libncurses5-dev \
  libnewt-dev \
  libxml2-dev \
  libsqlite3-dev \
  uuid-dev \
  libjansson-dev \
  libedit-dev \
  libxslt1-dev \
  binutils-dev \
  libiksemel-dev \
  libsrtp2-dev \
  libbluetooth-dev \
  libunbound-dev \
  curl \
  wget \
  rsync

# Asterisk 20 LTS ソースダウンロード・ビルド
cd /usr/src
ASTERISK_VERSION="20-current"
curl -O "https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-${ASTERISK_VERSION}.tar.gz"
tar xzf "asterisk-${ASTERISK_VERSION}.tar.gz"
cd asterisk-20*/

# chan_pjsip に必要な pjproject をバンドルビルド
contrib/scripts/get_mp3_source.sh || true
contrib/scripts/install_prereq install

./configure --with-jansson-bundled
make menuselect.makeopts

# res_pjsip（chan_pjsip の依存）を有効化
menuselect/menuselect \
  --enable res_pjsip \
  --enable res_pjsip_session \
  --enable res_pjsip_endpoint_identifier_ip \
  --enable chan_pjsip \
  menuselect.makeopts

make -j"$(nproc)"
make install
make samples   # デフォルト設定を /etc/asterisk/ に生成（後で rsync 上書きする）
make config    # systemd ユニットファイルを登録

ldconfig

# asterisk ユーザーへの権限付与
chown -R asterisk:asterisk /etc/asterisk
chown -R asterisk:asterisk /var/log/asterisk
chown -R asterisk:asterisk /var/spool/asterisk
chown -R asterisk:asterisk /var/lib/asterisk
chown -R asterisk:asterisk /var/run/asterisk

systemctl enable asterisk
systemctl start asterisk

echo "=== インストール完了: $(date) ==="
echo "確認: sudo asterisk -rx 'core show version'"
