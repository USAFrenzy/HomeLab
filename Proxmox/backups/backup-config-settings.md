

# Backup Configuration


<br>


## Backup Jobs

<br>

________________

#### Task One: ####
________________

  - General Tab:
    - Node: ```pveHost```
    - Storage: ```Proxmox_Backups``` (NFS Share On TrueNas Scale)
    - Schedule: ```mon..fri 00:00``
    - Selection mode: ```All```
    - Send Email: ```rcserver.official@gmail.com```
    - Email: ```Notify Always```
    - Compression: ```ZSTD (fast and good)```
    - Mode: ```Stop```
    - Enable: ```ticked```
    - Repeat missed: ```ticked```
  - Retention Tab:
    - Keep Last: ```14```
      - Gives two full weeks of redundancy due to daily scheduling
  - Note Template:
    - ```{{cluster}}, {{guestname}}, {{node}}, {{vmid}}```

________________

<br>
