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
