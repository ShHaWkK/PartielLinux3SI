# Il me faut impérativement un espace chiffré que je dois monter à la main, sait-on jamais ! [...] Un bon
# 10G minimum ferait pas de mal, je pense.

cat <<EOF > /home/$USER1/mount_lucks_extra.sh

#!/bin/bash

echo -n " Entrer le mot de passe du LUCKS : "
read -s LUKS_PASS
echo 
cryptsetup luksOpen /dev/vg0/luks_extra lucks_extra_manual
mount /dev/mapper/lucks_extra_manual /mnt
echo "Le volume LUKS extra a été monté dans /mnt"
EOF

chmod +x /home/$USER1/mount_lucks_extra.sh
chmod +x /home/$USER1/mount_lucks_extra.sh