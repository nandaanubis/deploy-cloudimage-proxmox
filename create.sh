#!/bin/bash
set -o errexit

clear
printf "\n*** This script will download a cloud image and create a Proxmox VM template from it. ***\n\n"

## - verify authenticity of downloaded images using hash or GPG

printf "* Available templates to generate:\n 1) Debian 10\n 2) Debian 11\n 3) Ubuntu 20.04\n\n"
read -p "* Enter number of distro to use: " OSNR

BRIDGE=vmbr0
USERCONFIG_DEFAULT=none # cloud-init-config.yml
NODEPROX="($hostname)"

case $OSNR in

  1)
    OSNAME=debian10
    VMID_DEFAULT=910
    read -p "Enter a VM ID for $OSNAME [$VMID_DEFAULT]: " VMID
    VMID=${VMID:-$VMID_DEFAULT}
    VMIMAGE=debian-9-openstack-amd64.qcow2
    NOTE="\n## Default user is 'debian'\n## NOTE: Setting a password via cloud-config does not work.\n"
    printf "$NOTE\n"
    wget -P /tmp -N https://cdimage.debian.org/cdimage/openstack/current-9/$VMIMAGE
    ;;

  2)
    OSNAME=debian11
    VMID_DEFAULT=920
    read -p "Enter a VM ID for $OSNAME [$VMID_DEFAULT]: " VMID
    VMID=${VMID:-$VMID_DEFAULT}
    VMIMAGE=debian-10-openstack-amd64.qcow2
    NOTE="\n## Default user is 'debian'\n"
    printf "$NOTE\n"
    wget -P /tmp -N https://cdimage.debian.org/cdimage/openstack/current-10/$VMIMAGE
    ;;

  3)
    OSNAME=ubuntu2
    VMID_DEFAULT=930
    read -p "Enter a VM ID for $OSNAME [$VMID_DEFAULT]: " VMID
    VMID=${VMID:-$VMID_DEFAULT}
    VMIMAGE=focal-server-cloudimg-amd64.img
    NOTE="\n## Default user is 'ubuntu'\n"
    printf "$NOTE\n"
    wget -P /tmp -N https://cloud-images.ubuntu.com/focal/current/$VMIMAGE
    ;;


  *)
    printf "\n** Unknown OS number. Please use one of the above!\n"
    exit 0
    ;;
esac

[[ $VMIMAGE == *".bz2" ]] \
    && printf "\n** Uncompressing image (waiting to complete...)\n" \
    && bzip2 -d --force /tmp/$VMIMAGE \
    && VMIMAGE=$(echo "${VMIMAGE%.*}") # remove .bz2 file extension from file name

# TODO: could prompt for the VM name
printf "\n** Creating a VM with $MEMORY MB using network bridge $BRIDGE\n"
qm create $VMID --name $OSNAME-cloud --memory $MEMORY --net0 virtio,bridge=$BRIDGE

printf "\n** Importing the disk in qcow2 format (as 'Unused Disk 0')\n"
qm importdisk $VMID /tmp/$VMIMAGE local -format qcow2

printf "\n** Attaching the disk to the vm using VirtIO SCSI\n"
qm set $VMID --scsihw virtio-scsi-pci --scsi0 /var/lib/vz/images/$VMID/vm-$VMID-disk-0.qcow2

printf "\n** Setting boot and display settings with serial console\n"
qm set $VMID --boot c --bootdisk scsi0 --serial0 socket --vga serial0

printf "\n** Using a dhcp server on $BRIDGE (or change to static IP)\n"
qm set $VMID --ipconfig0 ip=dhcp

printf "\n** Creating a cloudinit drive managed by Proxmox\n"
qm set $VMID --ide2 local:cloudinit

printf "\n** Enable Qemu Guest Agent\n"
qm set $VMID --agent enabled=1

printf "\n** Enable Qemu Guest Agent\n"
sleep 30
printf "\n** Update Size\n"
qm resize $VMID scsi0 $RESIZE

## TODO: Also ask for a network configuration. Or create a config with routing for a static IP
printf "\n*** Create Username and password VM.\n"
read -p ' Input your username for Virtual Machine : ' VMUSER
read -p ' Input your password for Virtual Machine : ' VMPASS
qm set $VMID --cipassword="$VMPASS" --ciuser=$VMUSER


# The NOTE is added to the Summary section of the VM (TODO there seems to be no 'qm' command for this)
#printf "#$NOTE\n" >> /etc/pve/nodes/$NODEPROX/qemu-server/$VMID.conf
printf "$NOTE\n\n"
