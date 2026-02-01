#!/bin/bash
#
# 6to4 + GRE6 Tunnel Setup Script
# Supports multiple Iran servers to one foreign server
# Interactive mode - prompts user for inputs
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default IPv6 base
IPV6_BASE="fde8:b030:25cf"

# Prompt for input with default value
prompt_default() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    read -p "$(echo -e ${CYAN}$prompt${NC}) [${default}]: " input
    eval "$var_name=\"${input:-$default}\""
}

# Prompt for required input
prompt_required() {
    local prompt="$1"
    local var_name="$2"
    while true; do
        read -p "$(echo -e ${CYAN}$prompt${NC}): " input
        if [[ -n "$input" ]]; then
            eval "$var_name=\"$input\""
            break
        fi
        echo -e "${RED}This field is required.${NC}"
    done
}

# Main menu
show_menu() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   6to4 + GRE6 Tunnel Setup${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "  1) Setup Iran server (tunnel endpoint)"
    echo "  2) Setup Foreign server (tunnel endpoint)"
    echo "  3) Remove tunnel"
    echo "  4) Show tunnel status"
    echo "  5) Exit"
    echo ""
}

# Calculate addresses based on tunnel-id
calc_addresses() {
    local tid=$1
    
    IRAN_IPV6="${IPV6_BASE}:${tid}::1"
    KHAREJ_IPV6="${IPV6_BASE}:${tid}::2"
    
    local subnet=$((19 + tid))
    IRAN_LOCAL_IPV4="172.20.${subnet}.1"
    KHAREJ_LOCAL_IPV4="172.20.${subnet}.2"
    
    TUNNEL_6TO4_NAME="6to4_T${tid}"
    TUNNEL_GRE6_NAME="GRE6_T${tid}"
}

# Show tunnel status
show_status() {
    echo -e "${BLUE}=== Tunnel Status ===${NC}"
    echo ""
    echo -e "${YELLOW}6to4 Tunnels:${NC}"
    ip tunnel show 2>/dev/null | grep -E "6to4|sit" || echo "  No 6to4 tunnels found"
    echo ""
    echo -e "${YELLOW}GRE6 Tunnels:${NC}"
    ip -6 tunnel show 2>/dev/null | grep -E "GRE6|ip6gre" || echo "  No GRE6 tunnels found"
    echo ""
    echo -e "${YELLOW}Interfaces:${NC}"
    ip addr show 2>/dev/null | grep -E "6to4|GRE6" -A 2 || echo "  No tunnel interfaces found"
    echo ""
}

# Remove tunnel
remove_tunnel() {
    echo -e "${YELLOW}=== Remove Tunnel ===${NC}"
    echo ""
    
    prompt_required "Enter tunnel ID to remove (1, 2, 3, ...)" "TUNNEL_ID"
    
    echo ""
    echo "Select server role:"
    echo "  1) Iran server"
    echo "  2) Foreign server"
    read -p "Choice [1-2]: " role_choice
    
    local role=""
    case "$role_choice" in
        1) role="iran" ;;
        2) role="kharej" ;;
        *) echo -e "${RED}Invalid choice.${NC}"; return 0 ;;
    esac
    
    calc_addresses $TUNNEL_ID
    
    echo ""
    echo -e "${YELLOW}Removing tunnel ${TUNNEL_ID}...${NC}"
    
    if [[ "$role" == "iran" ]]; then
        ip tunnel del ${TUNNEL_6TO4_NAME}_KH 2>/dev/null || true
        ip -6 tunnel del ${TUNNEL_GRE6_NAME}_KH 2>/dev/null || true
    elif [[ "$role" == "kharej" ]]; then
        ip tunnel del ${TUNNEL_6TO4_NAME}_IR 2>/dev/null || true
        ip -6 tunnel del ${TUNNEL_GRE6_NAME}_IR 2>/dev/null || true
    fi
    
    if [[ -f /etc/rc.local ]]; then
        sed -i "/${TUNNEL_6TO4_NAME}/d" /etc/rc.local 2>/dev/null || true
        sed -i "/${TUNNEL_GRE6_NAME}/d" /etc/rc.local 2>/dev/null || true
    fi
    
    echo -e "${GREEN}Tunnel ${TUNNEL_ID} removed successfully.${NC}"
    echo ""
}

