#!/bin/bash

# Si une erreur survient, le script s'arrête
set -e 

# Vérification : Le script doit être lancé en root
if [ "$EUID" -ne 0 ]
  then echo "Veuillez exécuter ce script en tant que root."
  exit
fi

# Variables
DISK="/dev/sda"
HOSTNAME="archlinux"
USER1="pere"
USER2="fils"
USER_PASS="azerty123"
LUKS_PASS="azerty123"

echo "### Installation d'Arch Linux Automatisée ###"
sleep 2

### Partitionnement ###
echo "Création des partitions..."
parted -s $DISK mklabel gpt 
parted -s $DISK mkpart primary fat32 1MiB 513MiB 
parted -s $DISK set 1 esp on 
parted -s $DISK mkpart primary ext4 513MiB 100%
mkfs.fat -F32 "${DISK}1"

### 2Chiffrement LUKS ###
echo "Chiffrement de la partition principale..."
echo -n "$LUKS_PASS" | cryptsetup luksFormat "${DISK}2" -
echo -n "$LUKS_PASS" | cryptsetup open "${DISK}2" cryptlvm -

### Configuration LVM ###
echo "Création des volumes logiques..."
pvcreate /dev/mapper/cryptlvm
vgcreate vg0 /dev/mapper/cryptlvm
lvcreate -L 20G vg0 -n root
lvcreate -L 8G vg0 -n swap
lvcreate -L 35G vg0 -n home
lvcreate -L 10G vg0 -n luks_extra
lvcreate -L 5G vg0 -n shared
lvcreate -L 2G vg0 -n virtualbox
mkfs.ext4 /dev/vg0/root
mkfs.ext4 /dev/vg0/home
mkfs.ext4 /dev/vg0/shared
mkfs.ext4 /dev/vg0/virtualbox
mkswap /dev/vg0/swap

# Volume logique chiffré manuel
echo -n "$LUKS_PASS" | cryptsetup luksFormat /dev/vg0/luks_extra -
echo -n "$LUKS_PASS" | cryptsetup open /dev/vg0/luks_extra luks_manual -

### Montage des partitions ###
echo "Montage des partitions..."
mount /dev/vg0/root /mnt
mkdir -p /mnt/{boot,home,shared,virtualbox}
mount "${DISK}1" /mnt/boot
mount /dev/vg0/home /mnt/home
mount /dev/vg0/shared /mnt/shared
mount /dev/vg0/virtualbox /mnt/virtualbox
swapon /dev/vg0/swap

### Installation de base ###
echo "Installation des paquets de base..."
pacstrap /mnt base linux linux-firmware lvm2 sudo nano vim networkmanager

# Génération du fstab
genfstab -U /mnt >> /mnt/etc/fstab

### Configuration système ###
arch-chroot /mnt /bin/bash <<EOF
set -e

# Configuration de base
echo "$HOSTNAME" > /etc/hostname
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc
sed -i 's/#fr_FR.UTF-8/fr_FR.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=fr_FR.UTF-8" > /etc/locale.conf
echo "KEYMAP=fr" > /etc/vconsole.conf

# mkinitcpio
sed -i 's/^HOOKS.*/HOOKS=(base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

# Installation de GRUB
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="cryptdevice=UUID=$(blkid -s UUID -o value ${DISK}2):cryptlvm root=/dev/vg0/root"/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Création des utilisateurs
useradd -m -G wheel -s /bin/bash $USER1
echo "$USER1:$USER_PASS" | chpasswd
useradd -m -s /bin/bash $USER2
echo "$USER2:$USER_PASS" | chpasswd

# Configuration sudo
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Activer les services
systemctl enable NetworkManager

# Installer des logiciels supplémentaires
pacman -S --noconfirm xorg-server xorg-xinit hyprland waybar firefox alacritty nano vim \
    virtualbox virtualbox-host-modules-arch

# Configuration des permissions du dossier partagé
chmod 770 /mnt/shared
chown $USER1:$USER2 /mnt/shared
EOF

echo "Installation terminée ! Vous pouvez redémarrer."
