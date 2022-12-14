# deploy-cloudimage-proxmox

This bash scripting for creating VM Proxmox using Cloudimage

How to create ???
1. Login to proxmox via ssh
2. git clone https://github.com/nandaanubis/deploy-cloudimage-proxmox.git
3. cd deploy-cloudimage-proxmox
4. bash <filename by type storage>

How to create VM base on Directory ( like local ) storage Proxmox
1. bash create.sh

How to create VM base on ZFS ( like ZFS-Data ) storage Proxmox
1. bash create-zfs.sh

How to create VM base on lvmthin ( like local-lvm ) storage Proxmox
1. bash create-lvmthin.sh

![Sample Capture](img/screnshoot.jpg)