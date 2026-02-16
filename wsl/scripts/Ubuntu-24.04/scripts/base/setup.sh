#!/bin/bash

# Répertoire racine
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "$BASE_DIR/../../env" ]] ; then
    gum log --time rfc822 --level fatal "Le fichier env est absent !"
    exit 1
fi
source "$BASE_DIR/../../env"
if [[ ! -d "$COMMON_LIBS_PATH" ]] ; then
    gum log --time rfc822 --level fatal "Le répertoire $COMMON_LIBS_PATH est absent !"
    exit 1
fi
# Sourcer tous les scripts dans common_libs
for script in "$COMMON_LIBS_PATH"/*.sh; do
    if [[ -f "$script" ]]; then
        source "$script"
    fi
done

## Lancement de la configuration minimale ##
############################################

# Configuration du hostname via /etc/wsl.conf
configure_wsl_hostname

## Lancement de la configuration avancée ##
###########################################

# Map associative pour suivre les logiciels déjà traités
declare -A installed_software