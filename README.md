# **Installation automatisée d'Arch Linux**

## **Contexte**
Dans ce projet, nous avons développé un script d’installation entièrement automatisé pour Arch Linux.  
L’objectif principal était de répondre à des besoins spécifiques d’un utilisateur tout en rendant le processus de configuration autonome et prêt à l’emploi.

Le script configure automatiquement :
- Le partitionnement du disque dur avec **LUKS (chiffrement)** et **LVM**.
- Un système avec plusieurs partitions logiques adaptées à des besoins spécifiques : utilisateur principal, virtualisation, stockage partagé, etc.
- L’installation de **Hyprland**, des outils essentiels et un environnement complet, prêt à l’emploi.

---

## **Ce que nous avons fait**

### **Analyse des besoins**
Nous avons pris en compte les spécifications suivantes fournies par le sujet :
- **Disque dur** : 80 Go, chiffré avec **LUKS**.
- **RAM** : 8 Go.
- **CPU** : 4 cœurs minimum.
- **UEFI** : Obligatoire (système configuré en mode EFI).
- **Utilisateurs** :
  - `pere` : Administrateur (avec droits sudo).
  - `fils` : Utilisateur standard pour suivre des tutoriels en C.
- **Stockage dédié** :
  - 10 Go pour un volume manuel chiffré.
  - 5 Go pour un dossier partagé entre `pere` et `fils`.
  - 2 Go pour la virtualisation avec VirtualBox.
- **Logiciels installés** :
  - Environnement graphique **Hyprland** (configuration de base pour ricing).
  - Outils essentiels : `vim`, `nano`, `firefox`, `virtualbox`, etc.

---

### **Étapes réalisées**
#### **Partitionnement du disque**
- Création d’une table de partition GPT.
- Configuration de :
  - Une partition EFI (512 Mo) pour le boot en mode UEFI.
  - Une partition principale chiffrée avec **LUKS** pour la sécurité des données.
- Utilisation de **LVM** pour créer les volumes logiques nécessaires :
  - `root` : 20 Go.
  - `swap` : 8 Go.
  - `home` : 35 Go.
  - `shared` : 5 Go (dossier partagé).
  - `virtualbox` : 2 Go (virtualisation).
  - `luks_extra` : 10 Go (volume manuel chiffré à monter par l'utilisateur).

#### **Installation de base**
- Installation des paquets essentiels via `pacstrap` :
  - `base`, `linux`, `linux-firmware`, `lvm2`, etc.
- Génération du fichier `/etc/fstab`.

#### **configuration système**
- Configuration des paramètres de base :
  - Nom d’hôte : `archlinux`.
  - Localisation (langue, fuseau horaire, clavier).
- Création des utilisateurs :
  - `pere` (admin avec sudo).
  - `fils` (utilisateur standard).
- Configuration des droits sur le dossier partagé (`/mnt/shared`).

#### **Installation de logiciels**
- Environnement graphique : **Hyprland** avec Wayland.
- Logiciels : `firefox`, `nano`, `vim`, `alacritty`, `virtualbox`, etc.
- Configuration de GRUB pour le boot avec LUKS + LVM.

#### **Chiffrement manuel**
- Création d’un volume logique supplémentaire chiffré (`luks_extra`) à monter manuellement.

---

## **Comment tester le projet**
### **Préparation de l’environnement**
- **Créer une VM** avec VirtualBox ou tout autre outil de virtualisation :
  - Disque dur : 80 Go.
  - RAM : 8 Go.
  - CPU : 4 cœurs.
  - Activer UEFI (EFI activé dans les paramètres de la VM).
- **Télécharger l’ISO Arch Linux** depuis [archlinux.org](https://archlinux.org/download/).

# Vérifications après installation

Après redémarrage de la machine, vérifiez les éléments suivants :
- Connexion utilisateur : Connectez-vous en tant que pere ou fils (mot de passe : azerty123).
- Partitionnement : Confirmez que les partitions sont correctement montées avec lsblk.
- Environnement graphique :
- Lancez Hyprland avec startx (ou configurez SDDM pour le démarrage automatique).
- Logiciels :
- Vérifiez que les outils demandés (ex. : firefox, virtualbox) sont installés.

## Résultats attendus
Dans le dossier rendu et dans images. 