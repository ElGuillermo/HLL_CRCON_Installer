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
# (untested)
#   - CentOS 8
#   - RHEL 8
#   - Rocky Linux 8.4
#   - AlmaLinux 8.4

# Source: https://github.com/ElGuillermo/HLL_CRCON_Installer
# Feel free to use/modify/distribute, as long as you keep this note in your code

# --- Functions ---

# Be sure we're in the current user's home folder
ensure_home_directory() {
    printf "\033[36m?\033[0m Checking if we're in user's home folder...\n"
    CURRENT_DIR=$(pwd)
    HOME_DIR=$(eval echo "~$USER")

    if [[ ! "$CURRENT_DIR" == "$HOME_DIR" ]]; then
        printf "  └ \033[31mX\033[0m The current folder (\033[33m$CURRENT_DIR\033[0m) is not the user's home folder (\033[33m$HOME_DIR\033[0m).\n"
        printf "    └ Changing to the home folder...\n"
        cd "$HOME_DIR"
        printf "    └ \033[32mV\033[0m We're now in the home folder: \033[33m$HOME_DIR\033[0m\n"
    else
        printf "  └ \033[32mV\033[0m Already in the user's home folder: \033[33m$CURRENT_DIR\033[0m\n"
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
            $SUDO apt-get update -y
            $SUDO apt-get install -y git-all
            printf "    └ \033[32mV\033[0m Git installation completed.\n"
        elif [[ $DISTRO == "centos" || $DISTRO == "rhel" || $DISTRO == "fedora" || $DISTRO == "rocky" || $DISTRO == "alma" ]]; then
            $SUDO yum install -y git-all
            printf "    └ \033[32mV\033[0m Git installation completed.\n"
        else
            printf "    └ \033[31mX\033[0m Automatic installation of Git is not supported for '$DISTRO'.\n"
            printf "      \033[36m?\033[0m You have to install it manually.\n\n"
            printf "      Exiting...\n"
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
        if [[ -f "/etc/debian_version" ]]; then
            $SUDO apt update && sudo apt install -y curl
            printf "    └ \033[32mV\033[0m curl installation completed.\n"
        elif [[ -f "/etc/redhat-release" ]]; then
            $SUDO yum install -y curl
            printf "    └ \033[32mV\033[0m curl installation completed.\n"
        elif [[ -f "/etc/arch-release" ]]; then
            $SUDO pacman -Syu --noconfirm curl
            printf "    └ \033[32mV\033[0m curl installation completed.\n"
        elif [[ -f "/etc/alpine-release" ]]; then
            $SUDO apk add --no-cache curl
            printf "    └ \033[32mV\033[0m curl installation completed.\n"
        else
            printf "    └ \033[31mX\033[0m Automatic installation of curl is not supported.\n"
            printf "      \033[36m?\033[0m You have to install it manually.\n\n"
            printf "      Search for the installation instructions here :\n"
            printf "      \033[36mhttps://curl.se\033[0m.\n\n"
            printf "      Exiting...\n"
            exit 1
        fi
        printf "└ \033[32mV\033[0m curl installation completed.\n"
    fi
}

# Install and configure systemd-timesyncd, then set the system to UTC
configure_utc() {
    printf "\033[36m?\033[0m Checking if systemd-timesyncd is installed...\n"
    if command -v timedatectl &> /dev/null; then
        printf "  └ \033[32mV\033[0m systemd-timesyncd is already installed.\n"
    else
        printf "  └ \033[31mX\033[0m systemd-timesyncd is not installed. Installing...\n"
        if [[ -f "/etc/debian_version" ]]; then
            $SUDO apt update && apt install -y systemd-timesyncd
        elif [[ -f "/etc/redhat-release" ]]; then
            $SUDO yum install -y systemd-timesyncd
        elif [[ -f "/etc/arch-release" ]]; then
            $SUDO pacman -Sy --noconfirm systemd-timesyncd
        elif [[ -f "/etc/alpine-release" ]]; then
            $SUDO apk add --no-cache systemd-timesyncd
        else
            printf "    └ \033[31mX\033[0m Automatic installation of systemd-timesyncd is not supported.\n"
            printf "      \033[36m?\033[0m You have to install it manually.\n"
            printf "      Exiting...\n"
            exit 1
        fi
    fi
    printf "  └ \033[36m?\033[0m Configuring systemd-timesyncd...\n"
    if ! systemctl is-active --quiet systemd-timesyncd; then
        $SUDO systemctl start systemd-timesyncd
    fi
    if ! systemctl is-enabled --quiet systemd-timesyncd; then
        $SUDO systemctl enable --now systemd-timesyncd
    fi
    $SUDO timedatectl set-ntp true
    $SUDO timedatectl set-timezone UTC
    printf "    └ \033[32mV\033[0m systemd-timesyncd configured and set to UTC.\n"
}

# Remove old Docker packages
remove_old_docker() {
    printf "\033[36m?\033[0m Removing old Docker packages (if any)...\n"
    if [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
        for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
            $SUDO apt-get remove -y $pkg || true
        done
        printf "  └ \033[32mV\033[0m Old Docker packages removed.\n"
    elif [[ $DISTRO == "fedora" ]]; then
        $SUDO dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine || true
        printf "  └ \033[32mV\033[0m Old Docker packages removed.\n"
    elif [[ $DISTRO == "centos" || $DISTRO == "rhel" || $DISTRO == "rocky" || $DISTRO == "alma" ]]; then
        $SUDO yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine || true
        printf "  └ \033[32mV\033[0m Old Docker packages removed.\n"
    else
        printf "  └ \033[31mX\033[0m Package removal not supported for '$DISTRO'.\n"
        printf "    You have to remove them manually.\n\n"
        printf "    Exiting...\n"
        exit 1
    fi
}

# Check and install Docker
install_docker() {
    printf "\033[36m?\033[0m Checking if Docker is installed...\n"
    if command -v docker &> /dev/null; then
        printf "  └ \033[32mV\033[0m Docker is already installed.\n"
    else
        printf "  └ \033[31mX\033[0m Docker is not installed. Proceeding with the installation...\n"
        if [[ $DISTRO == "ubuntu" || $DISTRO == "debian" ]]; then
            # Add Docker's official GPG key:
            $SUDO apt-get update -y
            $SUDO apt-get install -y ca-certificates curl
            $SUDO install -m 0755 -d /etc/apt/keyrings
            $SUDO curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
            $SUDO chmod a+r /etc/apt/keyrings/docker.asc
            # Add the repository to Apt sources:
            if [[ $DISTRO == "debian" ]]; then
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            elif [[ $DISTRO == "ubuntu" ]]; then
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$UBUNTU_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            fi
            # Update repos and install
            $SUDO apt-get update -y
            $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            elif [[ $DISTRO == "fedora" ]]; then
                $SUDO dnf -y install dnf-plugins-core
                $SUDO dnf-3 config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
                $SUDO dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
                $SUDO systemctl enable --now docker
            elif [[ $DISTRO == "centos" || $DISTRO == "rhel" || $DISTRO == "rocky" || $DISTRO == "alma" ]]; then
                $SUDO yum install -y yum-utils
                $SUDO yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                $SUDO yum install -y docker-ce docker-ce-cli containerd.io
                $SUDO systemctl start docker
                $SUDO systemctl enable docker
            else
                printf "    └ \033[31mX\033[0m Unsupported Linux distribution: '$DISTRO'.\n"
                printf "      \033[36m?\033[0m You have to install Docker manually.\n\n"
                printf "      Search for the installation instructions here :\n"
                printf "      \033[36mhttps://docs.docker.com/engine/install/\033[0m.\n\n"
                printf "      Exiting...\n"
                exit 1
            fi
        printf "└ \033[32mV\033[0m Docker installation completed.\n"
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
            $SUDO apt-get update -y
            $SUDO apt-get install -y docker-compose-plugin
        elif [[ $DISTRO == "centos" || $DISTRO == "rhel" || $DISTRO == "fedora" || $DISTRO == "rocky" || $DISTRO == "alma" ]]; then
            $SUDO yum install -y docker-compose-plugin
        else
            printf "    └ \033[31mX\033[0m Automatic installation of Docker Compose plugin is not supported for '$DISTRO'.\n"
            printf "    \033[36m?\033[0m You have to install it manually.\n"
            printf "    Search for the installation instructions here :\n"
            printf "    \033[36mhttps://docs.docker.com/compose/\033[0m.\n\n"
            printf "    Exiting...\n"
            exit 1
        fi
        printf "└ \033[32mV\033[0m Docker Compose plugin installation completed.\n"
    fi
}

# Stop and delete previous CRCON containers and images
cleanup_crcon() {
    printf "\033[36m?\033[0m Checking for running CRCON containers and images...\n"

    # Check and remove containers
    CONTAINERS=$($SUDO docker ps -q --filter "ancestor=cericmathey/hll_rcon_tool_frontend" --filter "ancestor=cericmathey/hll_rcon_tool")
    NAMED_CONTAINERS=$($SUDO docker ps -q --filter "name=hll_rcon_tool-")
    ALL_CONTAINERS=$(echo -e "$CONTAINERS\n$NAMED_CONTAINERS" | sort -u)
    if [ -n "$ALL_CONTAINERS" ]; then
        printf "  └ \033[36m?\033[0m Stopping and removing running CRCON containers...\n"
        echo "$ALL_CONTAINERS" | xargs -r $SUDO docker rm -f
    else
        printf "  └ \033[32mV\033[0m No running CRCON containers found.\n"
    fi

    # Check and remove images
    IMAGES=("cericmathey/hll_rcon_tool_frontend" "cericmathey/hll_rcon_tool")
    IMAGES+=($($SUDO docker images --format "{{.Repository}}" | grep "hll_rcon_tool-"))
    for IMAGE in "${IMAGES[@]}"; do
        IMAGE_ID=$($SUDO docker images -q "$IMAGE")
        if [ -n "$IMAGE_ID" ]; then
            echo "$IMAGE_ID" | xargs -r $SUDO docker rmi -f
        fi
    done
}

# Check for previous installation and save its essential files
backup_previous_crcon() {
    printf "\033[36m?\033[0m Checking for previous CRCON installation...\n"
    if [[ -d "$HOME_DIR/hll_rcon_tool" ]]; then
        printf "  └ \033[31m!\033[0m Previous CRCON installation found in \033[33m$HOME_DIR/hll_rcon_tool\033[0m\n"

        # Create a backup folder with the current date
        BACKUP_FOLDER="$HOME_DIR/previous_crcon_installation_$(date '+%Y-%m-%d_%Hh%M')"
        if [[ -d "$BACKUP_FOLDER" ]]; then
            printf "    └ \033[31m!\033[0m Previous backup folder found.\n"
        else
            $SUDO mkdir $BACKUP_FOLDER
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
    # These will be automatically generated
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

clear
printf "┌─────────────────────────────────────────────────────────────────────────────┐\n"
printf "│ CRCON installer                                                             │\n"
printf "└─────────────────────────────────────────────────────────────────────────────┘\n\n"
printf "This script will install the latest CRCON on your Linux server.\n"
printf "CRCON is a web-based RCON tool for Hell Let Loose game servers.\n"
printf "It allows you to manage your game server, ban players, change maps, etc.\n"
printf "It also provides a public scoreboard website for your players.\n\n"
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

clear
printf "┌─────────────────────────────────────────────────────────────────────────────┐\n"
printf "│ CRCON installer - checking requirements                                     │\n"
printf "└─────────────────────────────────────────────────────────────────────────────┘\n"

# Check if the script is being run as root
if [[ "$(id -u)" -ne 0 ]]; then
    printf "\033[31mX\033[0m You are not running this script as root.\n"
    printf "└ All commands requiring elevated privileges will be executed with 'sudo'.\n"
    # Get the actual username
    USER_NAME=$(whoami)
    # Check if the user is in the sudoers file
    if sudo -l -U "$USER_NAME" 2>/dev/null | grep -q '(ALL) ALL'; then
        printf "  └ \033[32mV\033[0m User '$USER_NAME' has 'sudo' privileges.\n"
        SUDO="sudo"
    else
        printf "  └ \033[31mX\033[0m User '$USER_NAME' does NOT have 'sudo' privileges.\n"
        printf "    Please relog into you linux install with a user having them.\n"
        printf "\nSorry : we can't go further :/ Exiting...\n"
        exit 1
    fi
else
    printf "\033[32mV\033[0m You are running this script as root.\n"
    SUDO=""
fi

# --- Software requirements ---

printf "\n┌─────────────────────────────────────────────────────────────────────────────┐\n"
printf "│ CRCON installer - Check and install software requirements                   │\n"
printf "└─────────────────────────────────────────────────────────────────────────────┘\n"

# Detect Linux distro
if [[ -f "/etc/os-release" ]]; then
    DISTRO=$(grep ^ID= /etc/os-release | cut -d= -f2 | tr -d '"')
else
    printf "\033[31mX\033[0m Unable to detect the Linux distribution.\n"
    printf "\nSorry : we can't go further :/ Exiting...\n"
    exit 1
fi

ensure_home_directory
install_git
install_curl
configure_utc
remove_old_docker
install_docker
install_docker_compose_plugin
cleanup_crcon
backup_previous_crcon

# Deleting previous CRCON folder (if any)
if [[ -d "$HOME_DIR/hll_rcon_tool" ]]; then
    $SUDO rm -rf "$HOME_DIR/hll_rcon_tool"
fi

# --- Install CRCON ---

# Download CRCON
printf "\n┌─────────────────────────────────────────────────────────────────────────────┐\n"
printf "│ CRCON installer - Download CRCON                                            │\n"
printf "└─────────────────────────────────────────────────────────────────────────────┘\n"
$SUDO git clone https://github.com/MarechJ/hll_rcon_tool.git

# Enter CRCON folder
cd "$HOME_DIR"/hll_rcon_tool

# Fetch the files from the latest tag
# TODO : once worked... now it fails (remains on master)
$SUDO git fetch --tags
$SUDO git checkout $(git tag -l --contains HEAD | tail -n1)

printf "\n┌─────────────────────────────────────────────────────────────────────────────┐\n"
printf "│ CRCON installer - Set configuration files                                   │\n"
printf "└─────────────────────────────────────────────────────────────────────────────┘\n"

# Copy the default configuration files
$SUDO cp docker-templates/one-server.yaml compose.yaml
$SUDO cp default.env .env

# Prompt user for input and update the .env file
setup_env_variables

# Launching CRCON for the first time
printf "\n┌─────────────────────────────────────────────────────────────────────────────┐\n"
printf "│ CRCON installer - CSRF and Scoreboard configuration                         │\n"
printf "└─────────────────────────────────────────────────────────────────────────────┘\n"
$SUDO docker compose up -d --remove-orphans
# Add some sleep time to be sure the containers are fully initialised before accessing them
printf "Giving some time to the CRCON Docker containers to be fully started and running...\n"
sleep 15

# Fetch the WAN IP address from a web service
WAN_IP=$(curl -s https://ipinfo.io/ip)
if [[ -n "$WAN_IP" ]]; then
    PRIVATE_URL="http://$WAN_IP:8010/"
    PUBLIC_URL="http://$WAN_IP:7010/"

    # update CRCON settings "server_url"
    SQL="UPDATE public.user_config SET value = jsonb_set(value, '{server_url}', '\"$PRIVATE_URL\"', true) WHERE key = '1_RconServerSettingsUserConfig';"
    $SUDO docker compose exec -it postgres psql -U rcon -c "$SQL"

    # update Scoreboard "public_scoreboard_url"
    SQL="UPDATE public.user_config SET value = jsonb_set(value, '{public_scoreboard_url}', '\"$PUBLIC_URL\"', true) WHERE key = '1_ScoreboardUserConfig';"
    $SUDO docker compose exec -it postgres psql -U rcon -c "$SQL"

    # restart CRCON
    $SUDO docker compose down
    $SUDO docker compose up -d --remove-orphans
    # Add some sleep time to be sure the containers are fully initialised before accessing them
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

# Change "admin" password
printf "\n┌─────────────────────────────────────────────────────────────────────────────┐\n"
printf "│ CRCON installer - Change \"admin\" password                                   │\n"
printf "└─────────────────────────────────────────────────────────────────────────────┘\n"
$SUDO docker compose exec -it backend_1 python3 rconweb/manage.py changepassword admin

# Installation done
printf "\n┌─────────────────────────────────────────────────────────────────────────────┐\n"
printf "│ CRCON installer - Done !                                                    │\n"
printf "└─────────────────────────────────────────────────────────────────────────────┘\n\n"
printf "\033[32mCRCON is installed and running !\033[0m\n\n"
printf "Optional, but heavily recommended :\n"
printf "  To enforce security and allow to finetune each user's permissions,\n"
printf "  create new user(s) account(s) and delete (or disable) the default \"admin\" account.\n\n"
printf "  To do so, access the admin panel at \033[36mhttp://$WAN_IP:8010/admin\033[0m\n"
printf "  The default login name is '\033[90madmin\033[0m', the password is the one you've just set.\n\n"
printf "  You'll find a complete guide on how to manage users at \033[36mhttps://github.com/MarechJ/hll_rcon_tool/wiki/\033[0m\n\n"
printf "Once done, you can access CRCON at :\n"
printf "  private (game admin) interface : \033[36mhttp://$WAN_IP:8010/\033[0m\n"
printf "  public (stats) website : \033[36mhttp://$WAN_IP:7010/\033[0m\n\n"
printf "Happy gaming !\n\n"
