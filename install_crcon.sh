#!/bin/bash
# ┌───────────────────────────────────────────────────────────────────────────┐
# │ CRCON installer                                                           │
# └───────────────────────────────────────────────────────────────────────────┘
# The script will :
# - install curl, git, Docker and Docker Compose plugin if needed
# - install the latest CRCON on a fresh Linux server
# - prompt the user to enter RCON credentials for the first HLL game server.
# - configure Scoreboard public stat site url
# - prompt the user to define a new admin password
# 
# Supported Linux distributions
# (tested)
#   - Debian 10 / 12.9.0
#   - Ubuntu 20.04 LTS / 24.04.1
#   - Fedora server 41-1.4

# Source: https://github.com/ElGuillermo/HLL_CRCON_Installer
# Feel free to use/modify/distribute, as long as you keep this note in your code

# --- Functions ---

# Function to check privileges and set $SUDO
check_privileges() {
    printf "\033[36m?\033[0m Checking current user permissions...\n"
    SUDO=""

    # Check if the user is root
    if [[ "$(id -u)" -eq 0 ]]; then
        printf "└ \033[32mV\033[0m You are running this script as root.\n"
        return 0
    fi

    printf "└ \033[31mX\033[0m You are not running this script as root.\n"

    # Check if sudo is available
    if ! command -v sudo &>/dev/null; then
        printf "    └ \033[31mX\033[0m The sudo command is not installed. Unable to check privileges.\n\n"
        printf "Sorry : we can't go further :/ Exiting...\n\n"
        exit 1
    fi

    # Check if user can run sudo without a password
    if sudo -n true 2>/dev/null; then
        printf "    └ \033[32mV\033[0m User '$(whoami)' has sudo privileges.\n"
        SUDO="sudo"
        return 0
    fi

    # Fallback: Check if sudo -l contains an "ALL" rule (ignoring localization)
    if LANG=C sudo -l 2>/dev/null | grep -Ez '(ALL[[:space:]]*:[[:space:]]*ALL)[[:space:]]*ALL' >/dev/null; then
        printf "    └ \033[32mV\033[0m User '$(whoami)' has sudo privileges.\n"
        SUDO="sudo"
        return 0
    fi

    # If neither check passes, deny access
    printf "    └ \033[31mX\033[0m User '$(whoami)' does NOT have sudo privileges.\n"
    printf "      Please log in as a user with sudo access.\n\n"
    printf "Sorry : we can't go further :/ Exiting...\n\n"
    exit 1
}

# Be sure we're in the current user's home folder
ensure_home_directory() {
    printf "\033[36m?\033[0m Checking if we're in user's home folder...\n"
    CURRENT_DIR=$(pwd)
    USERNAME="${USER:-$(whoami)}"
    HOME_DIR=$(eval echo "~$USERNAME")

    if [[ ! "$CURRENT_DIR" == "$HOME_DIR" ]]; then
        printf "  └ \033[31mX\033[0m The current folder (\033[33m$CURRENT_DIR\033[0m) is not the user's home folder (\033[33m$HOME_DIR\033[0m).\n"
        printf "    └ Changing to the home folder...\n"
        cd "$HOME_DIR" || exit 1
        printf "    └ \033[32mV\033[0m We're now in the home folder: \033[33m$HOME_DIR\033[0m\n"
    else
        printf "  └ \033[32mV\033[0m Already in the user's home folder: \033[33m$CURRENT_DIR\033[0m\n"
    fi
}

# Detect Linux distro
linux_flavor(){
    printf "\033[36m?\033[0m Detecting Linux flavor...\n"
    if [[ -f "/etc/os-release" ]]; then
        DISTRO=$(grep ^ID= /etc/os-release | cut -d= -f2 | tr -d '"')
    elif [[ -f "/etc/redhat-release" ]]; then
        DISTRO="rhel"
    elif [[ -f "/etc/debian_version" ]]; then
        DISTRO="debian"
    elif [[ -f "/etc/alpine-release" ]]; then
        DISTRO="alpine"
    else
        printf "\033[31mX\033[0m Unable to detect the Linux distribution.\n\n"
        printf "Sorry : we can't go further :/ Exiting...\n\n"
        exit 1
    fi
    printf "  └ \033[32mV\033[0m Detected Linux distribution: \033[33m$DISTRO\033[0m\n"
}

