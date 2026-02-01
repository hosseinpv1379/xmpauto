#!/bin/bash
#
# اسکریپت نصب XMPlus و تولید کانفیگ
# استفاده:
#   ./setup.sh --apihost "https://example.com" --apikey "YOUR_KEY" --nodes 1 2 3
#

set -e

# پارامترهای پیش‌فرض
APIHOST=""
APIKEY=""
NODES=()
SKIP_INSTALL=false

# خواندن آرگومان‌ها
while [[ $# -gt 0 ]]; do
    case $1 in
        --apihost)
            APIHOST="$2"
            shift 2
            ;;
        --apikey)
            APIKEY="$2"
            shift 2
            ;;
        --nodes)
            shift
            while [[ $# -gt 0 ]] && [[ ! "$1" == --* ]]; do
                NODES+=("$1")
                shift
            done
            ;;
        --config-only)
            SKIP_INSTALL=true
            shift
            ;;
        *)
            echo "آرگومان ناشناخته: $1"
            exit 1
            ;;
    esac
done

# بررسی پارامترهای الزامی
if [[ -z "$APIHOST" ]] || [[ -z "$APIKEY" ]]; then
    echo "استفاده: $0 --apihost \"https://example.com\" --apikey \"YOUR_KEY\" [--nodes 1 2 3 ...]"
    echo ""
    echo "پارامترها:"
    echo "  --apihost      آدرس API (ثابت)"
    echo "  --apikey       کلید API (ثابت)"
    echo "  --nodes        لیست Node ID ها (اگر چندتا بذاری، برای هرکدوم یک بلوک کپی میشه)"
    echo "  --config-only  فقط کانفیگ بساز، نصب نکن"
    exit 1
fi

# اگر node نداده، پیش‌فرض 1
if [[ ${#NODES[@]} -eq 0 ]]; then
    NODES=(1)
fi

if [[ "$SKIP_INSTALL" == false ]]; then
    echo "=== نصب XMPlus ==="
    bash <(curl -Ls https://raw.githubusercontent.com/XMPlusDev/XMPlus/scripts/install.sh)
    echo ""
fi

echo "=== ساخت کانفیگ ==="

# بخش بالای Nodes
CONFIG_HEAD='
Log:
  Level: warning
  AccessPath:
  ErrorPath:
  MaskAddress: half
DnsConfigPath:  #/etc/XMPlus/dns.json
RouteConfigPath: # /etc/XMPlus/route.json
InboundConfigPath: # /etc/XMPlus/inbound.json
OutboundConfigPath: # /etc/XMPlus/outbound.json
ConnectionConfig:
  Handshake: 8
  ConnIdle: 300
  UplinkOnly: 0
  DownlinkOnly: 0
  BufferSize: 64
Nodes:
'

# قالب یک نود (از - تا آخر بلوک)
NODE_TEMPLATE='  -
    ApiConfig:
      ApiHost: "APIHOST_PLACEHOLDER"
      ApiKey: "APIKEY_PLACEHOLDER"
      NodeID: NODEID_PLACEHOLDER
      Timeout: 30
      RuleListPath:
    ControllerConfig:
      EnableDNS: false
      DNSStrategy: AsIs
      CertConfig:
        Email: author@xmplus.dev
        CertFile: /etc/XMPlus/nodeNODEID_PLACEHOLDER.xmplus.dev.crt
        KeyFile: /etc/XMPlus/nodeNODEID_PLACEHOLDER.xmplus.dev.key
        Provider: cloudflare
        CertEnv:
          CLOUDFLARE_EMAIL:
          CLOUDFLARE_API_KEY:
      EnableFallback: false
      FallBackConfigs:
        - SNI:
          Alpn:
          Path:
          Dest: 80
          ProxyProtocolVer: 0
      IPLimit:
        Enable: false
        RedisNetwork: tcp
        RedisAddr: 127.0.0.1:6379
        RedisUsername: default
        RedisPassword: YOURPASSWORD
        RedisDB: 0
        Timeout: 5
        Expiry: 60
'

# ساخت فایل کانفیگ
CONFIG_FILE="/etc/XMPlus/config.yml"
OUTPUT=""

# افزودن هدر
OUTPUT="$CONFIG_HEAD"

# برای هر Node یک بلوک اضافه کن
for NODE_ID in "${NODES[@]}"; do
    BLOCK=$(echo "$NODE_TEMPLATE" | \
        sed "s|APIHOST_PLACEHOLDER|$APIHOST|g" | \
        sed "s|APIKEY_PLACEHOLDER|$APIKEY|g" | \
        sed "s|NODEID_PLACEHOLDER|$NODE_ID|g")
    OUTPUT="$OUTPUT$BLOCK"
done

# ذخیره کانفیگ
echo "$OUTPUT" | sudo tee "$CONFIG_FILE" > /dev/null

echo "کانفیگ در $CONFIG_FILE ذخیره شد"
echo "  ApiHost: $APIHOST"
echo "  ApiKey: $APIKEY"
echo "  Nodes: ${NODES[*]}"
