# HLL_CRCON_Installer
Installs an Hell Let Loose (HLL) CRCON (see : https://github.com/MarechJ/hll_rcon_tool) on a fresh Linux system.

This script will install any missing [required software](https://github.com/MarechJ/hll_rcon_tool/wiki/Getting-Started-%E2%80%90-Requirements#software-requirements).

It will then install and configure CRCON, as described in the [installation procedure](https://github.com/MarechJ/hll_rcon_tool/wiki/Getting-Started-%E2%80%90-Installation).

> [!CAUTION]
> This script should NOT be used on a host that is already running user programs or scripts,  
> as some system-wide software (git, curl, Docker, Docker compose plugin)  
> and settings (realtime clock timezone set on UTC) will be updated or set.
>
> **Only use it on a freshly installed Linux distro.**

Tested on :  
- [Debian](https://www.debian.org/) 12.9.0
- [Ubuntu server](https://ubuntu.com/server) 24.04.1
- [Fedora server](https://fedoraproject.org/server/) 41-1.4

## Features
- Check for requirements and install them if needed
  - git
  - curl
  - datetimectl
  - Docker
  - Docker 'compose' plugin
- Will **try** to backup any config files and database from a previous CRCON install before deleting it
- Download and install the latest CRCON release  
- Configure the first game server to be managed :  
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
7. (optional) Create new users
   - Follow regular [installation procedure from step 6.3](https://github.com/MarechJ/hll_rcon_tool/wiki/Getting-Started-%E2%80%90-Installation#3-create-you-own-users).

## Troubleshooting and reviews

- Please report [here](https://discord.com/channels/685692524442026020/1337758742447652895) if you encounter any issue.  
- Success stories are also welcomed ! ;)