# Install and configure systemd-timesyncd, then set the system to UTC
configure_utc() {
    printf "\033[36m?\033[0m Checking if systemd-timesyncd is installed...\n"

    # Check if timedatectl and systemctl are available (systemd-based systems)
    if command -v timedatectl &> /dev/null && command -v systemctl &> /dev/null; then
        printf "  └ \033[32mV\033[0m systemd-timesyncd is already installed.\n"
    else
        printf "  └ \033[31mX\033[0m systemd-timesyncd is not installed. Installing...\n"
        
        if [[ -f "/etc/debian_version" ]]; then
            $SUDO apt update >/dev/null 2>&1
            $SUDO apt-get install -y systemd >/dev/null 2>&1

        elif [[ $DISTRO == "centos" || $DISTRO == "rhel" || $DISTRO == "fedora" || $DISTRO == "rocky" || $DISTRO == "alma" ]]; then
            if command -v dnf &> /dev/null; then
                $SUDO dnf install -y systemd >/dev/null 2>&1
            else
                $SUDO yum install -y systemd >/dev/null 2>&1
            fi

        elif [[ $DISTRO == "arch" || $DISTRO == "manjaro" ]]; then
            $SUDO pacman -Syu --noconfirm systemd >/dev/null 2>&1

        elif [[ -f "/etc/alpine-release" ]]; then
            $SUDO apk add --no-cache systemd >/dev/null 2>&1

        elif [[ $DISTRO == "opensuse" || $DISTRO == "sles" ]]; then
            $SUDO zypper install -y systemd >/dev/null 2>&1

        else
            printf "    └ \033[31mX\033[0m Automatic installation of systemd is not supported for this distribution.\n"
            printf "      \033[36m?\033[0m You have to install it manually.\n\n"
            printf "Sorry : we can't go further :/ Exiting...\n\n"
            exit 1
        fi
        printf "    └ \033[32mV\033[0m systemd installation completed.\n"
    fi

    # Configure systemd-timesyncd (only on systemd-based systems)
    if command -v systemctl &> /dev/null; then
        printf "  └ \033[36m?\033[0m Configuring systemd-timesyncd...\n"
        
        # Start systemd-timesyncd service
        if ! systemctl is-active --quiet systemd-timesyncd; then
            $SUDO systemctl start systemd-timesyncd
        fi

        # Enable systemd-timesyncd service
        if ! systemctl is-enabled --quiet systemd-timesyncd; then
            $SUDO systemctl enable --now systemd-timesyncd
        fi
        
        # Set NTP and UTC timezone
        $SUDO timedatectl set-ntp true
        $SUDO timedatectl set-timezone UTC
        printf "    └ \033[32mV\033[0m systemd-timesyncd configured and set to UTC.\n"
    else
        printf "  └ \033[31mX\033[0m systemd is not available on this system. Unable to configure systemd-timesyncd.\n"
        printf "    \033[36m?\033[0m You may need to install systemd manually or use another method.\n"
        # exit 1
    fi
}

