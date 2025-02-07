#!/bin/bash

set -e  # Arrête le script en cas d'erreur
LOGFILE="/root/arch_install.log"
exec > >(tee -a "$LOGFILE") 2>&1
set -x  # Affiche chaque commande exécutée

###################################
# Variables
DISK="/dev/sda"
HOSTNAME="archlinux"
USER1="pere"
USER2="fils"
USER_PASS="azerty123"
LUKS_PASS="azerty123"
###################################

echo "### Début de l'installation d'Arch Linux ###"

# Partitionnement
echo "Partitionnement du disque $DISK..."
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart primary fat32 1MiB 513MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart primary ext4 513MiB 100%
mkfs.fat -F32 "${DISK}1"

# Chiffrement LUKS
echo "Chiffrement de la partition principale..."
echo -n "$LUKS_PASS" | cryptsetup luksFormat "${DISK}2" -
echo -n "$LUKS_PASS" | cryptsetup open "${DISK}2" cryptlvm -

# Configuration LVM
echo "Création des volumes logiques..."
pvcreate /dev/mapper/cryptlvm
vgcreate vg0 /dev/mapper/cryptlvm
lvcreate -L 18G vg0 -n root
lvcreate -L 6G vg0 -n swap
lvcreate -L 30G vg0 -n home
lvcreate -L 8G vg0 -n luks_extra
lvcreate -L 4G vg0 -n shared
lvcreate -L 2G vg0 -n virtualbox

# Formater les volumes logiques
echo "Formatage des volumes logiques..."
mkfs.ext4 /dev/vg0/root
mkfs.ext4 /dev/vg0/home
mkfs.ext4 /dev/vg0/shared
mkfs.ext4 /dev/vg0/virtualbox
mkswap /dev/vg0/swap
echo -n "$LUKS_PASS" | cryptsetup luksFormat /dev/vg0/luks_extra -
echo -n "$LUKS_PASS" | cryptsetup open /dev/vg0/luks_extra luks_manual -

# Montage des partitions
echo "Montage des partitions..."
mount /dev/vg0/root /mnt
mkdir -p /mnt/{boot,home,shared,virtualbox}
mount "${DISK}1" /mnt/boot
mount /dev/vg0/home /mnt/home
mount /dev/vg0/shared /mnt/shared
mount /dev/vg0/virtualbox /mnt/virtualbox
swapon /dev/vg0/swap

# Création temporaire des utilisateurs pour appliquer les permissions avant le chroot
echo "Création temporaire des utilisateurs pour appliquer les permissions..."
if ! grep -q "^fils:" /etc/group; then
  groupadd fils
fi
if ! id pere >/dev/null 2>&1; then
  useradd -M -g fils pere
fi
if ! id fils >/dev/null 2>&1; then
  useradd -M -g fils fils
fi

echo "Application des permissions sur /mnt/shared..."
chmod 770 /mnt/shared
chown pere:fils /mnt/shared

# Installation du système de base
echo "Installation des paquets de base..."
pacstrap /mnt base linux linux-firmware intel-ucode amd-ucode lvm2 networkmanager grub efibootmgr

# Génération du fichier fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Configuration système dans chroot
arch-chroot /mnt /bin/bash <<EOF
set -e

# Configuration de base
echo "$HOSTNAME" > /etc/hostname
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc
sed -i 's/#fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=fr_FR.UTF-8" > /etc/locale.conf
echo "KEYMAP=fr" > /etc/vconsole.conf

# Génération de l'initramfs
sed -i 's/^HOOKS.*/HOOKS=(base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

# Installation de GRUB
UUID=\$(blkid -s UUID -o value ${DISK}2)
sed -i "s|GRUB_CMDLINE_LINUX=\"\"|GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=\$UUID:cryptlvm root=/dev/vg0/root\"|" /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub.cfg

# Création des utilisateurs
useradd -m -G wheel -s /bin/bash $USER1
echo "$USER1:$USER_PASS" | chpasswd
useradd -m -s /bin/bash $USER2
echo "$USER2:$USER_PASS" | chpasswd
echo "root:$USER_PASS" | chpasswd

# Configuration des permissions du dossier partagé
chmod 770 /shared
chown $USER1:$USER2 /shared

# Activer les services
systemctl enable NetworkManager
EOF

# Suppression des utilisateurs temporaires
echo "Suppression des utilisateurs temporaires..."
if id pere >/dev/null 2>&1; then
  userdel pere
fi

if id fils >/dev/null 2>&1; then
  userdel fils
fi

if getent group fils >/dev/null 2>&1; then
  groupdel fils
fi

# Sauvegarde des fichiers requis pour le rendu
echo "Collecte des informations pour le rendu..."
mkdir -p /mnt/rendu
lsblk -f > /mnt/rendu/lsblk_f.txt
cat /mnt/etc/passwd /mnt/etc/group /mnt/etc/fstab /proc/self/mounts > /mnt/rendu/system_files.txt
echo "$HOSTNAME" > /mnt/rendu/hostname.txt
grep -i installed /mnt/var/log/pacman.log > /mnt/rendu/pacman_installed.txt

echo "### Installation terminée ! Redémarrez ! ###"
