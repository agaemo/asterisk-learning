# Asterisk 設定ガイド

## Asterisk とは

**PBX（Private Branch Exchange）**、つまり「構内電話交換機」のソフトウェア実装です。

電話の世界では、外線（公衆電話網）と内線（社内の電話）の間を仲介する装置が PBX です。Asterisk はそれをソフトウェアで実現しており、SIP という標準プロトコルで動作します。

このプロジェクトでの役割:

```
Zoiper（1001）─── SIP ───> Asterisk ─── SIP ───> Zoiper（1002）
                              │
                         ダイヤルプランを見て
                         「1002 に転送しろ」と判断
```

---

## 設定ファイルの全体像

```
asterisk/
├── pjsip.conf      ← SIP の「誰が・どう接続するか」
├── extensions.conf ← 「どの番号にかけたら何をするか」
└── rtp.conf        ← 「音声データに使うポート範囲」
```

---

## pjsip.conf の解説

### transport セクション

```ini
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060
external_media_address=<ELASTIC_IP>
external_signaling_address=<ELASTIC_IP>
local_net=10.0.0.0/16
```

| 設定 | 意味 |
|------|------|
| `protocol=udp` | SIP の通信に UDP を使う（SIP は TCP でも動くが UDP が一般的） |
| `bind=0.0.0.0:5060` | すべての NIC のポート 5060 で待ち受ける |
| `external_media_address` | EC2 の外部 IP（Elastic IP）。音声（RTP）の送信元として使う |
| `external_signaling_address` | EC2 の外部 IP。SIP シグナルの送信元として使う |
| `local_net` | VPC 内のアドレス範囲。これ以外は NAT 越えとして扱う |

**なぜ external_*_address が必要か**

EC2 はプライベート IP（10.0.1.x）で動いており、外部から見えるのは Elastic IP です。設定がないと Asterisk はプライベート IP を相手に伝えてしまい、Zoiper が音声を送れなくなります（ワンウェイオーディオの原因）。

```
[設定なし]  Asterisk → "音声を 10.0.1.146 に送って" → Zoiper → 届かない
[設定あり]  Asterisk → "音声を 13.193.207.56 に送って" → Zoiper → 届く
```

---

### endpoint セクション

```ini
[1001]
type=endpoint
transport=transport-udp
context=internal
disallow=all
allow=ulaw
allow=alaw
auth=auth1001
aors=1001
direct_media=no
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes
```

| 設定 | 意味 |
|------|------|
| `context=internal` | このエンドポイントからの発信は `extensions.conf` の `[internal]` コンテキストで処理する |
| `disallow=all` | まず全コーデックを禁止（次の allow で明示的に許可するため） |
| `allow=ulaw` | G.711 μ-law（北米標準コーデック）を許可 |
| `allow=alaw` | G.711 A-law（欧州標準コーデック）を許可 |
| `auth=auth1001` | 認証に `[auth1001]` セクションを使う |
| `aors=1001` | 登録先の AOR（Address of Record）。Zoiper の登録情報を保持する |
| `direct_media=no` | 音声を必ず Asterisk 経由で通す（NAT 環境では必須） |
| `rtp_symmetric=yes` | RTP の送信元ポートと受信ポートを同じにする（NAT 対策） |
| `force_rport=yes` | SIP レスポンスを受信ポートに返す（NAT 対策） |
| `rewrite_contact=yes` | Contact ヘッダーを実際の送信元アドレスで書き換える（NAT 対策） |

**direct_media=no の理由**

`direct_media=yes`（デフォルト）にすると、Asterisk は通話が確立した後に「2つの Zoiper が直接音声を交換しろ」と指示します。しかし NAT 環境では互いのプライベート IP には届かないため、Asterisk を中継役にする必要があります。

```
[direct_media=yes]  Zoiper(1001) ← 直接 → Zoiper(1002)   ← NAT で失敗
[direct_media=no]   Zoiper(1001) ← Asterisk → Zoiper(1002) ← 常に成功
```

---

### auth セクション

