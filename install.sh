#!/bin/bash

cryptsetup -v -y -c aes-xts-plain64 -s 512 -h sha512 -i 5000 --use-random luksFormat /dev/nvme0n1p2
cryptsetup luksDump /dev/nvme0n1p2
cryptsetup luksOpen /dev/nvme0n1p2 gentoo

pvcreate /dev/mapper/gentoo
vgcreate gentoo /dev/mapper/gentoo
pvdisplay
vgdisplay
lvcreate -C y -L 16G gentoo -n swap
lvcreate -l +100%FREE gentoo -n root

mkswap /dev/mapper/gentoo-swap
mkfs.ext4 /dev/mapper/gentoo-root
mkfs.vfat -F 32 /dev/nvme0n1p1

mkdir -p /mnt/gentoo
mount /dev/mapper/gentoo-root /mnt/gentoo
swapon /dev/mapper/gentoo-swap

cd /mnt/gentoo
wget https://distfiles.gentoo.org/releases/amd64/autobuilds/20230924T163139Z/stage3-amd64-openrc-20230924T163139Z.tar.xz
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner

mkdir --parents /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf

cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
mount --make-slave /mnt/gentoo/run 

chroot /mnt/gentoo /bin/bash
root #source /etc/profile
root #export PS1="(chroot) ${PS1}"

emerge-webrsync
emerge --sync

eselect profile set 1

emerge --update --deep --newuse @world
