#!/bin/bash


software_path="/usr/bin/zsh"
log_message "STEP" "" "Installation de ${software_name}"
if [[ $(isInstalled "$software_path") == 0 ]]; then
    log_message "MSG" "INFO" "Déjà fait"
    exit 0
fi

if ! install_zsh; then
    log_message "MSG" "ERROR" "Installation de zsh KO."
else
    log_message "MSG" "SUCCESS" "Installation de zsh OK"
    if ! configure_zsh; then
        log_message "MSG" "ERROR" "Configuration de zsh KO."
    else
        log_message "MSG" "SUCCESS" "Configuration de zsh OK"
    fi
fi
