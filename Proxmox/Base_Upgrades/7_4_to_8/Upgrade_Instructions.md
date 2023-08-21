# Given That This Method Is Only Used To Avoid Issues With Direct Installation Of PVE 8.0 On New Hardware With An Nvidia GPU, No Prior Backups Are Needed Before Upgrading.

## NOTE: This Process uses an install-then-upgrade approach of a fresh install of Proxmox 7.4 found [HERE](https://www.proxmox.com/en/downloads/proxmox-virtual-environment/iso/proxmox-ve-7-4-iso-installer)

<br><br>

-------------------------

### Steps For Upgrade Process
----------------------------------

- Ensure there is more than 5GB of free space on the root partition of Proxmox host machine by running "```df -h```" and checking the "```/dev/mapper/pve-root```" field
- Given that this process uses a direct install of [Proxmox 7.4 .iso](https://enterprise.proxmox.com/iso/proxmox-ve_7.4-1.iso), we need to upgrade this install to the most current 7.4.x release.
  - [tteck](https://tteck.github.io/Proxmox/)'s scripts are a lifesaver here and make things very streamlined:
  - In Proxmox's web gui shell, run "```bash -c "$(wget -qLO - https://github.com/tteck/Proxmox/raw/main/misc/post-pve-install.sh)"```"
    - Answer "```y```" to the prompts and reboot when prompted.
- After the reboot:
  - Log back in and verify under node summary that the version now states "```7.4-16```"
  - Run "```pve7to8 --full```" in the web gui shell
    - Correct any warnings before proceeding
- Using ttek's script again, run "```bash -c "$(wget -qLO - https://github.com/tteck/Proxmox/raw/main/misc/pve8-upgrade.sh)"```"
  - Keysmash enter and reboot when prompted
- Log back in and verify that the node summary now states version "```8.0.x```" where "```x```" is whatever is the current minor release version.
- Mostly unneccessary for this use case of this install-then-upgrade approach, but afterwards, a clean-up script can be run to check for any orphaned kernel images and remove them:
  - Run "```bash -c "$(wget -qLO - https://github.com/tteck/Proxmox/raw/main/misc/kernel-clean.sh)"```"

--------------------------