# Setup Iran server
setup_iran() {
    echo -e "${YELLOW}=== Setup Iran Server ===${NC}"
    echo ""
    
    prompt_required "Enter Iran server public IPv4" "IRAN_IPV4"
    prompt_required "Enter Foreign server public IPv4" "KHAREJ_IPV4"
    prompt_default "Enter tunnel ID (1 for first Iran, 2 for second, ...)" "1" "TUNNEL_ID"
    prompt_default "Enter IPv6 base prefix" "$IPV6_BASE" "IPV6_BASE"
    
    calc_addresses $TUNNEL_ID
    
    echo ""
    echo -e "${BLUE}Configuration:${NC}"
    echo "  Iran IPv4:      $IRAN_IPV4"
    echo "  Foreign IPv4:   $KHAREJ_IPV4"
    echo "  Tunnel ID:      $TUNNEL_ID"
    echo "  Iran IPv6:      $IRAN_IPV6"
    echo "  Foreign IPv6:   $KHAREJ_IPV6"
    echo "  Iran Local:     $IRAN_LOCAL_IPV4"
    echo "  Foreign Local:  $KHAREJ_LOCAL_IPV4"
    echo ""
    
    read -p "Proceed? [y/N]: " confirm
    [[ "$confirm" =~ ^[yY] ]] || { echo "Cancelled."; return 0; }
    
    echo ""
    echo -e "${YELLOW}[1/3] Creating 6to4 tunnel...${NC}"
    ip tunnel add ${TUNNEL_6TO4_NAME}_KH mode sit remote ${KHAREJ_IPV4} local ${IRAN_IPV4}
    ip -6 addr add ${IRAN_IPV6}/64 dev ${TUNNEL_6TO4_NAME}_KH
    ip link set ${TUNNEL_6TO4_NAME}_KH mtu 1480
    ip link set ${TUNNEL_6TO4_NAME}_KH up
    
    echo -e "${YELLOW}[2/3] Creating GRE6 tunnel...${NC}"
    ip -6 tunnel add ${TUNNEL_GRE6_NAME}_KH mode ip6gre remote ${KHAREJ_IPV6} local ${IRAN_IPV6}
    ip addr add ${IRAN_LOCAL_IPV4}/30 dev ${TUNNEL_GRE6_NAME}_KH
    ip link set ${TUNNEL_GRE6_NAME}_KH mtu 1436
    ip link set ${TUNNEL_GRE6_NAME}_KH up
    
    echo -e "${YELLOW}[3/3] Saving to rc.local...${NC}"
    if [[ ! -f /etc/rc.local ]]; then
        echo '#!/bin/bash' > /etc/rc.local
        echo '' >> /etc/rc.local
    fi
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

EOF
    echo 'exit 0' >> /etc/rc.local
    chmod +x /etc/rc.local
    
    echo ""
    echo -e "${GREEN}=== Tunnel created successfully ===${NC}"
    echo ""
    echo "To test from Iran server:"
    echo -e "  ${CYAN}ping6 ${KHAREJ_IPV6}${NC}"
    echo -e "  ${CYAN}ping ${KHAREJ_LOCAL_IPV4}${NC}"
    echo ""
}

# Setup Foreign (Kharej) server
setup_kharej() {
    echo -e "${YELLOW}=== Setup Foreign Server ===${NC}"
    echo ""
    
    prompt_required "Enter Foreign server public IPv4" "KHAREJ_IPV4"
    prompt_required "Enter Iran server public IPv4" "IRAN_IPV4"
    prompt_default "Enter tunnel ID (must match Iran server)" "1" "TUNNEL_ID"
    prompt_default "Enter IPv6 base prefix" "$IPV6_BASE" "IPV6_BASE"
    
    calc_addresses $TUNNEL_ID
    
    echo ""
    echo -e "${BLUE}Configuration:${NC}"
    echo "  Foreign IPv4:   $KHAREJ_IPV4"
    echo "  Iran IPv4:      $IRAN_IPV4"
    echo "  Tunnel ID:      $TUNNEL_ID"
    echo "  Foreign IPv6:   $KHAREJ_IPV6"
    echo "  Iran IPv6:      $IRAN_IPV6"
    echo "  Foreign Local:  $KHAREJ_LOCAL_IPV4"
    echo "  Iran Local:     $IRAN_LOCAL_IPV4"
    echo ""
    
    read -p "Proceed? [y/N]: " confirm
    [[ "$confirm" =~ ^[yY] ]] || { echo "Cancelled."; return 0; }
    
    echo ""
    echo -e "${YELLOW}[1/3] Creating 6to4 tunnel...${NC}"
    ip tunnel add ${TUNNEL_6TO4_NAME}_IR mode sit remote ${IRAN_IPV4} local ${KHAREJ_IPV4}
    ip -6 addr add ${KHAREJ_IPV6}/64 dev ${TUNNEL_6TO4_NAME}_IR
    ip link set ${TUNNEL_6TO4_NAME}_IR mtu 1480
    ip link set ${TUNNEL_6TO4_NAME}_IR up
    
    echo -e "${YELLOW}[2/3] Creating GRE6 tunnel...${NC}"
    ip -6 tunnel add ${TUNNEL_GRE6_NAME}_IR mode ip6gre remote ${IRAN_IPV6} local ${KHAREJ_IPV6}
    ip addr add ${KHAREJ_LOCAL_IPV4}/30 dev ${TUNNEL_GRE6_NAME}_IR
    ip link set ${TUNNEL_GRE6_NAME}_IR mtu 1436
    ip link set ${TUNNEL_GRE6_NAME}_IR up
    
    echo -e "${YELLOW}[3/3] Saving to rc.local...${NC}"
    if [[ ! -f /etc/rc.local ]]; then
        echo '#!/bin/bash' > /etc/rc.local
        echo '' >> /etc/rc.local
    fi
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
    echo -e "${GREEN}=== Tunnel created successfully ===${NC}"
    echo ""
    echo "To test from Foreign server:"
    echo -e "  ${CYAN}ping6 ${IRAN_IPV6}${NC}"
    echo -e "  ${CYAN}ping ${IRAN_LOCAL_IPV4}${NC}"
    echo ""
}

# Main loop
main() {
    # Check root
    [[ $EUID -eq 0 ]] || {
        echo -e "${RED}Error: This script must be run as root.${NC}"
        echo "Use: sudo $0"
        exit 1
    }
    
    while true; do
        show_menu
        read -p "Select option [1-5]: " choice
        echo ""
        
        case "$choice" in
            1) setup_iran ;;
            2) setup_kharej ;;
            3) remove_tunnel ;;
            4) show_status ;;
            5) echo "Goodbye."; exit 0 ;;
            *) echo -e "${RED}Invalid option.${NC}" ;;
        esac
        
        [[ "$choice" != "5" ]] && {
            echo ""
            read -p "Press Enter to continue..."
        }
    done
}

main
