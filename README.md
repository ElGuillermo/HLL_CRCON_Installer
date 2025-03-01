# HLL_CRCON_Installer
Installs the latest Hell Let Loose (HLL) [CRCON](https://github.com/MarechJ/hll_rcon_tool) on a Linux host.

> [!CAUTION]
> This script must be run with caution on a host that is already running user programs or scripts,  
> as some system-wide software (git, curl, Docker, Docker compose plugin)  
> and settings (realtime clock timezone set on UTC) will be updated or set.
>
> -> You should only use it on a freshly installed Linux distro.

> [!WARNING]
> Running the script on a machine where a previous CRCON is installed will DELETE it.  
> It will try to backup your existing `.env`, `compose.yaml` and database before,  
> but that could fail, mostly if you have changed the default install paths.  
>   
> -> Please make sure to backup any data you find valuable before proceeding.

Tested on :  
- [Debian](https://www.debian.org/) 12.9.0
- [Ubuntu server](https://ubuntu.com/server) 24.04.1
- [Fedora server](https://fedoraproject.org/server/) 41-1.4

## Features

This script will :  
- install any missing [required software](https://github.com/MarechJ/hll_rcon_tool/wiki/Getting-Started-%E2%80%90-Requirements#software-requirements)
  - git
  - curl
  - datetimectl
  - replace obsoleted Docker and `docker-compose` with latest stable versions
- backup (if found) a previous CRCON database, `.env` and `compose.yaml` files
- purge anything related to a previous CRCON install (Docker images and containers, `hll_rcon_tool` folder)
- install the latest available CRCON stable version
- configure the first game server to be managed
  - RCON credentials in `.env`  
  - one game server `compose.yaml`
  - CSRF verification url
  - Scoreboard public stats url
- Ask the user to define a new "admin" password

## Install

1. Log into an SSH session on your Linux VPS  
  :warning: Your user must have superuser permissions ("root") or `sudo` command access.  
2. Make sure you're in your user's default home folder :  
    ```shell
    cd
    ```  
3. Download the script :  
    ```shell
    wget https://raw.githubusercontent.com/ElGuillermo/HLL_CRCON_Installer/refs/heads/main/install_crcon.sh
    ```  
4. Make it executable :
    ```shell
    chmod +x install_crcon.sh
    ```
5. Launch it :
    ```shell
    ./install_crcon.sh
    ```
6. Follow instructions  
   You'll need to have some informations handy.  
   These are provided by your game server provider (Qonzer, GTX, GPortal, etc)  
   - HLL game server RCON IP
   - HLL game server RCON port
   - HLL game server RCON password
7. Create new users (optional but heavily recommended)
   - Follow regular [installation procedure from step 6.3](https://github.com/MarechJ/hll_rcon_tool/wiki/Getting-Started-%E2%80%90-Installation#3-create-you-own-users).

## Troubleshooting and reviews

- Please report [here](https://discord.com/channels/685692524442026020/1337758742447652895) if you encounter any issue.  
- Success stories are also welcomed ! ;)
