#!/bin/bash
#
# اسکریپت ایجاد تانل 6to4 + GRE6
# پشتیبانی از چند سرور ایران به یک سرور خارج
#
# استفاده:
#   روی سرور ایران:  ./6to4-tunnel.sh iran --kharej-ip 1.2.3.4 --iran-ip 5.6.7.8 --tunnel-id 1
#   روی سرور خارج:   ./6to4-tunnel.sh kharej --iran-ip 5.6.7.8 --kharej-ip 1.2.3.4 --tunnel-id 1
#   حذف تانل:        ./6to4-tunnel.sh remove --tunnel-id 1 --role iran
#   نمایش وضعیت:     ./6to4-tunnel.sh status
#

set -e

# رنگ‌ها
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# پارامترهای پیش‌فرض
ROLE=""
KHAREJ_IPV4=""
IRAN_IPV4=""
TUNNEL_ID=1
IPV6_BASE="fde8:b030:25cf"  # میتونید عوض کنید

# نمایش راهنما
show_help() {
    echo -e "${BLUE}=== اسکریپت تانل 6to4 + GRE6 ===${NC}"
    echo ""
    echo "استفاده:"
    echo "  $0 iran   --kharej-ip <IP> --iran-ip <IP> --tunnel-id <N> [--ipv6-base <BASE>]"
    echo "  $0 kharej --iran-ip <IP> --kharej-ip <IP> --tunnel-id <N> [--ipv6-base <BASE>]"
    echo "  $0 remove --tunnel-id <N> --role <iran|kharej>"
    echo "  $0 status"
    echo ""
    echo "پارامترها:"
    echo "  iran          اجرا روی سرور ایران"
    echo "  kharej        اجرا روی سرور خارج"
    echo "  remove        حذف تانل"
    echo "  status        نمایش وضعیت تانل‌ها"
    echo ""
    echo "  --kharej-ip   آیپی IPv4 پابلیک سرور خارج"
    echo "  --iran-ip     آیپی IPv4 پابلیک سرور ایران"
    echo "  --tunnel-id   شماره تانل (1, 2, 3, ...) - برای چند سرور ایران"
    echo "  --ipv6-base   پایه آدرس IPv6 (پیش‌فرض: fde8:b030:25cf)"
    echo ""
    echo -e "${YELLOW}مثال برای 2 سرور ایران + 1 خارج:${NC}"
    echo ""
    echo "سرور ایران 1 (آیپی: 1.1.1.1):"
    echo "  $0 iran --kharej-ip 9.9.9.9 --iran-ip 1.1.1.1 --tunnel-id 1"
    echo ""
    echo "سرور ایران 2 (آیپی: 2.2.2.2):"
    echo "  $0 iran --kharej-ip 9.9.9.9 --iran-ip 2.2.2.2 --tunnel-id 2"
    echo ""
    echo "سرور خارج (آیپی: 9.9.9.9) - برای هر سرور ایران یکبار:"
    echo "  $0 kharej --iran-ip 1.1.1.1 --kharej-ip 9.9.9.9 --tunnel-id 1"
    echo "  $0 kharej --iran-ip 2.2.2.2 --kharej-ip 9.9.9.9 --tunnel-id 2"
    echo ""
    exit 0
}

# خواندن آرگومان اول (نقش)
if [[ $# -eq 0 ]]; then
    show_help
fi

ROLE="$1"
shift

# خواندن بقیه آرگومان‌ها
while [[ $# -gt 0 ]]; do
    case $1 in
        --kharej-ip)
            KHAREJ_IPV4="$2"
            shift 2
            ;;
        --iran-ip)
            IRAN_IPV4="$2"
            shift 2
            ;;
        --tunnel-id)
            TUNNEL_ID="$2"
            shift 2
            ;;
        --ipv6-base)
            IPV6_BASE="$2"
            shift 2
            ;;
        --role)
            ROLE_FOR_REMOVE="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}آرگومان ناشناخته: $1${NC}"
            exit 1
            ;;
    esac
done

