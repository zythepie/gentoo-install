#!/bin/bash

#Stage 3
cd /mnt/gentoo
wget <PASTED_STAGE_URL>
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner

#Configuring Portage

#Chrooting
mirrorselect -i -o >> /mnt/gentoo/etc/portage/make.conf
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

mkdir /efi
mount /dev/sda1 /efi

emerge-webrsync
emerge --sync

#Choosing the right profile
eselect profile set 5

#Updating the @world set
emerge --ask --verbose --update --deep --newuse @world

