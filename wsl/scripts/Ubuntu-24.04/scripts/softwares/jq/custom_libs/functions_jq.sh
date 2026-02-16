#!/bin/bash

isInstalled() {
    local software_path="$1"
    if [[ -f "$software_path" ]]; then
        echo 0
        return
    fi
    echo 1
    return
}

install_jq() {
    if [[ -n "${installed_software["jq"]}" ]]; then
        log_message "INFO" "" "jq est déjà installé, passage à l'étape suivante."
        return
    fi

    log_message "INFO" "" "Installation de jq..."
    
    COMMANDS=(
    "sudo apt-get update"
    "sudo apt-get install -y jq"
    )

    if ! run_commands "$ERROR_LOG" "${COMMANDS[@]}"; then
        log_message "ERROR" "" "L'installation de jq a échoué !"
        return 1
    else
        log_message "OK" "3" "Installation de jq OK"
    fi
    installed_software["jq"]=1
}
