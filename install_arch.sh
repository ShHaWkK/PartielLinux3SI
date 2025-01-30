#!/bin/bash

# Si une erreur survient le script va s'arrêter
set -e 


# On vérifie que le script est lancé en root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

#Variables
DISK="/dev/sda"
HOSTNAME="archlinux"
USER1="pere"
USER2="fils"
USER_PASS="azerty123"
LUKS_PASS="azerty123"

echo "Installation d'Arch Linux"
sleep 2

### Partitionnement du disque ###
echo "### Création des partitions ###"

# Création du label GPT
parted -s $DISK mklabel gpt 
echo "Label GPT créé sur $DISK"


# partition de boot ESP
parted -s $DISK mkpart primary fat32 1MiB 513MiB 
echo "Partition de boot créée"

parted -s $DISK set 1 esp on 
echo "Partition de boot définie comme ESP"
# partition racine chiffrée
parted -s $DISK mkpart primary ext4 513MiB 100%
echo "Partition racine créée"

parted -s $DISK print # affiche les partitions
echo "Partitions créées et affichées"

# Formater la partition EFI
mkfs.fat -F32 "${DISK}1"

### Chiffrement LUKS + LVM ###
echo "Chiffrement de la partition principale..."
echo -n "$LUKS_PASS" | cryptsetup luksFormat "${DISK}2" -
echo "Chiffrement de la partition principale terminé"
echo -n "$LUKS_PASS" | cryptsetup open "${DISK}2" cryptlvm -
echo "Ouverture de la partition chiffrée"

# Création des volumes LVM
echo "Création des volumes LVM..."
pvcreate /dev/mapper/cryptlvm
vgcreate vg0 /dev/mapper/cryptlvm
lvcreate -L 20G vg0 -n root
lvcreate -L 8G vg0 -n swap
lvcreate -L 35G vg0 -n home
lvcreate -L 10G vg0 -n luks_extra
lvcreate -L 5G vg0 -n shared
lvcreate -L 2G vg0 -n virtualbox

### Formater les volumes logiques ### 
echo "Formatage des volumes logiques..."
mkfs.ext4 /dev/vg0/root
mkfs.ext4 /dev/vg0/home
mkfs.ext4 /dev/vg0/shared
mkfs.ext4 /dev/vg0/virtualbox
mkswap /dev/vg0/swap