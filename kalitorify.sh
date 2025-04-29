#!/bin/bash

# Anon-Route v1.0.0 - A Transparent Proxy Tool using Tor
# Author: Azadvir Singh

#==========================#
#    Terminal Colors       #
#==========================#
green="\033[1;32m"
red="\033[1;31m"
yellow="\033[1;33m"
cyan="\033[1;36m"
reset="\033[0m"

#==========================#
#    Message Functions     #
#==========================#
info() {
    echo -e "${cyan}[INFO]${reset} $1"
}

success() {
    echo -e "${green}[SUCCESS]${reset} $1"
}

error() {
    echo -e "${red}[ERROR]${reset} $1"
}

warning() {
    echo -e "${yellow}[WARNING]${reset} $1"
}

#==========================#
#     Root Check           #
#==========================#
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root."
    exit 1
fi

#==========================#
#   Tor Setup Functions    #
#==========================#

setup_torrc() {
    info "Setting up Tor configuration..."
    cat > /etc/tor/torrc <<EOF
Log notice file /var/log/tor/notices.log
VirtualAddrNetworkIPv4 10.192.0.0/10
AutomapHostsSuffixes .onion,.exit
AutomapHostsOnResolve 1
TransPort 9040
DNSPort 53
EOF
    success "Tor configuration file updated."
}

start_tor() {
    info "Starting Tor service..."
    systemctl start tor
    systemctl enable tor
    success "Tor started successfully."
}

stop_tor() {
    info "Stopping Tor service..."
    systemctl stop tor
    systemctl disable tor
    success "Tor stopped successfully."
}

#==========================#
#   IP & Firewall Setup    #
#==========================#

check_ip() {
    echo
    info "Checking your current public IP address:"
    curl -s https://check.torproject.org | grep -q "Congratulations" && \
        echo -e "${green}Your traffic is routed through Tor.${reset}" || \
        echo -e "${red}Your traffic is NOT routed through Tor.${reset}"
    echo
}

configure_iptables() {
    info "Flushing existing iptables rules..."
    iptables -F
    iptables -t nat -F

    info "Setting iptables rules to route through Tor..."

    # Allow Tor
    iptables -t nat -A OUTPUT -m owner --uid-owner debian-tor -j RETURN

    # Allow local loopback
    iptables -t nat -A OUTPUT -o lo -j RETURN
    iptables -A OUTPUT -o lo -j ACCEPT

    # Redirect DNS to Tor
    iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 53

    # Redirect TCP traffic to Tor
    iptables -t nat -A OUTPUT -p tcp --syn -j REDIRECT --to-ports 9040

    # Allow established connections
    iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    # Allow Tor UID to connect directly
    iptables -A OUTPUT -m owner --uid-owner debian-tor -j ACCEPT

    # Reject everything else
    iptables -A OUTPUT -j REJECT

    success "iptables configured successfully."
}

reset_iptables() {
    info "Resetting iptables to default..."
    iptables -F
    iptables -t nat -F
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    success "iptables reset complete."
}

#==========================#
#        Main Menu         #
#==========================#

start_anonroute() {
    setup_torrc
    start_tor
    configure_iptables
    check_ip
}

stop_anonroute() {
    stop_tor
    reset_iptables
    check_ip
}

restart_anonroute() {
    stop_anonroute
    start_anonroute
}

show_menu() {
    echo -e "${cyan}"
    echo "=============================="
    echo "     Anon-Route Tool v1.0     "
    echo "=============================="
    echo -e "${reset}"
    echo "1. Start Anon-Route"
    echo "2. Stop Anon-Route"
    echo "3. Restart Anon-Route"
    echo "4. Check IP"
    echo "5. Exit"
    echo
    read -rp "Choose an option: " option

    case $option in
        1) start_anonroute ;;
        2) stop_anonroute ;;
        3) restart_anonroute ;;
        4) check_ip ;;
        5) exit 0 ;;
        *) error "Invalid option. Try again." ;;
    esac
}

#==========================#
#         Run Tool         #
#==========================#
while true; do
    show_menu
done
