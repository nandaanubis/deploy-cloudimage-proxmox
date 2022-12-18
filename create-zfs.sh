#!/bin/bash
set -o errexit
clear
printf "\n*** This script will download a cloud image and create a Proxmox VM. ***\n\n"
## TODO
## - verify authenticity of downloaded images using hash or GPG
printf "* Available templates to generate:\n 1) Debian 11\n 2) Centos 7\n 3) Ubuntu 22.04\n 4) Ubuntu 20.04\n 5) Ubuntu 18.04\n 6) Cloudlinux 8.5 + Cpanel\n 7) Cloudlinux 7.9 + Cpanel\n\n"
read -p "* Enter number of distro to use: " OSPROX
NODEPROX="($hostname)"

case $OSPROX in

  1)
    OSNAME="Debian 11"
    VMID_DEFAULT=900
    read -p "Enter a VM ID for $OSNAME [$VMID_DEFAULT]: " VMID
    VMID=${VMID:-$VMID_DEFAULT}
    VMIMAGE=debian-11-genericcloud-amd64-daily-20221109-1194.qcow2
    wget -P /tmp -N https://cloud.debian.org/images/cloud/bullseye/daily/20221109-1194/$VMIMAGE
    ;;

  2)
    OSNAME="Centos 7"
    VMID_DEFAULT=900
    read -p "Enter a VM ID for $OSNAME [$VMID_DEFAULT]: " VMID
    VMID=${VMID:-$VMID_DEFAULT}
    VMIMAGE=CentOS-7-x86_64-GenericCloud-2111.qcow2
    wget -P /tmp -N https://cloud.centos.org/centos/7/images/$VMIMAGE
    ;;

  3)
    OSNAME="Ubuntu 22.04"
    VMID_DEFAULT=900
    read -p "Enter a VM ID for $OSNAME [$VMID_DEFAULT]: " VMID
    VMID=${VMID:-$VMID_DEFAULT}
    VMIMAGE=jammy-server-cloudimg-amd64.img
    wget -P /tmp -N https://cloud-images.ubuntu.com/jammy/current/$VMIMAGE
    ;;

  4)
    OSNAME="Ubuntu 20.04"
    VMID_DEFAULT=900
    read -p "Enter a VM ID for $OSNAME [$VMID_DEFAULT]: " VMID
    VMID=${VMID:-$VMID_DEFAULT}
    VMIMAGE=focal-server-cloudimg-amd64.img
    wget -P /tmp -N https://cloud-images.ubuntu.com/focal/current/$VMIMAGE
    ;;

   5)
    OSNAME="Ubuntu 18.04"
    VMID_DEFAULT=900
    read -p "Enter a VM ID for $OSNAME [$VMID_DEFAULT]: " VMID
    VMID=${VMID:-$VMID_DEFAULT}
    VMIMAGE=bionic-server-cloudimg-amd64.img
    wget -P /tmp -N https://cloud-images.ubuntu.com/bionic/current/$VMIMAGE
    ;;

  6)
    OSNAME="Cloudlinux 8.5 + Cpanel"
    VMID_DEFAULT=900
    read -p "Enter a VM ID for $OSNAME [$VMID_DEFAULT]: " VMID
    VMID=${VMID:-$VMID_DEFAULT}
    VMIMAGE=cloudlinux-8.5-x86_64-cpanel-openstack-20220414.qcow2
    wget -P /tmp -N https://download.cloudlinux.com/cloudlinux/images/$VMIMAGE
    ;;

   7)
    OSNAME="Cloudlinux 7.9 + Cpanel"
    VMID_DEFAULT=900
    read -p "Enter a VM ID for $OSNAME [$VMID_DEFAULT]: " VMID
    VMID=${VMID:-$VMID_DEFAULT}
    VMIMAGE=cloudlinux-7.9-x86_64-cpanel-openstack-20220621.qcow2
    wget -P /tmp -N https://download.cloudlinux.com/cloudlinux/images/$VMIMAGE
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

## TODO: Creating Config VM
printf "\n*** Config VM .\n"
read -p ' Input Hostname for Virtual Machine (exp : iwasyourfather.end ) : ' VMNAME
read -p ' Input your username for Virtual Machine : ' VMUSER
read -p ' Input your password for Virtual Machine : ' VMPASS
read -p ' Input Memory for Virtual Machine (exp: 1024 for 1G ) : ' VMRAM
read -p ' Input Increase Storage do you want (exp : 20G ): ' VMSTOR
read -p ' Input Name of Storage (exp : local or local-lvm ): ' VMNAMESTOR
read -p ' Input Interface Network (exp : vmbr0 ): ' VMNET


printf "\n** Creating a VM with $VMRAM MB using network bridge $VMNET\n"
qm create $VMID --name $VMNAME --memory $VMRAM --net0 virtio,bridge=$VMNET &> /dev/null

printf "\n** Importing the disk in qcow2 format (as 'Unused Disk 0')\n"
qm importdisk $VMID /tmp/$VMIMAGE $VMNAMESTOR -format qcow2 &> /dev/null

printf "\n** Attaching the disk to the vm using VirtIO SCSI\n"
qm set $VMID --scsihw virtio-scsi-pci --scsi0 $VMNAMESTOR:vm-$VMID-disk-0 &> /dev/null

printf "\n** Setting boot and display settings with serial console\n"
qm set $VMID --boot c --bootdisk scsi0 --serial0 socket --vga serial0 &> /dev/null

printf "\n** Using a dhcp server on $VMNET\n"
qm set $VMID --ipconfig0 ip=dhcp &> /dev/null

printf "\n** Creating a cloudinit drive managed by Proxmox\n"
qm set $VMID --ide2 $VMNAMESTOR:cloudinit &> /dev/null

printf "\n** Enable Qemu Guest Agent\n"
qm set $VMID --agent enabled=1 &> /dev/null

printf "\n** Create Username and password\n"
qm set $VMID --cipassword="$VMPASS" --ciuser=$VMUSER &> /dev/null
printf "\n** Update Size \n"
sleep 30
qm resize $VMID scsi0 +$VMSTOR &> /dev/null

printf "\n** VM Create status : Done\n"
echo=""
printf "\n** Status VM\n"
qm list | grep $VMID