# محاسبه آدرس‌ها بر اساس tunnel-id
# هر تانل یک جفت IPv6 و یک جفت IPv4 لوکال داره
calc_addresses() {
    local tid=$1
    
    # IPv6 addresses - هر تانل دو آدرس داره
    # تانل 1: de01, de02
    # تانل 2: de03, de04
    # تانل 3: de05, de06
    local base_num=$(( (tid - 1) * 2 + 1 ))
    local iran_suffix=$(printf "%02x" $base_num)
    local kharej_suffix=$(printf "%02x" $((base_num + 1)))
    
    IRAN_IPV6="${IPV6_BASE}::de${iran_suffix}"
    KHAREJ_IPV6="${IPV6_BASE}::de${kharej_suffix}"
    
    # IPv4 Local addresses
    # تانل 1: 172.20.20.1/30 <-> 172.20.20.2/30
    # تانل 2: 172.20.21.1/30 <-> 172.20.21.2/30
    # تانل 3: 172.20.22.1/30 <-> 172.20.22.2/30
    local subnet=$((19 + tid))
    IRAN_LOCAL_IPV4="172.20.${subnet}.1"
    KHAREJ_LOCAL_IPV4="172.20.${subnet}.2"
    
    # نام اینترفیس‌ها
    TUNNEL_6TO4_NAME="6to4_T${tid}"
    TUNNEL_GRE6_NAME="GRE6_T${tid}"
}

# نمایش وضعیت
show_status() {
    echo -e "${BLUE}=== وضعیت تانل‌ها ===${NC}"
    echo ""
    echo -e "${YELLOW}تانل‌های 6to4:${NC}"
    ip tunnel show 2>/dev/null | grep -E "6to4|sit" || echo "  هیچ تانل 6to4 یافت نشد"
    echo ""
    echo -e "${YELLOW}تانل‌های GRE6:${NC}"
    ip -6 tunnel show 2>/dev/null | grep -E "GRE6|ip6gre" || echo "  هیچ تانل GRE6 یافت نشد"
    echo ""
    echo -e "${YELLOW}اینترفیس‌ها:${NC}"
    ip addr show 2>/dev/null | grep -E "6to4|GRE6" -A 2 || echo "  هیچ اینترفیس تانل یافت نشد"
    echo ""
    echo -e "${YELLOW}IP Forward:${NC}"
    cat /proc/sys/net/ipv4/ip_forward
    echo ""
    echo -e "${YELLOW}iptables NAT:${NC}"
    iptables -t nat -L -n 2>/dev/null | head -20 || echo "  دسترسی به iptables نیست"
    exit 0
}

# حذف تانل
remove_tunnel() {
    local tid=$1
    local role=$2
    
    calc_addresses $tid
    
    echo -e "${YELLOW}در حال حذف تانل ${tid}...${NC}"
    
    if [[ "$role" == "iran" ]]; then
        ip tunnel del ${TUNNEL_6TO4_NAME}_KH 2>/dev/null || true
        ip -6 tunnel del ${TUNNEL_GRE6_NAME}_KH 2>/dev/null || true
        
        # پاک کردن iptables
        iptables -t nat -F 2>/dev/null || true
        iptables -t nat -X 2>/dev/null || true
        
    elif [[ "$role" == "kharej" ]]; then
        ip tunnel del ${TUNNEL_6TO4_NAME}_IR 2>/dev/null || true
        ip -6 tunnel del ${TUNNEL_GRE6_NAME}_IR 2>/dev/null || true
    fi
    
    # حذف از rc.local
    if [[ -f /etc/rc.local ]]; then
        sed -i "/${TUNNEL_6TO4_NAME}/d" /etc/rc.local 2>/dev/null || true
        sed -i "/${TUNNEL_GRE6_NAME}/d" /etc/rc.local 2>/dev/null || true
    fi
    
    echo -e "${GREEN}تانل ${tid} با موفقیت حذف شد${NC}"
    exit 0
}