# Check and install Git
install_git() {
    printf "\033[36m?\033[0m Checking if Git is installed...\n"
    
    if command -v git &> /dev/null; then
        printf "  └ \033[32mV\033[0m Git is already installed.\n"
    else
        printf "  └ \033[31mX\033[0m Git is not installed. Attempting to install it...\n"
        
        if [[ $DISTRO == "ubuntu" || $DISTRO == "debian" ]]; then
            $SUDO apt-get update -y >/dev/null 2>&1
            $SUDO apt-get install -y git >/dev/null 2>&1

        elif [[ $DISTRO == "centos" || $DISTRO == "rhel" || $DISTRO == "fedora" || $DISTRO == "rocky" || $DISTRO == "alma" ]]; then
            if command -v dnf &> /dev/null; then
                $SUDO dnf install -y git >/dev/null 2>&1
            else
                $SUDO yum install -y git >/dev/null 2>&1
            fi

        elif [[ $DISTRO == "arch" || $DISTRO == "manjaro" ]]; then
            $SUDO pacman -Syu --noconfirm git >/dev/null 2>&1

        elif [[ $DISTRO == "alpine" ]]; then
            $SUDO apk add --no-cache git >/dev/null 2>&1

        elif [[ $DISTRO == "opensuse" || $DISTRO == "sles" ]]; then
            $SUDO zypper install -y git >/dev/null 2>&1

        else
            printf "    └ \033[31mX\033[0m Automatic installation of Git is not supported for '$DISTRO'.\n"
            printf "      \033[36m?\033[0m You have to install it manually.\n\n"
            printf "Sorry : we can't go further :/ Exiting...\n\n"
            exit 1
        fi
        printf "    └ \033[32mV\033[0m Git installation completed.\n"
    fi
}

# Install curl
install_curl() {
    printf "\033[36m?\033[0m Checking if curl is installed...\n"
    
    if command -v curl &> /dev/null; then
        printf "  └ \033[32mV\033[0m curl is already installed.\n"
    else
        printf "  └ \033[31mX\033[0m curl is not installed. Attempting to install it...\n"
        
        if [[ $DISTRO == "ubuntu" || $DISTRO == "debian" ]]; then
            $SUDO apt-get update -y >/dev/null 2>&1
            $SUDO apt-get install -y curl >/dev/null 2>&1

        elif [[ $DISTRO == "centos" || $DISTRO == "rhel" || $DISTRO == "fedora" || $DISTRO == "rocky" || $DISTRO == "alma" ]]; then
            if command -v dnf &> /dev/null; then
                $SUDO dnf install -y curl >/dev/null 2>&1
            else
                $SUDO yum install -y curl >/dev/null 2>&1
            fi

        elif [[ $DISTRO == "arch" || $DISTRO == "manjaro" ]]; then
            $SUDO pacman -Syu --noconfirm curl >/dev/null 2>&1

        elif [[ $DISTRO == "alpine" ]]; then
            $SUDO apk add --no-cache curl >/dev/null 2>&1

        elif [[ $DISTRO == "opensuse" || $DISTRO == "sles" ]]; then
            $SUDO zypper install -y curl >/dev/null 2>&1

        else
            printf "    └ \033[31mX\033[0m Automatic installation of curl is not supported for '$DISTRO'.\n"
            printf "      \033[36m?\033[0m You have to install it manually.\n\n"
            printf "Sorry : we can't go further :/ Exiting...\n\n"
            exit 1
        fi
        printf "    └ \033[32mV\033[0m curl installation completed.\n"
    fi
}

