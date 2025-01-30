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