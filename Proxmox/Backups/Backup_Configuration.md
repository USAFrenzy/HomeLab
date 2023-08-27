

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
    - Schedule: ```Sundays at 01:00```
    - Selection mode: ```All```
    - Send Email: ```rcserver.official@gmail.com```
    - Email: ```Notify Always```
    - Compression: ```ZSTD (fast and good)```
    - Mode: ```Snapshot```
    - Enable: ```ticked```
  - Retention Tab:
    - Keep Last: ```4```
      - Effectively gives a month of redundancy due to weekly scheduling
  - Note Template:
    - ```{{cluster}}, {{guestname}}, {{node}}, {{vmid}}```

________________

<br>
