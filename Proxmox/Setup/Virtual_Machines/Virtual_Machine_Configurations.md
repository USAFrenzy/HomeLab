
# Virtual Machines And Their Configuration Settings

<br>

________________________________________________

### MasterNode (Cloned of Debian-12-Base) ###
________________________________________________

- agent: ```1```
- boot: ```order=scsi0;ide2;net0```
- cipassword: ```**********```
- ciuser: ```*********```
- cores: ```8```
- cpu: ```x86-64-v2-AES```
- ide0: ```local-zfs:vm-1001-cloudinit,media=cdrom,size=4M```
- ide2: ```none,media=cdrom```
- ipconfig0: ```ip=dhcp,ip6=dhcp```
- memory: ```16384```
- meta: ```creation-qemu=8.0.2,ctime=1693088084```
- name: ```MasterNode```
- net0: ```virtio=BA:44:D0:DF:C4:DD,bridge=vmbr0,firewall=1```
- numa: ```0```
- onboot: ```1```
- ostype: ```l26```
- parent: ```Base```
- scsi0: ```local-zfs:vm-1001-disk-0,discard=on,iothread=1,size=50G,ssd=1```
- scsihw: ```virtio-scsi-single```
- serial0: ```socket```
- smbios1: ```uuid=f32292c0-895d-41c1-9eaf-1a18460ce608```
- sockets: ```1```
- vga: ```serial0```
- vmgenid: ```a44bf69f-3a28-4fb8-af83-995dfd765a7d```
- Additional:
  - Installed sudo
  - Made external user a sudoer
  - Removed root password login
  - Starts On Boot (Before The Worker Nodes)

<br>

________________________________________________

### WorkerNode01 (Cloned of Debian-12-Base) ###
________________________________________________
- agent: ```1```
- boot: ```order=scsi0;ide2;net0```
- cipassword: ```**********```
- ciuser: ```*********```
- cores: ```4```
- cpu: ```x86-64-v2-AES```
- ide0: ```local-zfs:vm-1002-cloudinit,media=cdrom,size=4M```
- ide2: ```none,media=cdrom```
- ipconfig0: ```ip=dhcp,ip6=dhcp```
- memory: ```8192```
- meta: ```creation-qemu=8.0.2,ctime=1693088084```
- name: ```WorkerNode01```
- net0: ```virtio=72:C2:9D:E9:F3:4A,bridge=vmbr0,firewall=1```
- numa: ```0```
- onboot: ```1```
- ostype: ```l26```
- parent: ```Base```
- scsi0: ```local-zfs:vm-1002-disk-0,discard=on,iothread=1,size=50G,ssd=1```
- scsihw: ```virtio-scsi-single```
- serial0: ```socket```
- smbios1: ```uuid=3b8944fe-ccf5-4147-9528-1a55fff4bac6```
- sockets: ```1```
- startup: ```up=15```
- vga: ```serial0```
- vmgenid: ```50ae5d91-aeb6-400d-92e2-bdf4e78ee9fd```
- Additional:
  - Installed sudo
  - Made external user a sudoer
  - Removed root password login

<br>

________________________________________________

### WorkerNode02 (Cloned of Debian-12-Base) ###
________________________________________________
- agent: ```1```
- boot: ```order=scsi0;ide2;net0```
- cipassword: ```**********```
- ciuser: ```*********```
- cores: ```4```
- cpu: ```x86-64-v2-AES```
- ide0: ```local-zfs:vm-1003-cloudinit,media=cdrom,size=4M```
- ide2: ```none,media=cdrom```
- ipconfig0: ```ip=dhcp,ip6=dhcp```
- memory: ```8192```
- meta: ```creation-qemu=8.0.2,ctime=1693088084```
- name: ```WorkerNode02```
- net0: ```virtio=0E:F8:93:4F:DF:32,bridge=vmbr0,firewall=1```
- numa: ```0```
- onboot: ```1```
- ostype: ```l26```
- parent: ```Base```
- scsi0: ```local-zfs:vm-1003-disk-0,discard=on,iothread=1,size=50G,ssd=1```
- scsihw: ```virtio-scsi-single```
- serial0: ```socket```
- smbios1: ```uuid=3675327b-b638-478c-b8c7-0ffbce9e3956```
- sockets: ```1```
- startup: ```up=15```
- vga: ```serial0```
- vmgenid: ```8cda241c-a082-4dca-8d95-9a11dc3e8169```
- Additional:
  - Installed sudo
  - Made external user a sudoer
  - Removed root password login

<br>

________________________________________________

### WorkerNode03 (Cloned of Debian-12-Base) ###
________________________________________________
- agent: ```1```
- boot: ```order=scsi0;ide2;net0```
- cipassword: ```**********```
- ciuser: ```*********```
- cores: ```4```
- cpu: ```x86-64-v2-AES```
- ide0: ```local-zfs:vm-1004-cloudinit,media=cdrom,size=4M```
- ide2: ```none,media=cdrom```
- ipconfig0: ```ip=dhcp,ip6=dhcp```
- memory: ```8192```
- meta: ```creation-qemu=8.0.2,ctime=1693088084```
- name: ```WorkerNode03```
- net0: ```virtio=BE:8D:B7:98:86:B1,bridge=vmbr0,firewall=1```
- numa: ```0```
- onboot: ```1```
- ostype: ```l26```
- parent: ```Base```
- scsi0: ```local-zfs:vm-1004-disk-0,discard=on,iothread=1,size=50G,ssd=1```
- scsihw: ```virtio-scsi-single```
- serial0: ```socket```
- smbios1: ```uuid=2aa00ccd-ad86-4c08-b974-ed92f11a17a9```
- sockets: ```1```
- startup: ```up=15```
- vga: ```serial0```
- vmgenid: ```5c42df1b-c970-425f-8f76-d73075bfdda9```
- Additional:
  - Installed sudo
  - Made external user a sudoer
  - Removed root password login