```ini
[auth1001]
type=auth
auth_type=userpass
username=1001
password=XXXXXXXX
```

Zoiper が SIP 登録するときに使うユーザー名とパスワードです。Zoiper 側の設定と一致している必要があります。

---

### aor セクション

```ini
[1001]
type=aor
max_contacts=1
```

AOR（Address of Record）は「この内線番号に今どの端末が登録されているか」を管理します。`max_contacts=1` は同じ番号に同時に1台しか登録できないことを意味します。

---

## extensions.conf の解説

```ini
[general]
static=yes
writeprotect=no

[internal]
exten => 1001,1,Dial(PJSIP/1001,30)
exten => 1001,n,Hangup()

exten => 1002,1,Dial(PJSIP/1002,30)
exten => 1002,n,Hangup()
```

### コンテキスト

`[internal]` はコンテキスト（名前空間）です。`pjsip.conf` のエンドポイントに `context=internal` と書いているため、1001・1002 からの発信はここのルールで処理されます。

### exten の書式

```
exten => <番号>,<優先順位>,<アプリケーション>
```

| 部分 | 意味 |
|------|------|
| `1001` | この番号にダイヤルされたとき |
| `1` | 最初に実行するステップ（1から始まる） |
| `n` | 次のステップ（next の略） |
| `Dial(PJSIP/1001,30)` | 内線 1001 に SIP で発信、30秒応答なければ次へ |
| `Hangup()` | 切断 |

**実行の流れ（1002 にダイヤルした場合）**

```
1. Zoiper(1001) が "1002" をダイヤル
2. Asterisk が extensions.conf の [internal] を参照
3. exten => 1002,1,Dial(PJSIP/1002,30) を実行
4. Zoiper(1002) が鳴る
5. 応答 → 通話開始 / 30秒で無応答 → Hangup()
```

---

## rtp.conf の解説

```ini
[general]
rtpstart=10000
rtpend=20000
```

RTP（音声データ）に使うポート範囲を指定します。Security Group で `10000-20000/UDP` を開放しているのはこのためです。

1通話あたり送受信で2ポート使うため、この範囲で最大5000通話を同時処理できます（学習用途では十分すぎます）。

---

## 通話の流れ（全体）

```
[1] REGISTER（登録）
    Zoiper(1001) ──SIP REGISTER──> Asterisk
    Asterisk    <──SIP 200 OK───── Asterisk
    （AOR に 1001 の現在地を記録）

[2] INVITE（発信）
    Zoiper(1001) ──SIP INVITE 1002──> Asterisk
    Asterisk     ──SIP INVITE──>      Zoiper(1002)
    Zoiper(1002) ──SIP 200 OK──>      Asterisk
    Asterisk     ──SIP 200 OK──>      Zoiper(1001)

[3] RTP（通話中）
    Zoiper(1001) <══RTP（音声）══> Asterisk <══RTP（音声）══> Zoiper(1002)

[4] BYE（切断）
    Zoiper(1001) ──SIP BYE──> Asterisk ──SIP BYE──> Zoiper(1002)
```

SIP は「電話をかける・受ける・切る」という制御だけを担当し、実際の音声は RTP という別プロトコルで流れます。

---

## よくある疑問

**Q: コーデックとは何ですか？**

A: 音声を圧縮・変換する方式です。ulaw・alaw は非圧縮に近いシンプルなコーデックで、品質が高く CPU 負荷が低いため学習用途に適しています。

**Q: SIP と pjsip の違いは？**

A: Asterisk には旧来の `chan_sip` モジュールと新しい `chan_pjsip` モジュールがあります。このプロジェクトは `chan_pjsip`（設定ファイル名は `pjsip.conf`）を使っています。現在は pjsip が推奨です。

**Q: Asterisk を再起動せずに設定を反映できますか？**

A: `sudo asterisk -rx 'pjsip reload'` で pjsip.conf だけリロードできます。`extensions.conf` は `sudo asterisk -rx 'dialplan reload'` で反映できます。ただし学習中は `systemctl restart asterisk` でまとめて再起動するのが簡単です。
