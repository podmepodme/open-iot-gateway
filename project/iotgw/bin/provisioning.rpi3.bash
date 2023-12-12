#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

readonly _PACKAGES="vim btop git tmux"
readonly _USERNAME="maker"
readonly _PASSWORD="rekam"
readonly _TIMEZONE="Europe/Bratislava"
readonly _OS_NAME="Debian GNU/Linux 12 (bookworm)"
readonly _OS_VERSION_ID="12"
readonly _ROOM="${1:?Name of the room is missing as first parameter.}"

# functions
function log() {
    local message="${*}"
    local now
    now=$(date +%H:%M:%S)

    printf "\e[0;35m%s\e[m: \e[0;33m%s\e[m\n" "${now}" "${message}"
}

function install_software() {
    log "Software installation"

    apt update && sudo apt upgrade --yes
    apt install --yes ${_PACKAGES}

    # install docker
    if [[ ! $(which docker) ]]; then
        log "Installing Docker"
        curl -sSL https://get.docker.io | sh
    fi

    wget https://github.com/Macchina-CLI/macchina/releases/download/v6.1.8/macchina-linux-aarch64 -O /usr/local/bin/macchina
    chmod +x /usr/local/bin/macchina
}

function setup_maker() {
    log "Create and setup maker user"

    # create user maker
    if ! id "${_USERNAME}" > /dev/null 2>&1; then
        useradd --password "${_PASSWORD}" --user-group "${_USERNAME}"
        chpasswd <<<"${_USERNAME}:${_PASSWORD}"
    fi

    # add maker to group docker
    if [[ ! $(groups "${_USERNAME}") =~ "docker" ]]; then
        usermod -aG docker "${_USERNAME}"
    fi
}

function setup_system() {
    log "System Setup."

    # set the hostname based on the name of the room and update /etc/hosts
    hostnamectl hostname "${_ROOM}-gw"
    sed -i '/127.0.1.1/d' /etc/hosts
    sed -i "\$a127.0.1.1 ${_ROOM}-gw" /etc/hosts

    # disable hwmon kernel module because of too many undervoltage messages
    printf "blacklist raspberrypi_hwmon\n" >/etc/modprobe.d/raspberry_hwmon.conf

    timedatectl set-timezone "${_TIMEZONE}"
}

function setup_wifi_ap() {
    log "Setup WiFi AP"

    # setup wifi hotspot
    nmcli connection add type wifi ifname wlan0 con-name Hotspot autoconnect no ssid "${_ROOM}-things"
    nmcli connection modify Hotspot 802-11-wireless.mode ap 802-11-wireless.band bg ipv4.method shared
    nmcli connection modify Hotspot wifi-sec.key-mgmt wpa-psk
    nmcli connection modify Hotspot wifi-sec.psk "welcome.to.the.${_ROOM}"
    nmcli connection modify Hotspot ipv4.addresses 10.0.0.1/24
    nmcli connection modify Hotspot connection.autoconnect yes
    nmcli connection up Hotspot

    # drop trafik comming from the wlan0 interface
    nft add table inet filter
    nft add chain inet filter forward { type filter hook forward priority 0 \; }
    nft add rule inet filter forward iifname "wlan0" drop
    nft add rule inet filter forward oifname "wlan0" drop

    # make the rules apply on system startup
    printf "#!/usr/sbin/nft -f\n\nflush ruleset\n\n" >/etc/nftables.conf
    nft list ruleset >>/etc/nftables.conf

    # enable nftables on boot
    systemctl enable nftables
}

function is_proper_distro() {
    source /etc/os-release

    if [[ "${PRETTY_NAME}" != "${_OS_NAME}" || "${VERSION_ID}" != "${_OS_VERSION_ID}" ]]; then
        printf "ERROR: Incorrect OS or version.\nExpected OS is '%s' with version '%s'\nCurrent OS is '%s' with version '%s'\n" "${_OS_NAME}" \
            "${_OS_VERSION_ID}" "${PRETTY_NAME}" "${VERSION_ID}" >&2
        exit 1
    fi
}

function is_root() {
    if [[ $UID != 0 ]]; then
        printf "ERROR: Need to be root.\n" >&2
        exit 1
    fi
}

function is_in_proper_folder() {
    if [[ ! -f "docker-compose.yaml" ]]; then
        printf "ERROR: Script must be executed from folder with docker-compose.yaml file." >&2
        exit 1
    fi
}

function main() {
    is_root
    is_proper_distro
    is_in_proper_folder

    install_software
    setup_system
    setup_wifi_ap
    setup_maker

    log "Reboot in 10 seconds..."
    sleep 10
    log "Rebooting now..."
    reboot
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi