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

# ┌───────────────────────────────────────────────────────────────────────────┐

# Function to check and change to the home directory
ensure_home_directory() {
    CURRENT_DIR=$(pwd)
    HOME_DIR=$(eval echo "~$USER")

    if [[ ! "$CURRENT_DIR" == "$HOME_DIR" ]]; then
        printf "\033[31mX\033[0m The current directory (\033[33m$CURRENT_DIR\033[0m) is not the user's home directory (\033[33m$HOME_DIR\033[0m).\n"
        printf "└ Changing to the home directory...\n"
        cd "$HOME_DIR"
        printf "└ \033[32mV\033[0m Now in the home directory: $(pwd)\n"
    else
        printf "\033[32mV\033[0m Already in the user's home directory: \033[33m$CURRENT_DIR\033[0m\n"
    fi
}

# Function to check and install Git
install_git() {
    printf "\033[34m?\033[0m Checking if Git is installed...\n"
    if command -v git &> /dev/null; then
        printf "└ \033[32mV\033[0m Git is already installed.\n"
    else
        printf "└ \033[31mX\033[0m Git is not installed. Proceeding with the installation...\n"
        if [[ $DISTRO == "ubuntu" || $DISTRO == "debian" ]]; then
            $SUDO apt-get update -y
            $SUDO apt-get install -y git-all
        elif [[ $DISTRO == "centos" || $DISTRO == "rhel" || $DISTRO == "fedora" || $DISTRO == "rocky" || $DISTRO == "alma" ]]; then
            $SUDO yum install -y git-all
        else
            printf "└ \033[31mX\033[0m Automatic installation of Git is not supported for '$DISTRO'.\n"
            printf "  └ \033[34m?\033[0m You have to install it manually.\n"
            exit 1
        fi
        printf "└ \033[32mV\033[0m Git installation completed.\n"
    fi
}

# Function to remove old Docker packages
remove_old_docker() {
    printf "\033[34m?\033[0m Removing old Docker packages (if any)...\n"
    if [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
        for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
            $SUDO apt-get remove -y $pkg || true
        done
        printf "└ \033[32mV\033[0m Old Docker packages removed.\n"
    elif [[ $DISTRO == "fedora" ]]; then
        $SUDO dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine || true
        printf "└ \033[32mV\033[0m Old Docker packages removed.\n"
    elif [[ $DISTRO == "centos" || $DISTRO == "rhel" || $DISTRO == "rocky" || $DISTRO == "alma" ]]; then
        $SUDO yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine || true
        printf "└ \033[32mV\033[0m Old Docker packages removed.\n"
    else
        printf "└ \033[31mX\033[0m Package removal not supported for '$DISTRO'.\n"
    fi
}

# Function to check and install Docker
install_docker() {
    printf "\033[34m?\033[0m Checking if Docker is installed...\n"
    if command -v docker &> /dev/null; then
        printf "└ \033[32mV\033[0m Docker is already installed.\n"
    else
        printf "└ \033[31mX\033[0m Docker is not installed. Proceeding with the installation...\n"
        if [[ $DISTRO == "ubuntu" || $DISTRO == "debian" ]]; then
            # Add Docker's official GPG key:
            $SUDO apt-get update
            $SUDO apt-get install ca-certificates curl
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
            $SUDO apt-get update
            $SUDO apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
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
            printf "└ \033[31mX\033[0m Unsupported Linux distribution: '$DISTRO'.\n"
            printf "  └ \033[34m?\033[0m You have to install Docker manually.\n"
            exit 1
        fi
        printf "└ \033[32mV\033[0m Docker installation completed.\n"
    fi
}

# Function to check and install Docker Compose plugin
install_docker_compose_plugin() {
    printf "\033[34m?\033[0m Checking if Docker Compose plugin is installed...\n"
    if docker compose version &> /dev/null; then
        printf "└ \033[32mV\033[0m Docker Compose plugin is already installed.\n"
    else
        printf "└ \033[31mX\033[0m Docker Compose plugin is not installed. Proceeding with the installation...\n"
        if [[ $DISTRO == "ubuntu" || $DISTRO == "debian" ]]; then
            $SUDO apt-get update -y
            $SUDO apt-get install -y docker-compose-plugin
        elif [[ $DISTRO == "centos" || $DISTRO == "rhel" || $DISTRO == "fedora" || $DISTRO == "rocky" || $DISTRO == "alma" ]]; then
            $SUDO yum install -y docker-compose-plugin
        else
            printf "└ \033[31mX\033[0m Automatic installation of Docker Compose plugin is not supported for '$DISTRO'.\n"
            printf "  └ \033[34m?\033[0m You have to install it manually.\n"
            exit 1
        fi
        printf "└ \033[32mV\033[0m Docker Compose plugin installation completed.\n"
    fi
}

# Function to validate user input to ensure it contains only letters and numbers
validate_input() {
    local input="$1"
    if [[ ! "$input" =~ ^[A-Za-z0-9]+$ ]]; then
        printf "\033[31mX\033[0m Error: $input contains invalid characters. Only letters (a-z) and numbers (0-9), without any space, are allowed.\n"
        return 1
    fi
    return 0
}

# Function to validate user input to ensure it is a valid IPv4 address
validate_input_ip() {
    local input="$1"
    if [[ ! "$input" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        printf "\033[31mX\033[0m Error: $input isn't a valid IPv4 address.\n"
        return 1
    fi
    return 0
}

# Function to validate user input to ensure it contains only numbers in 0-65535 range
validate_input_port() {
    local input="$1"
    if [[ ! "$input" =~ ^[0-9]+$ ]] || (( input < 0 || input > 65535 )); then
        printf "\033[31mX\033[0m Error: $input isn't a valid port number (0-65535).\n"
        return 1
    fi
    return 0
}

# Function to prompt for user input and replace in the .env file
setup_env_variables() {
    while true; do
        echo "________________________________________________________________________________"
        printf "\033[35mDefine your own HLL_DB_PASSWORD\033[0m\n"
        printf "\033[90mHLL_DB_PASSWORD is a string that will be used as database access password.\033[0m\n"
        printf "\033[90mInvent your own using only regular letters and numbers, without any space in it.\033[0m\n"
        read -p "Enter HLL_DB_PASSWORD: " HLL_DB_PASSWORD
        if validate_input "$HLL_DB_PASSWORD"; then
            break
        fi
    done

    while true; do
        echo "________________________________________________________________________________"
        printf "\033[35mDefine your own RCONWEB_API_SECRET\033[0m\n"
        printf "\033[90mRCONWEB_API_SECRET is a string that will be used to scramble users' passwords.\033[0m\n"
        printf "\033[90mInvent your own using only regular letters and numbers, without any space in it.\033[0m\n"
        read -p "Enter RCONWEB_API_SECRET: " RCONWEB_API_SECRET
        if validate_input "$RCONWEB_API_SECRET"; then
            break
        fi
    done

    while true; do
        echo "________________________________________________________________________________"
        printf "\033[35mEnter your game server's RCON IP\033[0m\n"
        printf "\033[90mHLL_HOST is the RCON IP address, as provided by your game server provider.\033[0m\n"
        printf "\033[90mExample: 123.123.123.123\033[0m\n"
        read -p "Enter HLL_HOST: " HLL_HOST
        if validate_input_ip "$HLL_HOST"; then
            break
        fi
    done

    while true; do
        echo "________________________________________________________________________________"
        printf "\033[35mEnter your game server's RCON port\033[0m\n"
        printf "\033[90mHLL_PORT is the RCON port, as provided by your game server provider.\033[0m\n"
        printf "\033[90mIt is NOT the same as the game server (query) or SFTP ports\033[0m\n"
        printf "\033[90mExample: 12345\033[0m\n"
        read -p "Enter HLL_PORT: " HLL_PORT
        if validate_input_port "$HLL_PORT"; then
            break
        fi
    done

    echo "________________________________________________________________________________"
    printf "\033[35mEnter your game server's RCON password\033[0m\n"
    printf "\033[90mHLL_PASSWORD is the RCON password, as provided by your game server provider.\033[0m\n"
    read -p "Enter HLL_PASSWORD: " HLL_PASSWORD

    # Replacing the values in the .env file
    $SUDO sed -i "s/^HLL_DB_PASSWORD=.*/HLL_DB_PASSWORD=$HLL_DB_PASSWORD/" "$HOME_DIR"/hll_rcon_tool/.env
    $SUDO sed -i "s/^RCONWEB_API_SECRET=.*/RCONWEB_API_SECRET=$RCONWEB_API_SECRET/" "$HOME_DIR"/hll_rcon_tool/.env
    $SUDO sed -i "s/^HLL_HOST=.*/HLL_HOST=$HLL_HOST/" "$HOME_DIR"/hll_rcon_tool/.env
    $SUDO sed -i "s/^HLL_PORT=.*/HLL_PORT=$HLL_PORT/" "$HOME_DIR"/hll_rcon_tool/.env
    $SUDO sed -i "s/^HLL_PASSWORD=.*/HLL_PASSWORD=$HLL_PASSWORD/" "$HOME_DIR"/hll_rcon_tool/.env
}

# Function to install curl
install_curl() {
  printf "\033[31mX\033[0m curl is not installed. Attempting to install it...\n"
  if [[ -f "/etc/debian_version" ]]; then
    $SUDO apt update && sudo apt install -y curl
  elif [[ -f "/etc/redhat-release" ]]; then
    $SUDO yum install -y curl
  elif [[ -f "/etc/arch-release" ]]; then
    $SUDO pacman -Syu --noconfirm curl
  elif [[ -f "/etc/alpine-release" ]]; then
    $SUDO apk add --no-cache curl
  else
    printf "\033[31mX\033[0m Unsupported Linux distribution. Please install curl manually.\n"
    exit 1
  fi
}

# └───────────────────────────────────────────────────────────────────────────┘

# Exit immediately if a command exits with a non-zero status.
set -e

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

clear
printf "┌─────────────────────────────────────────────────────────────────────────────┐\n"
printf "│ CRCON installer - checking requirements                                     │\n"
printf "└─────────────────────────────────────────────────────────────────────────────┘\n"

# Main script execution
if [[ -f "/etc/os-release" ]]; then
    DISTRO=$(grep ^ID= /etc/os-release | cut -d= -f2 | tr -d '"')
else
    printf "\033[31mX\033[0m Unable to detect the Linux distribution.\n"
    printf "\nSorry : we can't go further :/ Exiting...\n"
    exit 1
fi

# Check if curl is installed
if ! command -v curl &> /dev/null; then
  install_curl
  if ! command -v curl &> /dev/null; then
    printf "\033[31mX\033[0m Failed to install curl from the default repositories.\n"
    printf "Please install it manually and try again.\n"
    printf "Search for the installation instructions here : \033[36mhttps://curl.se\033[0m.\n"
    printf "\nSorry : we can't go further :/ Exiting...\n"
    exit 1
  fi
fi

# Run the installation steps
ensure_home_directory
install_git
remove_old_docker
install_docker
install_docker_compose_plugin

# Download CRCON
printf "\n┌─────────────────────────────────────────────────────────────────────────────┐\n"
printf "│ CRCON installer - Download CRCON                                            │\n"
printf "└─────────────────────────────────────────────────────────────────────────────┘\n"
$SUDO git clone https://github.com/MarechJ/hll_rcon_tool.git

# Enter CRCON folder
cd "$HOME_DIR"/hll_rcon_tool

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
printf "│ CRCON installer - CSRF configuration                                        │\n"
printf "└─────────────────────────────────────────────────────────────────────────────┘\n"
$SUDO docker compose up -d --remove-orphans

# Fetch the WAN IP address from a web service
WAN_IP=$(curl -s https://ipinfo.io/ip)
if [[ -n "$WAN_IP" ]]; then
  PRIVATE_URL="http://$WAN_IP:8010/"
  PUBLIC_URL="http://$WAN_IP:7010/"

  # update CRCON settings "server_url"
  SQL="UPDATE public.user_config SET value = jsonb_set(value, '{server_url}', '\"$PRIVATE_URL\"', true) WHERE key = '1_RconServerSettingsUserConfig';"
  $SUDO docker compose exec -it postgres psql -U rcon -c "$SQL"

  # update Scorebot "base_api_url"
  # SQL="UPDATE public.user_config SET value = jsonb_set(value, '{base_api_url}', '\"$PRIVATE_URL\"', true) WHERE key = '1_ScorebotUserConfig';"
  # $SUDO docker compose exec -it postgres psql -U rcon -c "$SQL"

  # update Scorebot "base_scoreboard_url"
  # SQL="UPDATE public.user_config SET value = jsonb_set(value, '{base_scoreboard_url}', '\"$PUBLIC_URL\"', true) WHERE key = '1_ScorebotUserConfig';"
  # $SUDO docker compose exec -it postgres psql -U rcon -c "$SQL"

  # update ScoreBoard "public_scoreboard_url"
  SQL="UPDATE public.user_config SET value = jsonb_set(value, '{public_scoreboard_url}', '\"$PUBLIC_URL\"', true) WHERE key = '1_ScoreboardUserConfig';"
  $SUDO docker compose exec -it postgres psql -U rcon -c "$SQL"

  # restart CRCON
  $SUDO docker compose down
  $SUDO docker compose up -d --remove-orphans
else
  printf "\033[31mX\033[0m Failed to retrieve the WAN IP address.\n"
  printf "  └ \033[34m?\033[0m You'll have to manually set your CRCON url in CRCON settings\n"
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

# Launching CRCON for the first time
printf "\n┌─────────────────────────────────────────────────────────────────────────────┐\n"
printf "│ CRCON installer - Done !                                                    │\n"
printf "└─────────────────────────────────────────────────────────────────────────────┘\n\n"
printf "\033[32mCRCON is installed and running !\033[0m\n\n"
printf "Optional, but heavily recommended :\n"
printf "  To enforce security and allow to finetune each user's permissions,\n"
printf "  create new user(s) account(s) and delete (or disable) the default \"admin\" account.\n\n"
printf "  To do so, access the admin panel at \033[36mhttp://$WAN_IP:8010/admin\033[0m\n"
printf "  You'll find a complete guide on how to manage users at \033[36mhttps://github.com/MarechJ/hll_rcon_tool/wiki/\033[0m\n\n"
# printf "The default login name is '\033[90madmin\033[0m' and the password is '\033[90madmin\033[0m'\n\n"
printf "Once done, you can access CRCON at :\n"
printf "  private interface : \033[36mhttp://$WAN_IP:8010/\033[0m\n"
printf "  public (stats) website : \033[36mhttp://$WAN_IP:7010/\033[0m\n\n"
printf "Happy gaming !\n\n"
