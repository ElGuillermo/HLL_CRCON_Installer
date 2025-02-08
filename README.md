# HLL_CRCON_Installer
Installs an Hell Let Loose (HLL) CRCON (see : https://github.com/MarechJ/hll_rcon_tool)

## Features
- Check for requirements (Git, Docker, Docker compose plugin) and installs them if needed
- Download the latest CRCON release
- Configure the first game server to be managed (`.env`, `compose.yaml`, CSRF verification and Scorebot urls)

Tested on a Debian 12.

## Install

- Log into an SSH session on your Linux VPS  
- Make sure you're in "root" default home :  
  ```shell
  cd /root
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

Please report if you encounter any issue.
