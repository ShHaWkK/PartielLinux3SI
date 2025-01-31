# **Comparaison détaillée des scripts d’installation d’Arch Linux**  
## **Version 1 (`install_arch.sh`) vs Version 2 (`install_arch_ver2.sh`)**  

---

## **1. Introduction**  
Ce document compare deux versions d’un script d’installation automatisé d’Arch Linux, en mettant en évidence les différences et les améliorations apportées dans la **version 2**. Ces scripts installent Arch Linux sur un disque chiffré avec **LUKS + LVM**, en respectant les spécifications demandées.

---

## **2. Principales améliorations et corrections**
| **Catégorie** | **Version 1 (`install_arch.sh`)** | **Version 2 (`install_arch_ver2.sh`)** | **Améliorations** |
|--------------|----------------------------------|----------------------------------|-------------------|
| **Langue des messages** | Mélange de français et anglais (`Please run as root`) | Français uniformisé | Plus de cohérence |
| **Gestion des erreurs** | `set -e` activé | `set -e` activé + amélioration des messages d’erreur | Meilleure robustesse |
| **Vérification root** | `if [ "$EUID" -ne 0 ] then echo "Please run as root"` | `if [ "$EUID" -ne 0 ]; then echo "Veuillez exécuter ce script en tant que root."; exit 1; fi` | Message plus clair et en français |
| **Création de la partition racine** | `parted -s $DISK mkpart primary ext4 513MiB 100%` | `parted -s "$DISK" mkpart primary 513MiB 100%` | Suppression du type `ext4` (inutile avant LUKS) |
| **Chiffrement LUKS principal** | `cryptsetup luksFormat "${DISK}2" -` | `cryptsetup luksFormat --type luks1 --label "cryptlvm" "${DISK}2"` | Ajout d’un label pour faciliter l’identification |
| **Ouverture du volume LUKS** | `cryptsetup open "${DISK}2" cryptlvm -` | `cryptsetup open "${DISK}2" cryptlvm` | Suppression du `-` incorrect |
| **Erreur de frappe dans le chiffrement du volume supplémentaire** | `"Chiffrement du volume LUCKS extra..."` | `"Chiffrement du volume LUKS extra..."` | Correction de la faute `"LUCKS"` → `"LUKS"` |
| **Label du volume LUKS supplémentaire** | Absent | `cryptsetup luksFormat --type luks1 --label "luks_extra" /dev/vg0/luks_extra` | Ajout d’un label |
| **Formatage du volume LUKS supplémentaire** | Oublié | `mkfs.ext4 /dev/mapper/luks_manual` | Correction d’un oubli critique |
| **Ordre et clarté des messages** | Voir analyse détaillée ci-dessous | Messages plus clairs et logiques | Meilleure UX |
| **Point de montage VirtualBox** | Indéfini | Ajout clair `/mnt/virtualbox` | Meilleure conformité avec les exigences |

---

## **3. Analyse détaillée des corrections et améliorations**
### **3.1 Ordre et clarté des messages**
Dans **la version 1**, les messages d’affichage du script manquent de clarté et ne suivent pas un ordre logique, ce qui peut compliquer le débogage.  

Exemple dans la **version 1** :
```bash
echo "Chiffrement du volume LUCKS extra..."
echo -n "$LUKS_PASS" | cryptsetup luksFormat /dev/vg0/luks_extra -
echo "Chiffrement du volume LUCKS extra terminé"
echo "Ouverture du volume chiffré"
echo -n "$LUKS_PASS" | cryptsetup open /dev/vg0/luks_extra luks_manual -
echo "Volume chiffré ouvert"
```
🔴 **Problèmes** :
- Le terme `"LUCKS"` est une faute de frappe qui nuit à la compréhension.
- L’ordre des messages **n’est pas optimal** : l’ouverture du volume est mentionnée **avant même d’avoir précisé que le chiffrement est terminé**.
- Absence de retour utilisateur après l’ouverture du volume.

✅ **Correction dans la version 2** :
```bash
echo "Chiffrement du volume LUKS extra..."
echo -n "$LUKS_PASS" | cryptsetup luksFormat --type luks1 --label "luks_extra" /dev/vg0/luks_extra
echo "Chiffrement du volume LUKS extra terminé"

echo "Déverrouillage du volume chiffré..."
echo -n "$LUKS_PASS" | cryptsetup open /dev/vg0/luks_extra luks_manual
echo "Volume LUKS supplémentaire ouvert avec succès"

echo "Formatage du volume chiffré..."
mkfs.ext4 /dev/mapper/luks_manual
echo "Formatage terminé"
```
**Améliorations :**
✅ Correction de `"LUCKS"` → `"LUKS"`.  
✅ Ajout d’une meilleure **progression logique** dans l'affichage des messages.  
✅ Ajout de `"Déverrouillage du volume chiffré..."` avant `"Volume LUKS ouvert"`.  
✅ Ajout du formatage du volume chiffré, qui était absent dans la version 1.  

