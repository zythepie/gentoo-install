#!/bin/bash

cryptsetup -v -y -c aes-xts-plain64 -s 512 -h sha512 -i 5000 --use-random luksFormat /dev/nvme0n1p2
cryptsetup luksOpen /dev/nvme0n1p2 gentoo

pvcreate /dev/mapper/gentoo
vgcreate gentoo /dev/mapper/gentoo
lvcreate -C y -L 16G gentoo -n swap
lvcreate -l +100%FREE gentoo -n root

mkfs.ext4 /dev/mapper/gentoo-root
mkfs.vfat -F 32 /dev/nvme0n1p1
mkswap /dev/mapper/gentoo-swap

mount /dev/mapper/gentoo-root /mnt/gentoo
mkdir -p /mnt/gentoo/efi
mount /dev/nvme0n1p1 /mnt/gentoo/efi
swapon /dev/mapper/gentoo-swap

cd /mnt/gentoo
wget https://distfiles.gentoo.org/releases/amd64/autobuilds/20230924T163139Z/stage3-amd64-openrc-20230924T163139Z.tar.xz
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner

mkdir --parents /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf

cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
mount --make-slave /mnt/gentoo/run 
chroot /mnt/gentoo /bin/bash
source /etc/profile
export PS1="(chroot) ${PS1}"

emerge-webrsync
emerge --sync

rm -rf /etc/portage/make.conf
touch /etc/portage/make.conf
echo "
COMMON_FLAGS="-march=native -O2 -pipe"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
FCFLAGS="${COMMON_FLAGS}"
FFLAGS="${COMMON_FLAGS}"

USE="lvm crypt"
MAKEOPTS="-j16"
ACCEPT_LICENSE="*"
GENTOO_MIRRORS="https://mirror.aarnet.edu.au/pub/gentoo/"

LC_MESSAGES=C.utf8cd 
" > /etc/portage/make.conf

echo "
*/* CPU_FLAGS_X86: aes avx avx2 avx512f avx512dq avx512cd avx512bw avx512vl avx512vbmi f16c fma3 mmx mmxext pclmul popcnt rdrand sha sse sse2 sse3 sse4_1 sse4_2 ssse3
" > /etc/portage/package.use/00cpu-flags

eselect profile set 1

emerge -uDN @world
echo "sys-boot/grub mount device-mapper" > /etc/portage/package.use/grub
emerge doas dracut cryptsetup gentoo-kernel-bin grub linux-firmware lvm networkmanager

echo "Australia/Sydney" > /etc/timezone
emerge --config sys-libs/timezone-data

rm -rf /etc/locale.gen
touch /etc/locale.gen
echo "
en_US ISO-8859-1
en_US.UTF-8 UTF-8
" > /etc/locale.gen
eselect locale set 5
env-update && source /etc/profile && export PS1="(chroot) ${PS1}"

dracut --force -H --kver <gentoo-kernel-bin-version>
rc-update add lvm boot
rc-update add dmcrypt boot

echo "
GRUB_DISTRIBUTOR="Gentoo"
GRUB_TIMEOUT=0
GRUB_CMDLINE_LINUX="crypt_root=/dev/nvme0n1p2 root=/dev/mapper/gentoo-root dolvm quiet"
GRUB_GFXMODE=1920x1080
GRUB_DISABLE_LINUX_PARTUUID=false
" > /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot /dev/nvme0n1p1
grub-mkconfig -o /boot/grub/grub.cfg

rm -rf /etc/fstab
touch /etc/fstab
echo "
/dev/mapper/gentoo-root	/		ext4		noatime,discard		0 1
/dev/nvme0n1p1		/boot		vfat		defaults,noatime	0 2
/dev/mapper/gentoo-swap	none		swap		defaults		0 0
" > /etc/fstab

echo gentoo > /etc/hostname

rm -rf /etc/hosts
touch /etc/hosts
echo "
127.0.0.1	localhost	gentoo
" > /etc/hosts

passwd
useradd -m -G users,wheel,audio,video zyzy
passwd zyzy

chown -c root:root /etc/doas.conf
chmod -c 0400 /etc/doas.conf
echo "
permit :wheel
" > /etc/doas.conf

reboot