# ایجاد تانل سرور ایران
setup_iran() {
    calc_addresses $TUNNEL_ID
    
    echo -e "${BLUE}=== راه‌اندازی تانل روی سرور ایران ===${NC}"
    echo -e "تانل ID: ${YELLOW}${TUNNEL_ID}${NC}"
    echo -e "آیپی ایران: ${YELLOW}${IRAN_IPV4}${NC}"
    echo -e "آیپی خارج: ${YELLOW}${KHAREJ_IPV4}${NC}"
    echo -e "IPv6 ایران: ${YELLOW}${IRAN_IPV6}${NC}"
    echo -e "IPv6 خارج: ${YELLOW}${KHAREJ_IPV6}${NC}"
    echo -e "IPv4 لوکال ایران: ${YELLOW}${IRAN_LOCAL_IPV4}${NC}"
    echo -e "IPv4 لوکال خارج: ${YELLOW}${KHAREJ_LOCAL_IPV4}${NC}"
    echo ""
    
    # Step 1: تانل 6to4
    echo -e "${YELLOW}[1/4] ایجاد تانل 6to4...${NC}"
    ip tunnel add ${TUNNEL_6TO4_NAME}_KH mode sit remote ${KHAREJ_IPV4} local ${IRAN_IPV4}
    ip -6 addr add ${IRAN_IPV6}/64 dev ${TUNNEL_6TO4_NAME}_KH
    ip link set ${TUNNEL_6TO4_NAME}_KH mtu 1480
    ip link set ${TUNNEL_6TO4_NAME}_KH up
    
    # Step 2: تانل GRE6
    echo -e "${YELLOW}[2/4] ایجاد تانل GRE6...${NC}"
    ip -6 tunnel add ${TUNNEL_GRE6_NAME}_KH mode ip6gre remote ${KHAREJ_IPV6} local ${IRAN_IPV6}
    ip addr add ${IRAN_LOCAL_IPV4}/30 dev ${TUNNEL_GRE6_NAME}_KH
    ip link set ${TUNNEL_GRE6_NAME}_KH mtu 1436
    ip link set ${TUNNEL_GRE6_NAME}_KH up
    
    # Step 3: IP Forward و iptables
    echo -e "${YELLOW}[3/4] تنظیم IP Forward و iptables...${NC}"
    sysctl -w net.ipv4.ip_forward=1
    
    # فقط اگر اولین تانل باشه، قوانین پایه رو اضافه کن
    if [[ $TUNNEL_ID -eq 1 ]]; then
        iptables -t nat -A PREROUTING -p tcp --dport 22 -j DNAT --to-destination ${IRAN_LOCAL_IPV4}
    fi
    iptables -t nat -A PREROUTING -j DNAT --to-destination ${KHAREJ_LOCAL_IPV4}
    iptables -t nat -A POSTROUTING -j MASQUERADE
    
    # Step 4: ذخیره در rc.local
    echo -e "${YELLOW}[4/4] ذخیره تنظیمات برای بوت...${NC}"
    
    if [[ ! -f /etc/rc.local ]]; then
        echo '#!/bin/bash' > /etc/rc.local
        echo '' >> /etc/rc.local
    fi
    
    # حذف exit 0 قبلی اگه هست
    sed -i '/^exit 0$/d' /etc/rc.local
    
    cat >> /etc/rc.local << EOF

# Tunnel ${TUNNEL_ID} - Iran to Kharej
ip tunnel add ${TUNNEL_6TO4_NAME}_KH mode sit remote ${KHAREJ_IPV4} local ${IRAN_IPV4}
ip -6 addr add ${IRAN_IPV6}/64 dev ${TUNNEL_6TO4_NAME}_KH
ip link set ${TUNNEL_6TO4_NAME}_KH mtu 1480
ip link set ${TUNNEL_6TO4_NAME}_KH up

ip -6 tunnel add ${TUNNEL_GRE6_NAME}_KH mode ip6gre remote ${KHAREJ_IPV6} local ${IRAN_IPV6}
ip addr add ${IRAN_LOCAL_IPV4}/30 dev ${TUNNEL_GRE6_NAME}_KH
ip link set ${TUNNEL_GRE6_NAME}_KH mtu 1436
ip link set ${TUNNEL_GRE6_NAME}_KH up

sysctl -w net.ipv4.ip_forward=1
iptables -t nat -A PREROUTING -j DNAT --to-destination ${KHAREJ_LOCAL_IPV4}
iptables -t nat -A POSTROUTING -j MASQUERADE

EOF
    
    echo 'exit 0' >> /etc/rc.local
    chmod +x /etc/rc.local
    
    echo ""
    echo -e "${GREEN}=== تانل با موفقیت ایجاد شد ===${NC}"
    echo ""
    echo -e "برای تست، از سرور ایران پینگ بگیرید:"
    echo -e "  ${YELLOW}ping6 ${KHAREJ_IPV6}${NC}"
    echo -e "  ${YELLOW}ping ${KHAREJ_LOCAL_IPV4}${NC}"
}

