#!/bin/bash

set -e  # Arrêt en cas d'erreur
LOGFILE="/root/arch_install.log"
exec > >(tee -a "$LOGFILE") 2>&1
set -x  # Afficher chaque commande exécutée

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
DNS="1.1.1.1"

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
echo -n "$LUKS_PASS" | cryptsetup luksFormat --type luks2 "$LVM_PART"
echo -n "$LUKS_PASS" | cryptsetup open "$LVM_PART" cryptlvm

# ===============================
# CONFIGURATION LVM
# ===============================
echo "Création des volumes logiques..."
pvcreate /dev/mapper/cryptlvm # Partition chiffrée
vgcreate vg0 /dev/mapper/cryptlvm # Groupe de volumes
lvcreate -L 18G vg0 -n root # Partition racine
lvcreate -L 6G vg0 -n swap # Partition swap
lvcreate -L 30G vg0 -n home # Volume home chiffré
lvcreate -L 10G vg0 -n luks_extra  # Volume chiffré manuel
lvcreate -L 5G vg0 -n shared  # Dossier partagé entre père et fils
lvcreate -L 10G vg0 -n virtualbox  # Stockage dédié VirtualBox

# ===============================
# FORMATAGE DES VOLUMES LOGIQUES
# ===============================
echo "Formatage des volumes logiques..."
mkfs.ext4 /dev/vg0/root
mkfs.ext4 /dev/vg0/home
mkfs.ext4 /dev/vg0/shared
mkfs.ext4 /dev/vg0/virtualbox
mkswap /dev/vg0/swap
echo -n "$LUKS_PASS" | cryptsetup luksFormat --type luks2 /dev/vg0/luks_extra

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
pacstrap /mnt base linux linux-firmware intel-ucode amd-ucode lvm2 networkmanager grub efibootmgr os-prober \
    xorg xorg-xinit i3 firefox git neovim sddm waybar xdg-desktop-portal-hyprland mako swaylock \
    virtualbox base-devel alacritty xdg-user-dirs rofi starship dmenu picom \
    ttf-dejavu noto-fonts pavucontrol pulseaudio pulseaudio-alsa pulseaudio-bluetooth \
    vim htop neofetch curl wget fzf gcc make gdb clang nano openssh


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

# Configuration DNS
echo "nameserver $DNS" > /etc/resolv.conf

# ===============================
# CONFIGURATION INITRAMFS
# ===============================
sed -i 's/^HOOKS.*/HOOKS=(base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

# ===============================
# CONFIGURATION GRUB
# ===============================
UUID=\$(blkid -s UUID -o value "$LVM_PART")
sed -i "s|GRUB_CMDLINE_LINUX=\"\"|GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=\$UUID:cryptlvm root=/dev/vg0/root\"|" /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck
grub-mkconfig -o /boot/grub/grub.cfg

# ===============================
# CRÉATION DES UTILISATEURS
# ===============================
useradd -m -G wheel -s /bin/bash "$USER1"
echo "$USER1:$USER_PASS" | chpasswd
useradd -m -s /bin/bash "$USER2"
echo "$USER2:$USER_PASS" | chpasswd
echo "root:$USER_PASS" | chpasswd


# ===============================
# CONFIGURATION DES PERMISSIONS POUR /shared
# ===============================

groupadd shared 

usermod -aG shared "$USER1"
usermod -aG shared "$USER2"

mkdir -p /shared
chown -R "$USER1:shared" /shared
chmod 770 /shared
chmod g+s /shared

chown -R "$USER1:$USER1" /home/$USER1
chown -R "$USER2:$USER2" /home/$USER2

# ===============================
# CONFIGURATION I3
# ===============================
mkdir -p /home/$USER1/.config/i3
mkdir -p /home/$USER1/.config  # Correction ici

cat <<I3CONF > /home/$USER1/.config/i3/config
set \\\$mod Mod4
font pango:DejaVu Sans Mono 10
bindsym \\\$mod+Return exec alacritty
bindsym \\\$mod+d exec rofi -show drun
bindsym \\\$mod+Shift+q kill
bindsym \\\$mod+Shift+r restart
bindsym \\\$mod+f fullscreen toggle

bar {
    status_command i3status
}

exec --no-startup-id picom
exec --no-startup-id nm-applet
exec --no-startup-id setxkbmap fr
I3CONF

chown -R "$USER1:$USER1" /home/$USER1/.config

# Configuration .XINITRC
echo "exec i3" > /home/$USER1/.xinitrc
chmod +x /home/$USER1/.xinitrc
chown "$USER1:$USER1" /home/$USER1/.xinitrc


# ===============================
# Configuration .BASHRC 
# ===============================

cat <<BASHRC > /home/$USER1/.bashrc
eval "\$(starship init bash)"
alias ll="ls -la --color=auto"
alias update="sudo pacman -Syu"
alias ..="cd .."
alias ...="cd ../.."
PS1="\[\e[1;34m\]\u@\h\[\e[0m\] \[\e[1;32m\]\w\[\e[0m\]\n\$ "
BASHRC
cp /home/$USER1/.bashrc /home/$USER2/.bashrc
chown "$USER1:$USER1" /home/$USER1/.bashrc
chown "$USER2:$USER2" /home/$USER2/.bashrc

# ===============================
# INSTALLATION DE YAY
# ===============================
echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
pacman -S --noconfirm git base-devel
git clone https://aur.archlinux.org/yay.git /opt/yay
chown -R "$USER1:$USER1" /opt/yay
su - "$USER1" -c "cd /opt/yay && makepkg -si --noconfirm"
su - "$USER1" -c "yay -S --noconfirm wlogout"

# ===============================
# FINALISATION
# ===============================
xdg-user-dirs-update
systemctl enable NetworkManager
systemctl enable sddm

EOF

echo "### Installation terminée ! Redémarrez ! ###"