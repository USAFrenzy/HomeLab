
# NFS Shares Enabled For Proxmox

<br>

___________________________________________________________________

## Backup Shares

- ```Proxmox_Backup``` dataset created on ```Archival_Pool```
  - Permissions:
    - owner: ```root``` -> ```rwx```
    - group: ```root``` -> ```rwx```
    - other: ```none```
 - UNIX (NFS) Shares
   - Path: ```/mnt/Archival_Pool/Proxmox_Backups```
   - Name: ```Proxmox_Backups```
   - Enabled: ```ticked```
   - Under Advanced Settings:
     - Maproot User: ```root```
     - Maproot Group: ```root```

___________________________________________________________________

<br>