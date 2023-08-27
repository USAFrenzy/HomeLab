# This File Simply Outlines The Configuration Used For, As Well As The Setup For, The Debian 12 Template In Use.

<br>

____________________
## Configuration ##

### Note: Backup, Replication, Firewall, and Permissions settings have been left at their defaults thus far

### Base Settings ###
|            	|                                                                                     	|
|------------	|-------------------------------------------------------------------------------------	|
| Image Used 	| https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2 	|
| Name       	| Debian-12-Base                                                                      	|
| VM ID      	| 100                                                                                 	|

### Hardware ###

|                       	|                             	|                  	    |                   	|             	|              	|
|-----------------------	|-----------------------------	|------------------	    |-------------------	|-------------	|--------------	|
| Processors            	| 4 cores                     	|                  	    |                   	|             	|              	|
| Bios                  	| Default (SeaBios)           	|                  	    |                   	|             	|              	|
| Display               	| Serial terminal 0 (serial0) 	|                  	    |                   	|             	|              	|
| Machine               	| Default (i440fx)            	|                  	    |                   	|             	|              	|
| SCSI Controller       	| VirtIO SCSI single          	|                  	    |                   	|             	|              	|
| CloudInit Drive       	| local-zfs:vm-100-cloudinit  	| media:<br>cdrom      	|                   	|             	|              	|
| CD/DVD Drive (ide2)   	| none                        	| media:<br>cdrom      	|                   	|             	|              	|
| Hard Disk (scsi0)     	| local-zfs:base-100-disk-0   	| discard:<br>enabled 	| iothread:<br>enabled 	| size:<br>50GiB|ssd:<br>enabled|
| Network Device (net0) 	| virtio=XX:XX:XX:XX:XX:XX    	| bridge:<br>vmbr0    	| firewall:<br>enabled 	|             	|              	|
| Serial Port (serial0) 	| socket                      	|                  	    |                   	|             	|              	|


### Cloud-Init ###

|                  	|                      	|           	|
|------------------	|----------------------	|-----------	|
| User             	| rmccu                	|           	|
| Password         	| ******************** 	|           	|
| DNS Domain       	| use host settings    	|           	|
| DNS Servers      	| use host settings    	|           	|
| SSH Public Keys  	| none                 	|           	|
| Upgrade Packages 	| Yes                  	|           	|
| IP Config (net0) 	| ip:<br>DHCP           | ip6:<br>DHCP 	|


### Options ###

| Name                        	| Debian-12-Base                       	|   	|   	|   	|   	|
|-----------------------------	|--------------------------------------	|---	|---	|---	|---	|
| Start at boot               	| yes                                  	|   	|   	|   	|   	|
| Start/Shutdown Order        	| order:<br>any                        	|   	|   	|   	|   	|
| OS Type                     	| Linux 6.x-2.6 Kernel                 	|   	|   	|   	|   	|
| Boot Order                  	| scsi0, ide2, net0                    	|   	|   	|   	|   	|
| Use Tablet For Pointer      	| Yes                                  	|   	|   	|   	|   	|
| Hotplug                     	| Disk, Network, USB                   	|   	|   	|   	|   	|
| ACPI support                	| Yes                                  	|   	|   	|   	|   	|
| KVM hardware virtualization 	| Yes                                  	|   	|   	|   	|   	|
| Freeze CPU at startup       	| No                                   	|   	|   	|   	|   	|
| Use Local Time For RTC      	| Default (Enabled for Windows)        	|   	|   	|   	|   	|
| RTC start date              	| now                                  	|   	|   	|   	|   	|
| SMBIOS settings (type1)     	| 064946d8-f6dd-4848-b326-4320e5e6b69b 	|   	|   	|   	|   	|
| QEMU Guest Agent            	| Enabled                              	|   	|   	|   	|   	|
| Protection                  	| No                                   	|   	|   	|   	|   	|
| Spice Enhancements          	| none                                 	|   	|   	|   	|   	|
| VM State Storage            	| Automatic                            	|   	|   	|   	|   	|

<br><br>

____________________
## Post Creation Setup ##
- Added ```deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware``` to ```/etc/apt/sources.list```
- Ran ```apt-get upgrade && apt-get update -y```
- Ran ```apt-get install qemu-guest-agent```
- Ran ```systemctl enable qemu-guest-agent```
- Ran ```apt-get install cloud-init```
- No ssh host keys were present so that step was skipped
- Ran ```truncate -s 0 /etc/machine-id```
- Ran ```apt-get clean```
- Ran ```apt-get autoremove```
- Ran ```cloud-init clean```
- Shutdown the VM and converted to template