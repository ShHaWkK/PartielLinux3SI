#!/bin/bash

set -e  # Stop en cas d'erreur
LOGFILE="/root/arch_install.log"
exec > >(tee -a "$LOGFILE") 2>&1
set -x  # Affiche chaque commande exécutée

# ===============================
# CONFIGURATION
# ===============================
DISK="/dev/sda"
EFI_PART="${DISK}1"
LVM_PART="${DISK}2"
HOSTNAME="archlinux"
USER1="pere"
USER2="fils"
USER_PASS="azerty123"
LUKS_PASS="azerty123"

echo "### Début de l'installation d'Arch Linux ###"

# ===============================
# PARTITIONNEMENT ET FORMATAGE
# ===============================
echo "Partitionnement du disque $DISK..."
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart primary fat32 1MiB 513MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart primary ext4 513MiB 100%
mkfs.fat -F32 "$EFI_PART"

# ===============================
# CHIFFREMENT LUKS
# ===============================
echo "Chiffrement de la partition principale..."
echo -n "$LUKS_PASS" | cryptsetup luksFormat "$LVM_PART" -
echo -n "$LUKS_PASS" | cryptsetup open "$LVM_PART" cryptlvm -

# ===============================
# CONFIGURATION LVM
# ===============================
echo "Création des volumes logiques..."
pvcreate /dev/mapper/cryptlvm
vgcreate vg0 /dev/mapper/cryptlvm
lvcreate -L 18G vg0 -n root
lvcreate -L 6G vg0 -n swap
lvcreate -L 30G vg0 -n home
lvcreate -L 10G vg0 -n luks_extra
lvcreate -L 5G vg0 -n shared
lvcreate -L 10G vg0 -n virtualbox

# ===============================
# FORMATAGE DES VOLUMES LOGIQUES
# ===============================
echo "Formatage des volumes logiques..."
mkfs.ext4 /dev/vg0/root
mkfs.ext4 /dev/vg0/home
mkfs.ext4 /dev/vg0/shared
mkfs.ext4 /dev/vg0/virtualbox
mkswap /dev/vg0/swap
echo -n "$LUKS_PASS" | cryptsetup luksFormat /dev/vg0/luks_extra -

# ===============================
# MONTAGE DES PARTITIONS
# ===============================
echo "Montage des partitions..."
mount /dev/vg0/root /mnt
mkdir -p /mnt/{boot,home,shared,virtualbox}
mount "$EFI_PART" /mnt/boot
mount /dev/vg0/home /mnt/home
mount /dev/vg0/shared /mnt/shared
mount /dev/vg0/virtualbox /mnt/virtualbox
swapon /dev/vg0/swap

# ===============================
# INSTALLATION DU SYSTÈME DE BASE
# ===============================
echo "Installation des paquets de base..."
pacstrap /mnt base linux linux-firmware intel-ucode amd-ucode lvm2 networkmanager grub efibootmgr hyprland i3 firefox git neovim

# ===============================
# GÉNÉRATION DU FSTAB
# ===============================
genfstab -U /mnt >> /mnt/etc/fstab

# ===============================
# CONFIGURATION DANS CHROOT
# ===============================
arch-chroot /mnt /bin/bash <<EOF
set -e

# Configuration système de base
echo "$HOSTNAME" > /etc/hostname
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc
sed -i 's/#fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=fr_FR.UTF-8" > /etc/locale.conf
echo "KEYMAP=fr" > /etc/vconsole.conf

# ===============================
# INSTALLATION ET CONFIGURATION DE GRUB
# ===============================
echo "Installation et configuration de GRUB..."
UUID=\$(blkid -s UUID -o value "$LVM_PART")

sed -i "s|GRUB_CMDLINE_LINUX=\"\"|GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$UUID:cryptlvm root=/dev/vg0/root\"|" /etc/default/grub

mkdir -p /boot/efi
mount "$EFI_PART" /boot/efi

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck --modules="lvm luks2 part_gpt"

grub-mkconfig -o /boot/grub/grub.cfg

# ===============================
# CRÉATION DES UTILISATEURS
# ===============================
useradd -m -G wheel -s /bin/bash $USER1
echo "$USER1:$USER_PASS" | chpasswd
useradd -m -s /bin/bash $USER2
echo "$USER2:$USER_PASS" | chpasswd
echo "root:$USER_PASS" | chpasswd

# Permissions du dossier partagé
chmod 770 /shared
chown $USER1:$USER2 /shared

# Activer les services essentiels
systemctl enable NetworkManager

# ===============================
# INSTALLATION D’ENVIRONNEMENT GRAPHIQUE
# ===============================
echo "Installation de Hyprland et i3..."
pacman -S --noconfirm xorg xorg-xinit hyprland i3 dmenu alacritty firefox neovim git 

# Configuration de Hyprland
mkdir -p /home/$USER1/.config/hypr
cat <<HYPRCONF > /home/$USER1/.config/hypr/hyprland.conf
exec firefox
bind = $mainMod, RETURN, exec, alacritty
bind = $mainMod SHIFT, Q, killactive
bind = $mainMod, D, exec, dmenu_run
HYPRCONF
chown -R $USER1:$USER1 /home/$USER1/.config

EOF

# ===============================
# SUPPRESSION DES UTILISATEURS TEMPORAIRES
# ===============================
echo "Suppression des utilisateurs temporaires..."
userdel -r pere 2>/dev/null || true
userdel -r fils 2>/dev/null || true
groupdel fils 2>/dev/null || true

# ===============================
# SAUVEGARDE DES INFORMATIONS
# ===============================
echo "Collecte des informations..."
mkdir -p /mnt/rendu
lsblk -f > /mnt/rendu/lsblk_f.txt
cat /mnt/etc/passwd /mnt/etc/group /mnt/etc/fstab /proc/self/mounts > /mnt/rendu/system_files.txt
echo "$HOSTNAME" > /mnt/rendu/hostname.txt
grep -i installed /mnt/var/log/pacman.log > /mnt/rendu/pacman_installed.txt

echo "### Installation terminée ! Redémarrez ! ###"
