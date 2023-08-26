_____________________________
# Creating VM Templates In Proxmox
- References:
  - [Proxmox VE Full Course: Class 6 - Creating Virtual Machine Templates](https://www.youtube.com/watch?v=t3Yv4OOYcLs&ab_channel=LearnLinuxTV)
  - [Creating a VM Template in Proxmox](https://tcude.net/creating-a-vm-template-in-proxmox)
  - [How to create a Proxmox VM template](https://4sysops.com/archives/how-to-create-a-proxmox-vm-template)

<br>
<br>

_____________________________

#### NOTES:
- This Following Guide Is Not Done On The Proxmox Host, Only In The VM That Will Be Used As A Template For Other VMs
- This Guide Is An Amalgamation Of The References Cited Above When Researching This Topic
- This Process Is Mostly For Linux-Based VMs
- If Root, Omit Sudo From The Below Commands

_____________________________

<br><br>

_____________________________
## Part 1 - Virtual Machine Base For Template ##

### To create a template, we first need to create a base VM -> the steps to configure it as the foundation of the template will follow suite afterwards. <br> To get started, right click on the node that will be used to launch this initial VM and select ```Create VM``` or, alternatively, click the same button located <br> in the top right of the web gui. ###
#### 1) Under the ```General``` tab, fill out: ####
   -  The node the VM will be on
   -  The name of the VM (This will also be the name of the template)
   -  The VM ID fields under the ```General``` tab
     - It's usually best to give the VMs that will become templates a higher VM ID to separate them in the node list

#### 2) Under the ```OS``` tab: ####
   - Select "```Do not use any media```"; the main difference in creating a template and a regular VM comes from this step.
     - The reason for this is because we will be configuring ```cloud-init``` to be the initial boot loader later
   - The rest of the settings can be left as-is or changed according to preference.
     - If using a non-Linux OS, then the ```Type``` and ```Version``` fields will need to be changed as well

#### 3) Under the ```System``` tab: ####
  - Enable the "```Qemu Agent```" which allows for more functionality between the host (Proxmox) and the VM
  - Best practices seem to dictate that the rest of the fields on this tab should remain as their defaults
    - Doing this would allow for greater compatibility between nodes and/or systems if VM migrations are needed in the future

#### 4) Under the ```Disks``` tab: ####
   - Delete the default "```scsi0```" disk as this disk will be created later on via the ```cloud-init``` process

#### 5) Under the ```CPU``` tab, fill out: ####
   - The number of ```sockets``` (typically left at ```one```)
   - The ```cores``` value (NOTE: This is really how many threads to allocate to the VM)
     - I.e. 4 cores is really just 4 threads
   - The CPU ```Type``` (For the same reasons listed in step 3 for the ```Systems``` tab, this will typically be the default value)

#### 6) Under the ```Memory``` tab: ####
   - Simply fill in a value that you would like VMs made from this template to start off with
     - Click ```Advanced``` and make sure "```Ballooning Device```" is enabled
       - This allows Proxmox to dynamically allocate ram up to the value specified previously, allowing Proxmox to utilize the ram not currently in use for other processes

#### 7) Under the ```Network``` tab: ####
   - Specify the ```Bridge``` to use (This can be left at the default bridge "```vmbr0```" or can be set to any other bridge created)
   - Recommended selection of "```VirtIO(paravirtualized)```" in ```Model``` as this gives the best performance
   - ```VLAN Tag``` can remain empty, unless there is a need to specify this field due to network topography
   - Leave ```MAC address``` set to "```auto```"
   - Enable/Disable ```Firewall``` if desired

#### 8) After reviewing all the settings made, click ```Finish``` to create the new VM ####

<br>

_____________________________

## Part 2 - Post Virtual Machine Creation Steps ##

#### 1) This Step Requires Pulling A Cloud-Image For The VM ####
- This Can Be Any OS That Supports Cloud Instantiations.
  - For Example:
    - For Debian,  you would pull the image from one of the ones listed on ```https://cloud.debian.org/images/cloud/```
    - For Ubuntu, you would pull the image from one of the ones listed on ```https://cloud-images.ubuntu.com/releases/```
- Once a cloud image has been located, go to the Proxmox shell and run "```wget <distro_image> -O /tmp/<chosen_name.img>```"
  - To import the image into the lvm-datastore, run "```qm importdisk <template_vm_id> /tmp/<chosen_name.img> lvm-datastore```"
  - To view the imported image, run "```pvesm list lvm-datastore```"
    - If using local or NFS storage, the image should be imported in ```qcow2``` format
      - The new extension is needed for this to work specifically with live snapshots
      - To do this, run "```qm importdisk <template_vm_id> /tmp/<chosen_name.img> local --format qcow2```"

#### 2) Adding The Disk For The VM To Use ####
- Navigate back to the ```Hardware``` tab and where the new disk is, select it and click edit to add the ```CloudInit Drive``` created from step 1 to the VM
- This step is optional, but for best performance when already being stored and run on an actual SSD, check ```SSD emulation``` under the ```Advanced``` settings
- Check ```Discard``` to enable thin-provisioning and allow Proxmox to reclaim storage space if the VM is deleted or shutdown


#### 3) Adding Serial Port And Cloud-Init Drive
- While still at the ```Hardware``` tab, select ```Add``` and add a ```Serial Port``` and ```CloudInit Drive```
- The serial port is added to the virtual machine for display output as, without it, there may only be a black screen visible
  - After adding the serial port, double click the ```Display``` field and set ```Serial terminal 0``` as the graphics card
    - This will allow Proxmox to have access to the VM's console and allow us to interact with the virtual machine
- Navigate over to the ```Cloud-Init``` tab and configure the settings available here
  - Select the storage pool to use to store this drive
  -  Under this tab, settings that will be used for each VM on creation can be applied.
     - This includes:
       - Username
       - Password
       - SSH Keys (public key)
       - DNS servers and DNS Domain
       - Network Configuration
         - A preferred way may be to set this to DHCP initially and then set this to static afterwards if needed
  - After Settings have been configured for ```Cloud-Init``` , Click ```Regenerate Image```
#### 4) Enabling the newly created drive and changing the boot order ####
- Navigate over to the ```Options``` tab
  - Select ```Boot Order``` and move the "```scsi0```" disk towards the top and check the ```Enabled``` box
  - Enable ```Start at boot``` to automatically start when Proxmox is booted up

<br>

_____________________________

### Note: Steps 5 through 9 are done on the VM while the VM is running ###
_____________________________


#### 5) Power on the VM ####
#### 6) Enabling qemu-guest-agent ####
- If, for whatever reason, ```qemu-guest-agent``` wasn't installed previously when creating the Virtual Machine in step 3 of part 1:
  - Install the qemu-guest-agent by running "```sudo apt update && sudo apt upgrade -y && sudo apt install qemu-guest-agent```"
  - Enable the agent by running "```sudo systemctl enable qemu-guest-agent```"

#### 7) Cleaning up ssh host keys ####
Now we need to remove the ssh host keys so that the template doesn't copy them over to each clone made from the template (avoiding client connection confusion)
- Move on over to the ```ssh``` directory by running "```cd /etc/ssh```"
- Remove the host ssh files by running "```sudo rm ssh_host_*```"
  - This step forces ```cloud-init``` to regenerate these key files when cloning the template

#### 8) Clearing the machine-id file ####
After removing the ssh host key files, we also need to ensure the ```machine id``` is unique per VM instance
- We do this by truncating the ```machine-id``` file by running "```sudo truncate -s 0 /etc/machine-id```"
  - To check the file is now empty, run "```cat /etc/machine-id```"
- Now to check that the symbolic link to the ```machine-id``` file exists where it should, run "```ls -l /var/lib/dbus/machine-id```"
  - If a symbolic link doesn't exist yet, we need to create a symbolic link to the ```machine-id``` file by running "```sudo ln -s /etc/machine-id /var/lib/dbus/machine-id```"
    - If a file exists here, delete it before creating the symbolic link

#### 9) Last Remaining Steps Before Conversion To Template ####
- Run "```sudo apt clean```" to clean up any package caches leftover
- Run "```sudo apt autoremove```" to clean up any possible leftover package remnants
- If ```cloud-init``` isn't installed yet, run "```sudo apt install cloud-init```" to install it now
  - Finally, run "```cloud-init clean```"

#### 10) Shut down the VM ####

#### 11) Convert the VM to a template by right-clicking the VM and selecting "```Convert to template```"


#### 12) Optional Steps After The Template Has Been Made ####
- When cloning the template into a VM, prefer to use ```full clone``` as this copies the entire template and not a differential copy
- When firing up VMs made from this template, they will have the same name due to what was set in the template
  - To ammend this, run "```sudo nano \etc\hostname```" and rename the default name to whatever is desired
  - Then run "```sudo nano \etc\hosts```" and rename the default name used to whatever was used in the previous step
  - Then reboot the VM
_____________________________
