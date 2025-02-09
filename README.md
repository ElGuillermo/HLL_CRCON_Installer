# HLL_CRCON_Installer
Installs an Hell Let Loose (HLL) CRCON (see : https://github.com/MarechJ/hll_rcon_tool) on a fresh Linux system.

## Features
- Check for requirements (Git, Docker, Docker compose plugin) and installs them if needed
- Download the latest CRCON release
- Configure the first game server to be managed (`.env`, `compose.yaml`, CSRF verification and Scorebot urls)

Tested on a [Debian](https://www.debian.org/) 12.9.0 and [Ubuntu server](https://ubuntu.com/server) 24.04.1

## Install

- Log into an SSH session on your Linux VPS  
  :warning: Your user must have superuser permissions ("root") or member of the "sudo" group.  
- Make sure you're in your user's default home folder :  
  ```shell
  cd
  ```  
- Download the script :  
  ```shell
  wget https://raw.githubusercontent.com/ElGuillermo/HLL_CRCON_Installer/refs/heads/main/install_crcon.sh
  ```  
- Make it executable :
  ```shell
  chmod +x install_crcon.sh
  ```
- Launch it :
  ```shell
  ./install_crcon.sh
  ```
- Follow instructions

Please report [here](https://discord.com/channels/685692524442026020/1337758742447652895) if you encounter any issue.
