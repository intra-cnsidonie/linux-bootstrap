#!/bin/bash

if [[ ! -f "/usr/bin/gum" ]]; then
    echo "Installation de gum"
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
    sudo apt update && sudo apt install gum
    if [ $? -ne 0 ]; then
        echo "Erreur lors de l'installation de gum. Veuillez vérifier votre connexion Internet et les sources de paquets."
        exit 1
    fi
fi

gum style --border normal --width 100 --margin "1" --padding "1 2" --border-foreground 212 "Script de configuration de base du poste de travail WSL !"
gum input --placeholder "Tapez Entrée pour démarrer la procédure : "

# Lancement du script de configuration de base
./scripts/base/setup.sh

gum input --placeholder "Tapez Entrée pour continuer : "

clear
# Map associative pour suivre les logiciels déjà traités
declare -A installed_software

# Lancement du script d'installation des logiciels
gum style --border normal --width 100 --margin "1" --padding "1 2" --border-foreground 212 "Installation des logiciels pour le poste de travail WSL !"
gum confirm "Souhaitez-vous exécuter cette action ?"
CR=$?
if [ "${CR}" -eq 0 ] ; then
    ./scripts/base/softwares.sh
fi

gum input --placeholder "Tapez Entrée pour continuer : "

clear

log_message "STEP" "1" "Configuration du poste de travail WSL terminée"