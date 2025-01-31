#!/bin/bash

# Si une erreur survient, le script s'arrête immédiatement
set -e 

# Vérification que le script est exécuté en root
if [ "$EUID" -ne 0 ]; then
  echo "Veuillez exécuter ce script en tant que root."
  exit 1
fi

# Variables
DISK="/dev/sda"
HOSTNAME="archlinux"
USER1="pere"
USER2="fils"
USER_PASS="azerty123"
LUKS_PASS="azerty123"

echo "Démarrage de l'installation d'Arch Linux..."
sleep 2

### Partitionnement du disque ###
echo "### Création des partitions ###"

# Création du label GPT
parted -s "$DISK" mklabel gpt 
echo "Label GPT créé sur $DISK"

# Création de la partition de boot EFI
parted -s "$DISK" mkpart primary fat32 1MiB 513MiB 
echo "Partition de boot créée"

parted -s "$DISK" set 1 esp on 
echo "Partition de boot définie comme ESP"

# Création de la partition racine (sera chiffrée avec LUKS)
parted -s "$DISK" mkpart primary 513MiB 100%
echo "Partition racine créée"

# Affichage des partitions
parted -s "$DISK" print
echo "Partitions créées et affichées"

# Formater la partition EFI
mkfs.fat -F32 "${DISK}1"

### Chiffrement LUKS + LVM ###
echo "Chiffrement de la partition principale..."
echo -n "$LUKS_PASS" | cryptsetup luksFormat --type luks1 --label "cryptlvm" "${DISK}2"
echo "Chiffrement de la partition principale terminé"

# Déverrouillage de la partition chiffrée
echo -n "$LUKS_PASS" | cryptsetup open "${DISK}2" cryptlvm
echo "Ouverture de la partition chiffrée réussie"

### Création des volumes LVM ###
echo "Création des volumes LVM..."
pvcreate /dev/mapper/cryptlvm
vgcreate vg0 /dev/mapper/cryptlvm

lvcreate -L 20G vg0 -n root
lvcreate -L 8G vg0 -n swap
lvcreate -L 35G vg0 -n home
lvcreate -L 10G vg0 -n luks_extra
lvcreate -L 5G vg0 -n shared
lvcreate -L 2G vg0 -n virtualbox

### Formatage des volumes logiques ###
echo "Formatage des volumes logiques..."
mkfs.ext4 /dev/vg0/root
mkfs.ext4 /dev/vg0/home
mkfs.ext4 /dev/vg0/shared
mkfs.ext4 /dev/vg0/virtualbox
mkswap /dev/vg0/swap

### Chiffrement du volume supplémentaire ###
echo "Chiffrement du volume LUKS extra..."
echo -n "$LUKS_PASS" | cryptsetup luksFormat --type luks1 --label "luks_extra" /dev/vg0/luks_extra
echo "Chiffrement du volume LUKS extra terminé"

# Déverrouillage du volume LUKS supplémentaire
echo -n "$LUKS_PASS" | cryptsetup open /dev/vg0/luks_extra luks_manual
echo "Volume LUKS supplémentaire ouvert"

# Formater le volume LUKS supplémentaire
mkfs.ext4 /dev/mapper/luks_manual

### Montage des partitions ###
echo "Montage des partitions..."
mount /dev/vg0/root /mnt
mkdir -p /mnt/{boot,home,shared,virtualbox}
mount "${DISK}1" /mnt/boot
mount /dev/vg0/home /mnt/home
mount /dev/vg0/shared /mnt/shared
mount /dev/vg0/virtualbox /mnt/virtualbox
swapon /dev/vg0/swap

echo "Partitionnement et formatage terminés avec succès."
