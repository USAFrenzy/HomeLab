
# Not Quite Organized yet

<br>

_________________________

### Packages Installed
_________________________
  - cloud-init
  - sudo

  <br>

_________________________

### Templates Created
_________________________

  - Debian 12
    - Sudo isn't installed by default on this template
    - Refer to this [FILE](./../Virtual_Machine_Templates/Debian_12/Debian_12_Template.md) for config settings used


<br>

_________________________

### VMs Created
_________________________
  - 4 Debian 12 cloud-init clones from Debian 12 template
    - One master node and 3 worker nodes for k8s cluster
    - sudo installed on each
    - external user given sudo privilege


<br>

_________________________

 ### Users Created:
_________________________
   - one external admin account
     - group: PamAdmins
     - TOTP enabled
     - Role: Administrator
     - system user
     - sudo privilege
     - runs as root


  <br>

_________________________

 ### Users Disabled From Password Login
_________________________
   - The ```root``` user
     - ```PermitRootLogin``` value changed from ```Yes``` to ```prohibit-password``` in ```sshd_config```
     - The root password was then deleted with ```sudo passwd -dl root```
     - The ```root``` user still exists in Proxmox and in the primary (only) node


<br>