# Remove old Docker packages
remove_old_docker() {
    printf "\033[36m?\033[0m Removing old Docker packages (if any)...\n"
    
    if [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
        for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
            $SUDO apt-get remove -y $pkg >/dev/null 2>&1 || true
        done

    elif [[ $DISTRO == "fedora" || $DISTRO == "centos" || $DISTRO == "rhel" || $DISTRO == "rocky" || $DISTRO == "alma" ]]; then
        $SUDO dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine >/dev/null 2>&1 || true

    elif [[ $DISTRO == "arch" || $DISTRO == "manjaro" ]]; then
        $SUDO pacman -Rns docker docker-compose --noconfirm >/dev/null 2>&1 || true

    elif [[ $DISTRO == "openSUSE" || $DISTRO == "sles" ]]; then
        $SUDO zypper remove -y docker docker-compose >/dev/null 2>&1 || true

    elif [[ $DISTRO == "alpine" ]]; then
        $SUDO apk del docker docker-compose >/dev/null 2>&1 || true

    else
        printf "  └ \033[31mX\033[0m Package removal not supported for '$DISTRO'.\n"
        printf "    You have to remove Docker manually.\n\n"
        printf "    Sorry: we can't go further. Exiting...\n\n"
        exit 1
    fi
    
    printf "  └ \033[32mV\033[0m Old Docker packages removed.\n"
}

# Check and install Docker
install_docker() {
    printf "\033[36m?\033[0m Checking if Docker is installed...\n"
    
    if command -v docker &> /dev/null; then
        printf "  └ \033[32mV\033[0m Docker is already installed.\n"
    else
        printf "  └ \033[31mX\033[0m Docker is not installed. Proceeding with the installation...\n"

        if [[ $DISTRO == "ubuntu" || $DISTRO == "debian" ]]; then
            $SUDO apt-get update -y >/dev/null 2>&1
            $SUDO apt-get install -y ca-certificates curl >/dev/null 2>&1
            $SUDO install -m 0755 -d /etc/apt/keyrings >/dev/null 2>&1
            $SUDO curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc >/dev/null 2>&1
            $SUDO chmod a+r /etc/apt/keyrings/docker.asc >/dev/null 2>&1
            if [[ $DISTRO == "debian" ]]; then
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null
            elif [[ $DISTRO == "ubuntu" ]]; then
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$UBUNTU_CODENAME") stable" | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null
            fi
            $SUDO apt-get update -y >/dev/null 2>&1
            $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1

        elif [[ $DISTRO == "fedora" ]]; then
            $SUDO dnf -y install dnf-plugins-core >/dev/null 2>&1
            $SUDO dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo >/dev/null 2>&1
            $SUDO dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1
            $SUDO systemctl enable --now docker >/dev/null 2>&1

        elif [[ $DISTRO == "centos" || $DISTRO == "rhel" || $DISTRO == "rocky" || $DISTRO == "alma" ]]; then
            $SUDO yum install -y yum-utils >/dev/null 2>&1
            $SUDO yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >/dev/null 2>&1
            $SUDO yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin >/dev/null 2>&1
            $SUDO systemctl start docker >/dev/null 2>&1
            $SUDO systemctl enable docker >/dev/null 2>&1

        elif [[ $DISTRO == "arch" || $DISTRO == "manjaro" ]]; then
            $SUDO pacman -Syu --noconfirm docker docker-compose-plugin >/dev/null 2>&1
            $SUDO systemctl enable --now docker >/dev/null 2>&1

        elif [[ $DISTRO == "alpine" ]]; then
            $SUDO apk add --no-cache docker docker-compose-plugin >/dev/null 2>&1
            $SUDO rc-update add docker default >/dev/null 2>&1
            $SUDO service docker start >/dev/null 2>&1

        elif [[ $DISTRO == "openSUSE" ]]; then
            $SUDO zypper install -y docker docker-compose-plugin >/dev/null 2>&1
            $SUDO systemctl enable --now docker >/dev/null 2>&1

        else
            printf "    └ \033[31mX\033[0m Unsupported Linux distribution: '$DISTRO'.\n"
            printf "      \033[36m?\033[0m You have to install Docker manually.\n\n"
            printf "Sorry : we can't go further :/ Exiting...\n\n"
            exit 1
        fi
        
        printf "  └ \033[32mV\033[0m Docker installation completed.\n"
    fi
}

# Check and install Docker Compose plugin
install_docker_compose_plugin() {
    printf "\033[36m?\033[0m Checking if Docker Compose plugin is installed...\n"
    
    if docker compose version &> /dev/null; then
        printf "  └ \033[32mV\033[0m Docker Compose plugin is already installed.\n"
    else
        printf "  └ \033[31mX\033[0m Docker Compose plugin is not installed. Proceeding with the installation...\n"

        if [[ $DISTRO == "ubuntu" || $DISTRO == "debian" ]]; then
            $SUDO apt-get update -y >/dev/null 2>&1
            $SUDO apt-get install -y docker-compose-plugin >/dev/null 2>&1

        elif [[ $DISTRO == "centos" || $DISTRO == "rhel" || $DISTRO == "rocky" || $DISTRO == "alma" ]]; then
            $SUDO yum install -y docker-compose-plugin >/dev/null 2>&1

        elif [[ $DISTRO == "fedora" ]]; then
            $SUDO dnf install -y docker-compose-plugin >/dev/null 2>&1

        elif [[ $DISTRO == "alpine" ]]; then
            $SUDO apk add --no-cache docker-compose-plugin >/dev/null 2>&1

        elif [[ $DISTRO == "arch" || $DISTRO == "manjaro" ]]; then
            $SUDO pacman -Syu --noconfirm docker-compose-plugin >/dev/null 2>&1

        else
            printf "    └ \033[31mX\033[0m Automatic installation of Docker Compose plugin is not supported for '$DISTRO'.\n"
            printf "    \033[36m?\033[0m You have to install it manually.\n\n"
            printf "Sorry : we can't go further :/ Exiting...\n\n"
            exit 1
        fi
        
        printf "└ \033[32mV\033[0m Docker Compose plugin installation completed.\n"
    fi
}

# Stop and delete previous CRCON containers and images
cleanup_crcon() {
    printf "\033[36m?\033[0m Checking for running CRCON containers and images...\n"

    # List CRCON containers
    CONTAINERS=$($SUDO docker ps -q --filter "ancestor=cericmathey/hll_rcon_tool_frontend" --filter "ancestor=cericmathey/hll_rcon_tool" 2>/dev/null)
    NAMED_CONTAINERS=$($SUDO docker ps -q --filter "name=hll_rcon_tool-" 2>/dev/null)
    ALL_CONTAINERS=$(echo -e "$CONTAINERS\n$NAMED_CONTAINERS" | sort -u | sed '/^$/d')

    # Remove containers if any
    if [ -n "$ALL_CONTAINERS" ]; then
        printf "  └ \033[36m?\033[0m Stopping and removing running CRCON containers...\n"
        echo "$ALL_CONTAINERS" | xargs -r $SUDO docker rm -f >/dev/null 2>&1
    else
        printf "  └ \033[32mV\033[0m No running CRCON containers found.\n"
    fi

    # List CRCON images
    IMAGES=("cericmathey/hll_rcon_tool_frontend" "cericmathey/hll_rcon_tool")
    ADDITIONAL_IMAGES=$($SUDO docker images --format "{{.Repository}}" | grep "hll_rcon_tool-" 2>/dev/null || true)
    if [ -n "$ADDITIONAL_IMAGES" ]; then
        while IFS= read -r img; do
            IMAGES+=("$img")
        done <<< "$ADDITIONAL_IMAGES"
    fi

    # Remove images if any
    for IMAGE in "${IMAGES[@]}"; do
        if [ -n "$IMAGE" ]; then
            IMAGE_ID=$($SUDO docker images -q "$IMAGE" 2>/dev/null | sed '/^$/d')

            if [ -n "$IMAGE_ID" ]; then
                printf "  └ \033[36m?\033[0m Removing image: %s\n" "$IMAGE"
                echo "$IMAGE_ID" | xargs -r $SUDO docker rmi -f >/dev/null 2>&1
            else
                printf "  └ \033[32mV\033[0m No image found for: %s\n" "$IMAGE"
            fi
        fi
    done
}

# Check for previous installation and save its essential files
backup_previous_crcon() {
    printf "\033[36m?\033[0m Checking for previous CRCON installation...\n"
    if [[ -d "$HOME_DIR/hll_rcon_tool" ]]; then
        printf "  └ \033[31m!\033[0m Previous CRCON installation found in \033[33m$HOME_DIR/hll_rcon_tool\033[0m\n"

        # Create a backup folder with the current date in its name, so there could be several backups
        BACKUP_FOLDER="$HOME_DIR/crcon_backup_$(date '+%Y-%m-%d_%Hh%M')"
        if [[ -d "$BACKUP_FOLDER" ]]; then
            printf "    └ \033[31m!\033[0m Previous backup folder found.\n"
        else
            $SUDO mkdir "$BACKUP_FOLDER"
            printf "    └ \033[32mV\033[0m Backup folder created in \033[33m$BACKUP_FOLDER\033[0m\n"
        fi

        # Saving the previous .env file
        if [[ -f "$HOME_DIR/hll_rcon_tool/.env" ]]; then
            printf "  └ \033[31m!\033[0m Previous .env file found.\n"
            $SUDO cp "$HOME_DIR/hll_rcon_tool/.env" "$BACKUP_FOLDER/.env"
            printf "    └ \033[32mV\033[0m .env file saved.\n"
        else
            printf "  └ \033[32mV\033[0m No previous .env file found.\n"
        fi

        # Saving the previous compose.yaml file
        if [[ -f "$HOME_DIR/hll_rcon_tool/compose.yaml" ]]; then
            printf "  └ \033[31m!\033[0m Previous compose.yaml file found.\n"
            $SUDO cp "$HOME_DIR/hll_rcon_tool/compose.yaml" "$BACKUP_FOLDER/compose.yaml"
            printf "    └ \033[32mV\033[0m compose.yaml file saved.\n"
        else
            printf "  └ \033[32mV\033[0m No previous compose.yaml file found.\n"
        fi

        # Saving the previous db_data/ folder
        if [[ -d "$HOME_DIR/hll_rcon_tool/db_data" ]]; then
            printf "  └ \033[31m!\033[0m Previous database found.\n"
            $SUDO cp -r "$HOME_DIR/hll_rcon_tool/db_data" "$BACKUP_FOLDER/db_data"
            printf "    └ \033[32mV\033[0m Database saved.\n"
        else
            printf "  └ \033[32mV\033[0m No previous database folder found.\n"
        fi

    else
        printf "└ \033[32mV\033[0m No previous CRCON installation found.\n"
    fi
}

# Validate user input to ensure it is a valid IPv4 address
validate_input_ip() {
    local input="$1"
    if [[ ! "$input" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        printf "\033[31mX\033[0m Error: $input isn't a valid IPv4 address.\n"
        return 1
    fi
    return 0
}

# Validate user input to ensure it contains only numbers in 0-65535 range
validate_input_port() {
    local input="$1"
    if [[ ! "$input" =~ ^[0-9]+$ ]] || (( input < 0 || input > 65535 )); then
        printf "\033[31mX\033[0m Error: $input isn't a valid port number (0-65535).\n"
        return 1
    fi
    return 0
}

# Prompt for user input and replace in the .env file
setup_env_variables() {
    # HLL_DB_PASSWORD and RCONWEB_API_SECRET will be automatically generated
    HLL_DB_PASSWORD=$(date +%s | sha256sum | base64 | head -c 32; echo)
    # Sleep time to avoid getting the same password twice
    sleep 2
    RCONWEB_API_SECRET=$(date +%s | sha256sum | base64 | head -c 32; echo)

    while true; do
        printf "\033[36mEnter your game server's RCON IP\033[0m\n"
        printf "\033[90mHLL_HOST is the RCON IP address, as provided by your game server provider.\033[0m\n"
        printf "\033[90mExample: 123.123.123.123\033[0m\n"
        read -p "Enter game server RCON IP: " HLL_HOST
        if validate_input_ip "$HLL_HOST"; then
            break
        fi
    done

    while true; do
        printf "________________________________________________________________________________\n"
        printf "\033[36mEnter your game server's RCON port\033[0m\n"
        printf "\033[90mHLL_PORT is the RCON port, as provided by your game server provider.\033[0m\n"
        printf "\033[90mIt is NOT the same as the game server (query) or SFTP ports\033[0m\n"
        printf "\033[90mExample: 12345\033[0m\n"
        read -p "Enter game server RCON port: " HLL_PORT
        if validate_input_port "$HLL_PORT"; then
            break
        fi
    done

    printf "________________________________________________________________________________\n"
    printf "\033[36mEnter your game server's RCON password\033[0m\n"
    printf "\033[90mHLL_PASSWORD is the RCON password, as provided by your game server provider.\033[0m\n"
    read -p "Enter game server RCON password: " HLL_PASSWORD

    # Save the values in the .env file
    $SUDO sed -i "s/^HLL_DB_PASSWORD=.*/HLL_DB_PASSWORD=$HLL_DB_PASSWORD/" "$HOME_DIR"/hll_rcon_tool/.env
    $SUDO sed -i "s/^RCONWEB_API_SECRET=.*/RCONWEB_API_SECRET=$RCONWEB_API_SECRET/" "$HOME_DIR"/hll_rcon_tool/.env
    $SUDO sed -i "s/^HLL_HOST=.*/HLL_HOST=$HLL_HOST/" "$HOME_DIR"/hll_rcon_tool/.env
    $SUDO sed -i "s/^HLL_PORT=.*/HLL_PORT=$HLL_PORT/" "$HOME_DIR"/hll_rcon_tool/.env
    $SUDO sed -i "s/^HLL_PASSWORD=.*/HLL_PASSWORD=$HLL_PASSWORD/" "$HOME_DIR"/hll_rcon_tool/.env
}

# --- Script start ---

# Exit immediately if a command exits with a non-zero status.
set -e

printf "\\033c"
printf "┌─────────────────────────────────────────────────────────────────────────────┐\n"
printf "│ CRCON installer                                                             │\n"
printf "└─────────────────────────────────────────────────────────────────────────────┘\n\n"
printf "This script will install the latest CRCON on your Linux server.\n\n"
printf "!!!  WARNING  !!!\n"
printf "If you choose to proceed, \033[33many previous CRCON install will be DELETED\033[0m.\n\n"
printf "The script will try to backup your existing .env, compose.yaml and database,\n"
printf "but it will fail if you have changed the default install paths.\n"
printf "Please make sure to backup any data you find valuable before proceeding.\n\n"
printf "Enter 'yes' to proceed :\n"
read -r user_input
if [[ "$user_input" != "yes" ]]; then
    printf "Exiting the script.\n"
    exit 1
fi

printf "\n"
check_privileges
ensure_home_directory
linux_flavor
configure_utc

printf "\n┌─────────────────────────────────────────────────────────────────────────────┐\n"
printf "│ CRCON installer - Check and install software requirements                   │\n"
printf "└─────────────────────────────────────────────────────────────────────────────┘\n\n"

install_git
install_curl
remove_old_docker
install_docker
install_docker_compose_plugin

printf "\n┌─────────────────────────────────────────────────────────────────────────────┐\n"
printf "│ CRCON installer - Backup previous CRCON config and data, then delete it     │\n"
printf "└─────────────────────────────────────────────────────────────────────────────┘\n\n"

cleanup_crcon
backup_previous_crcon

# Deleting previous CRCON folder (if any)
if [[ -d "$HOME_DIR/hll_rcon_tool" ]]; then
    $SUDO rm -rf "$HOME_DIR/hll_rcon_tool"
fi

# Download CRCON
printf "\n┌─────────────────────────────────────────────────────────────────────────────┐\n"
printf "│ CRCON installer - Download CRCON                                            │\n"
printf "└─────────────────────────────────────────────────────────────────────────────┘\n\n"

printf "Cloning repo...\n"
$SUDO git clone https://github.com/MarechJ/hll_rcon_tool.git >/dev/null 2>&1

printf "Marking the local repo as safe...\n"
$SUDO git config --global --add safe.directory "$HOME_DIR/hll_rcon_tool" >/dev/null 2>&1

cd "$HOME_DIR"/hll_rcon_tool

printf "Detaching HEAD to the latest version tag...\n"
$SUDO git fetch --tags >/dev/null 2>&1
$SUDO git checkout $(git tag -l --contains HEAD | tail -n1) >/dev/null 2>&1

printf "\n┌─────────────────────────────────────────────────────────────────────────────┐\n"
printf "│ CRCON installer - Set configuration files                                   │\n"
printf "└─────────────────────────────────────────────────────────────────────────────┘\n\n"

$SUDO cp docker-templates/one-server.yaml compose.yaml
$SUDO cp default.env .env
setup_env_variables

# Launching CRCON for the first time
printf "\n┌─────────────────────────────────────────────────────────────────────────────┐\n"
printf "│ CRCON installer - CSRF and Scoreboard configuration                         │\n"
printf "└─────────────────────────────────────────────────────────────────────────────┘\n\n"

$SUDO docker compose up -d --remove-orphans
printf "Giving some time to the CRCON Docker containers to be fully started and running...\n"
sleep 15

WAN_IP=$(curl -s https://ipinfo.io/ip)
if [[ -n "$WAN_IP" ]]; then
    PRIVATE_URL="http://$WAN_IP:8010/"
    PUBLIC_URL="http://$WAN_IP:7010/"

    # update CRCON settings "server_url"
    printf "Updating CRCON settings : mark the WAN IP:private_port as safe for CSRF...\n"
    SQL="UPDATE public.user_config SET value = jsonb_set(value, '{server_url}', '\"$PRIVATE_URL\"', true) WHERE key = '1_RconServerSettingsUserConfig';"
    $SUDO docker compose exec -it postgres psql -U rcon -c "$SQL"

    # update Scoreboard "public_scoreboard_url"
    printf "Updating CRCON settings : set public Scoreboard url...\n"
    SQL="UPDATE public.user_config SET value = jsonb_set(value, '{public_scoreboard_url}', '\"$PUBLIC_URL\"', true) WHERE key = '1_ScoreboardUserConfig';"
    $SUDO docker compose exec -it postgres psql -U rcon -c "$SQL"

    # restart CRCON
    printf "Restarting CRCON to apply the changes...\n"
    $SUDO docker compose down
    $SUDO docker compose up -d --remove-orphans
    printf "Giving some time to the CRCON Docker containers to be fully started and running...\n"
    sleep 15
else
    printf "\033[31mX\033[0m Failed to retrieve the WAN IP address.\n"
    printf "  └ \033[36m?\033[0m You'll have to manually set your CRCON url in CRCON settings\n"
    printf "      before accessing the admin panel and manage users accounts.\n"
    printf "      Failing to do so will trigger 'CSRF' errors on your web browser.\n"
    printf "      (see \033[36mhttps://github.com/MarechJ/hll_rcon_tool/wiki/\033[0m)\n\n"
    read -s -n 1 -p "Press any key to continue..."
fi

printf "\n┌─────────────────────────────────────────────────────────────────────────────┐\n"
printf "│ CRCON installer - Change \"admin\" password                                   │\n"
printf "└─────────────────────────────────────────────────────────────────────────────┘\n\n"

$SUDO docker compose exec -it backend_1 python3 rconweb/manage.py changepassword admin

printf "\n┌─────────────────────────────────────────────────────────────────────────────┐\n"
printf "│ CRCON installer - Done !                                                    │\n"
printf "└─────────────────────────────────────────────────────────────────────────────┘\n\n"

printf "\033[32mCRCON is installed and running !\033[0m\n\n"
printf "Optional, but heavily recommended :\n"
printf "  To enforce security and allow to finetune each user's permissions,\n"
printf "  you should create new user(s) account(s) and delete (or disable) the default \"admin\" account.\n\n"
printf "  To do so, access the admin panel at \033[36mhttp://$WAN_IP:8010/admin\033[0m\n"
printf "  The default login name is '\033[90madmin\033[0m', the password is the one you've just set.\n\n"
printf "  You'll find a complete guide on how to manage users at \033[36mhttps://github.com/MarechJ/hll_rcon_tool/wiki/\033[0m\n\n"
printf "Once done, you can access CRCON at :\n"
printf "  private (game admin) interface : \033[36mhttp://$WAN_IP:8010/\033[0m\n"
printf "  public (stats) website : \033[36mhttp://$WAN_IP:7010/\033[0m\n\n"
printf "Happy gaming !\n\n"