# ایجاد تانل سرور خارج
setup_kharej() {
    calc_addresses $TUNNEL_ID
    
    echo -e "${BLUE}=== راه‌اندازی تانل روی سرور خارج ===${NC}"
    echo -e "تانل ID: ${YELLOW}${TUNNEL_ID}${NC}"
    echo -e "آیپی خارج: ${YELLOW}${KHAREJ_IPV4}${NC}"
    echo -e "آیپی ایران: ${YELLOW}${IRAN_IPV4}${NC}"
    echo -e "IPv6 خارج: ${YELLOW}${KHAREJ_IPV6}${NC}"
    echo -e "IPv6 ایران: ${YELLOW}${IRAN_IPV6}${NC}"
    echo -e "IPv4 لوکال خارج: ${YELLOW}${KHAREJ_LOCAL_IPV4}${NC}"
    echo -e "IPv4 لوکال ایران: ${YELLOW}${IRAN_LOCAL_IPV4}${NC}"
    echo ""
    
    # Step 1: تانل 6to4
    echo -e "${YELLOW}[1/3] ایجاد تانل 6to4...${NC}"
    ip tunnel add ${TUNNEL_6TO4_NAME}_IR mode sit remote ${IRAN_IPV4} local ${KHAREJ_IPV4}
    ip -6 addr add ${KHAREJ_IPV6}/64 dev ${TUNNEL_6TO4_NAME}_IR
    ip link set ${TUNNEL_6TO4_NAME}_IR mtu 1480
    ip link set ${TUNNEL_6TO4_NAME}_IR up
    
    # Step 2: تانل GRE6
    echo -e "${YELLOW}[2/3] ایجاد تانل GRE6...${NC}"
    ip -6 tunnel add ${TUNNEL_GRE6_NAME}_IR mode ip6gre remote ${IRAN_IPV6} local ${KHAREJ_IPV6}
    ip addr add ${KHAREJ_LOCAL_IPV4}/30 dev ${TUNNEL_GRE6_NAME}_IR
    ip link set ${TUNNEL_GRE6_NAME}_IR mtu 1436
    ip link set ${TUNNEL_GRE6_NAME}_IR up
    
    # Step 3: ذخیره در rc.local
    echo -e "${YELLOW}[3/3] ذخیره تنظیمات برای بوت...${NC}"
    
    if [[ ! -f /etc/rc.local ]]; then
        echo '#!/bin/bash' > /etc/rc.local
        echo '' >> /etc/rc.local
    fi
    
    # حذف exit 0 قبلی اگه هست
    sed -i '/^exit 0$/d' /etc/rc.local
    
    cat >> /etc/rc.local << EOF

# Tunnel ${TUNNEL_ID} - Kharej to Iran
ip tunnel add ${TUNNEL_6TO4_NAME}_IR mode sit remote ${IRAN_IPV4} local ${KHAREJ_IPV4}
ip -6 addr add ${KHAREJ_IPV6}/64 dev ${TUNNEL_6TO4_NAME}_IR
ip link set ${TUNNEL_6TO4_NAME}_IR mtu 1480
ip link set ${TUNNEL_6TO4_NAME}_IR up

ip -6 tunnel add ${TUNNEL_GRE6_NAME}_IR mode ip6gre remote ${IRAN_IPV6} local ${KHAREJ_IPV6}
ip addr add ${KHAREJ_LOCAL_IPV4}/30 dev ${TUNNEL_GRE6_NAME}_IR
ip link set ${TUNNEL_GRE6_NAME}_IR mtu 1436
ip link set ${TUNNEL_GRE6_NAME}_IR up

EOF
    
    echo 'exit 0' >> /etc/rc.local
    chmod +x /etc/rc.local
    
    echo ""
    echo -e "${GREEN}=== تانل با موفقیت ایجاد شد ===${NC}"
    echo ""
    echo -e "برای تست، از سرور خارج پینگ بگیرید:"
    echo -e "  ${YELLOW}ping6 ${IRAN_IPV6}${NC}"
    echo -e "  ${YELLOW}ping ${IRAN_LOCAL_IPV4}${NC}"
}

# اجرای اصلی
case "$ROLE" in
    iran)
        if [[ -z "$KHAREJ_IPV4" ]] || [[ -z "$IRAN_IPV4" ]]; then
            echo -e "${RED}خطا: --kharej-ip و --iran-ip الزامی هستند${NC}"
            exit 1
        fi
        setup_iran
        ;;
    kharej)
        if [[ -z "$KHAREJ_IPV4" ]] || [[ -z "$IRAN_IPV4" ]]; then
            echo -e "${RED}خطا: --kharej-ip و --iran-ip الزامی هستند${NC}"
            exit 1
        fi
        setup_kharej
        ;;
    remove)
        if [[ -z "$ROLE_FOR_REMOVE" ]]; then
            echo -e "${RED}خطا: --role (iran یا kharej) الزامی است${NC}"
            exit 1
        fi
        remove_tunnel $TUNNEL_ID $ROLE_FOR_REMOVE
        ;;
    status)
        show_status
        ;;
    --help|-h|help)
        show_help
        ;;
    *)
        echo -e "${RED}نقش نامعتبر: $ROLE${NC}"
        echo "از 'iran' یا 'kharej' یا 'remove' یا 'status' استفاده کنید"
        exit 1
        ;;
esac
