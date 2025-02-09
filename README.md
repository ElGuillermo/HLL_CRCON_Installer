# HLL_CRCON_Installer
Installs an Hell Let Loose (HLL) CRCON (see : https://github.com/MarechJ/hll_rcon_tool) on a fresh Linux system.

## Features
- Check for requirements (Git, Docker, Docker compose plugin) and installs them if needed
- Download the latest CRCON release
- Configure the first game server to be managed (`.env`, `compose.yaml`, CSRF verification and Scorebot urls)

Tested on :  
- [Debian](https://www.debian.org/) 12.9.0
- [Ubuntu server](https://ubuntu.com/server) 24.04.1
- [Fedora](https://fedoraproject.org/) server 41-1.4

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

Please report [here](https://discord.com/channels/685692524442026020/1337758742447652895) if you encounter any issue.
