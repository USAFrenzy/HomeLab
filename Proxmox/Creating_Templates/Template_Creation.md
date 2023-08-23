_____________________________
# Creating VM Templates In Proxmox
- Reference: [Proxmox VE Full Course: Class 6 - Creating Virtual Machine Templates](https://www.youtube.com/watch?v=t3Yv4OOYcLs&ab_channel=LearnLinuxTV)

<br><br>

_____________________________
## Prerequisites
_____________________________

<br>

#### NOTES:
- This Following Guide Is Not Done On The Proxmox Host, Only In The VM That Will Be Used As A Template For Other VMs
- If Root, Omit Sudo From The Below Commands

<br>

This first step isn't a hard requirement, but to make life simpler for VM deployments using templates, make sure the ```cloud-init``` package is installed by running "```apt search cloud-init```"
  - If ```cloud-init``` isn't installed yet, run "```sudo apt install cloud-init```" to install it now

Now we need to remove the ssh host keys so that the template doesn't copy them over to each clone made from the template (avoiding client connection confusion)
- Move on over to the ```ssh``` directory by running "```cd /etc/ssh```"
- Remove the host ssh files by running "```sudo rm ssh_host_*```"
  - This step forces ```cloud-init``` to regenerate these key files when cloning the template

After removing the ssh host key files, we also need to ensure the ```machine id``` is unique per VM instance
- We do this by truncating the ```machine-id``` file by running "```sudo truncate -s 0 /etc/machine-id```"
  - To check the file is now empty, run "```cat /etc/machine-id```"
- Now to check that the symbolic link to the ```machine-id``` file exists where it should, run "```ls -l /var/lib/dbus/machine-id```"
  - If a symbolic link doesn't exist yet, we need to create a symbolic link to the ```machine-id``` file by running "```sudo ln -s /etc/machine-id /var/lib/dbus/machine-id```"
    - If a file exists here, delete it before creating the symbolic link
-
_____________________________

<br><br>

_____________________________
## Template Creation
_____________________________
-
-
_____________________________
