#!/bin/bash

# Répertoire racine
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "$BASE_DIR/../../../env" ]] ; then
    gum log --time rfc822 --level fatal "Le fichier env est absent !"
    exit 1
fi
source "$BASE_DIR/../../../env"
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

software_path="/usr/bin/jq"
log_message "STEP" "" "Installation de jq"
if [[ $(isInstalled "$software_path") == 0 ]]; then
    log_message "MSG" "INFO" "Déjà fait"
    exit 0
fi

if ! install_jq; then
    log_message "MSG" "ERROR" "Installation de jq KO."
else
    log_message "MSG" "SUCCESS" "Installation de jq OK"
fi
