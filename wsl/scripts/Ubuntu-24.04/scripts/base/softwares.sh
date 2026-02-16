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

shopt -s nullglob
   
softwares=("$WORKING_DIR/scripts/softwares/"*/)

if [ ${#softwares[@]} -eq 0 ]; then
    log_message "MSG" "WARN" "Aucun logiciel à installer (répertoire softwares vide)"
else
    # Créer la liste des logiciels disponibles
    for dir in "${softwares[@]}"; do
        software_names+=("$(basename "$dir")")
    done
    
    # Permettre à l'utilisateur de choisir les logiciels à installer
    selected_softwares=$(printf '%s\n' "${software_names[@]}" | gum choose --no-limit --header "Sélectionnez les logiciels à installer :")
    
    if [[ -z "$selected_softwares" ]]; then
        log_message "MSG" "INFO" "Aucun logiciel sélectionné."
        return 0
    fi
    
    # Installer les logiciels sélectionnés
    while IFS= read -r software_name; do
        for dir in "${softwares[@]}"; do
            if [[ "$(basename "$dir")" == "$software_name" ]]; then
                parent_path="$(dirname "$dir")"
                install_software "$software_name" "$parent_path"
                gum input --placeholder "Tapez Entrée pour continuer : "
                break
            fi
        done
    done <<< "$selected_softwares"
fi