---

### **3.2 Point de montage VirtualBox**
La spécification exige un volume logique dédié à **VirtualBox**, mais la **version 1** ne définit pas clairement son point de montage.  

🔴 **Problème dans la version 1** :
```bash
lvcreate -L 2G vg0 -n virtualbox
mkfs.ext4 /dev/vg0/virtualbox
```
➡ **Le script crée bien le volume, mais ne le monte nulle part**, ce qui **rend l’espace inutilisable après l’installation**.  

✅ **Correction dans la version 2** :
```bash
echo "Création du volume pour VirtualBox..."
lvcreate -L 2G vg0 -n virtualbox
mkfs.ext4 /dev/vg0/virtualbox
echo "Volume VirtualBox formaté"

echo "Montage du volume VirtualBox..."
mkdir -p /mnt/virtualbox
mount /dev/vg0/virtualbox /mnt/virtualbox
echo "Volume VirtualBox monté dans /mnt/virtualbox"
```
**Améliorations :**
✅ Ajout explicite du **point de montage `/mnt/virtualbox`**.  
✅ **Messages plus clairs** expliquant la création, le formatage et le montage du volume.  
✅ **Conformité totale avec les exigences du sujet.**  

---

## **4. Conclusion**
La **version 2 du script (`install_arch_ver2.sh`)** apporte plusieurs **corrections critiques et des améliorations de lisibilité** :

🎯 **Clarté et lisibilité**  
✔️ Les messages sont plus **clairs**, **logiques**, et **dans le bon ordre**.  
✔️ Suppression d'erreurs de frappe (`LUCKS` → `LUKS`).  

🎯 **Correction de bugs et conformité**  
✔️ **Ajout du point de montage VirtualBox** pour éviter un espace inutilisable.  
✔️ **Correction du formatage du volume `luks_extra`**, qui était absent.  

🎯 **Meilleure gestion du chiffrement LUKS**  
✔️ Ajout de **labels (`cryptlvm`, `luks_extra`)** pour identifier facilement les volumes.  

🚀 **🆕 Recommandation :** Utiliser **install_arch_ver2.sh**, qui est plus stable et conforme aux exigences.

Voici un extrait en **Markdown** expliquant en détail la correction apportée au **formatage du volume LUKS supplémentaire**, qui était oublié dans la première version du script.  

---

## 🛠 Correction du formatage du volume LUKS supplémentaire

### 🔴 Problème dans la version 1
Dans **install_arch.sh**, un volume logique supplémentaire (`luks_extra`) est créé et chiffré avec **LUKS**. Cependant, une **étape critique est manquante** :  
➡ **Le volume n'est pas formaté après son ouverture**, ce qui le rend inutilisable.

Extrait du code de la **version 1** :
```bash
echo "Chiffrement du volume LUKS extra..."
echo -n "$LUKS_PASS" | cryptsetup luksFormat /dev/vg0/luks_extra -
echo "Chiffrement du volume LUKS extra terminé"

echo "Ouverture du volume chiffré"
echo -n "$LUKS_PASS" | cryptsetup open /dev/vg0/luks_extra luks_manual -
echo "Volume chiffré ouvert"
```
### ⚠️ Problèmes :
1. **Le volume `luks_manual` est bien déverrouillé mais jamais formaté**  
   🔹 Sans formatage, il **ne peut pas être monté et utilisé** après l’installation.  
2. **Absence de feedback clair pour l'utilisateur**  
   🔹 Un message confirmant le formatage aurait permis de **mieux suivre la progression du script**.  

---

### ✅ Correction dans la version 2
Dans **install_arch_ver2.sh**, on ajoute une **étape de formatage** après l'ouverture du volume **LUKS**.

Extrait du **code corrigé** :
```bash
echo "Chiffrement du volume LUKS extra..."
echo -n "$LUKS_PASS" | cryptsetup luksFormat --type luks1 --label "luks_extra" /dev/vg0/luks_extra
echo "Chiffrement du volume LUKS extra terminé"

echo "Déverrouillage du volume chiffré..."
echo -n "$LUKS_PASS" | cryptsetup open /dev/vg0/luks_extra luks_manual
echo "Volume LUKS supplémentaire ouvert avec succès"

echo "Formatage du volume chiffré..."
mkfs.ext4 /dev/mapper/luks_manual
echo "Formatage terminé"
```
### 🚀 Améliorations :
✔ **Ajout de la commande `mkfs.ext4 /dev/mapper/luks_manual`** pour rendre le volume utilisable.  
✔ **Clarification des messages** pour une meilleure compréhension du processus.  
✔ **Correction complète du problème**, garantissant que l’utilisateur puisse **monter et utiliser** l’espace chiffré après l’installation.

---

### 🎯 Conclusion
Cette correction **évite un problème majeur** qui aurait empêché l’utilisation du volume supplémentaire après l’installation d’Arch Linux. **Avec cette amélioration, le script assure une installation complète et fonctionnelle**. 🎉  

---
