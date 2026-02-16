#!/bin/bash

install_zsh() {
    if [[ -n "${installed_software["zsh"]}" ]]; then
        log_message "INFO" "" "zsh est déjà installé, passage à l'étape suivante."
        return
    fi

    log_message "INFO" "" "Installation de zsh..."
    
    COMMANDS=(
    "sudo apt-get install -y zsh >/dev/null"
    )


    if ! run_commands "$ERROR_LOG" "${COMMANDS[@]}"; then
        log_message "ERROR" "" "L'installation de zsh a échoué !"
        return 1
    else
        log_message "OK" "3" "Installation de zsh OK"
    fi
    installed_software["zsh"]=1
}

# Installation de Oh My Zsh (idempotent)
install_ohmyzsh() {
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        log_message "MSG" "INFO" "Oh My Zsh est déjà installé."
        return 0
    fi

    log_message "MSG" "INFO" "Installation de Oh My Zsh..."
    if ! sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended >/dev/null 2>>"${ERROR_LOG}"; then
        log_message "MSG" "ERROR" "L'installation de Oh My Zsh a échoué !"
        return 1
    fi
    
    log_message "MSG" "SUCCESS" "Oh My Zsh installé avec succès."
    return 0
}

# Installation de Powerlevel10k (idempotent)
install_powerlevel10k() {
    local P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    
    if [[ -d "$P10K_DIR" ]]; then
        log_message "MSG" "INFO" "Powerlevel10k est déjà installé."
        return 0
    fi

    log_message "MSG" "INFO" "Installation de Powerlevel10k..."
    
    # Installer Oh My Zsh si pas déjà fait
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        install_ohmyzsh || return 1
    fi
    
    if ! git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR" >/dev/null 2>>"${ERROR_LOG}"; then
        log_message "MSG" "ERROR" "L'installation de Powerlevel10k a échoué !"
        return 1
    fi
    
    # Configurer le thème dans .zshrc
    if [[ -f "$HOME/.zshrc" ]]; then
        sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$HOME/.zshrc"
        log_message "MSG" "SUCCESS" "Powerlevel10k installé et configuré."
    fi
    
    return 0
}

# Installation de Zinit (idempotent)
install_zinit() {
    local ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
    
    if [[ -d "$ZINIT_HOME" ]]; then
        log_message "MSG" "INFO" "Zinit est déjà installé."
        return 0
    fi

    log_message "MSG" "INFO" "Installation de Zinit..."
    
    if ! mkdir -p "$(dirname $ZINIT_HOME)" >/dev/null 2>>"${ERROR_LOG}"; then
        log_message "MSG" "ERROR" "Impossible de créer le répertoire Zinit !"
        return 1
    fi
    
    if ! git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME" >/dev/null 2>>"${ERROR_LOG}"; then
        log_message "MSG" "ERROR" "L'installation de Zinit a échoué !"
        return 1
    fi
    
    # Ajouter la configuration dans .zshrc si pas déjà présent
    if [[ -f "$HOME/.zshrc" ]] && ! grep -q "zinit.git/zinit.zsh" "$HOME/.zshrc"; then
        cat >> "$HOME/.zshrc" << 'EOF'

### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit
EOF
    fi
    
    log_message "MSG" "SUCCESS" "Zinit installé avec succès."
    return 0
}

# Installation de Starship (idempotent)
install_starship() {
    if command -v starship &> /dev/null; then
        log_message "MSG" "INFO" "Starship est déjà installé."
        return 0
    fi

    log_message "MSG" "INFO" "Installation de Starship..."
    
    if ! curl -sS https://starship.rs/install.sh | sh -s -- -y >/dev/null 2>>"${ERROR_LOG}"; then
        log_message "MSG" "ERROR" "L'installation de Starship a échoué !"
        return 1
    fi
    
    # Ajouter la configuration dans .zshrc si pas déjà présent
    if [[ -f "$HOME/.zshrc" ]] && ! grep -q 'eval "$(starship init zsh)"' "$HOME/.zshrc"; then
        echo 'eval "$(starship init zsh)"' >> "$HOME/.zshrc"
    fi
    
    # Créer une configuration par défaut si elle n'existe pas
    if [[ ! -f "$HOME/.config/starship.toml" ]]; then
        mkdir -p "$HOME/.config"
        starship preset nerd-font-symbols -o "$HOME/.config/starship.toml" 2>/dev/null || true
    fi
    
    log_message "MSG" "SUCCESS" "Starship installé avec succès."
    return 0
}

# Fonction principale de configuration de zsh
configure_zsh() {
    log_message "STEP" "" "Configuration de zsh"
    
    # Proposer les choix à l'utilisateur
    gum style --border normal --width 70 --margin "1" --padding "1 2" --border-foreground 212 \
        "Choisissez vos outils de configuration Zsh" \
        "" \
        "• Oh My Zsh : Framework complet avec plugins" \
        "• Powerlevel10k : Thème rapide et moderne (nécessite Oh My Zsh)" \
        "• Zinit : Plugin manager léger et rapide" \
        "• Starship : Prompt cross-shell minimaliste (Rust)"
    
    # Utiliser gum choose avec multi-select
    local choices
    choices=$(gum choose --no-limit \
        "Oh My Zsh" \
        "Powerlevel10k (nécessite Oh My Zsh)" \
        "Zinit" \
        "Starship" \
        "Aucune configuration personnalisée")
    
    if [[ -z "$choices" ]] || [[ "$choices" == "Aucune configuration personnalisée" ]]; then
        log_message "MSG" "INFO" "Aucune configuration sélectionnée."
        return 0
    fi
    
    # Installer les outils sélectionnés
    while IFS= read -r choice; do
        case "$choice" in
            "Oh My Zsh")
                install_ohmyzsh
                ;;
            "Powerlevel10k (nécessite Oh My Zsh)")
                install_powerlevel10k
                ;;
            "Zinit")
                install_zinit
                ;;
            "Starship")
                install_starship
                ;;
        esac
    done <<< "$choices"
    
    log_message "MSG" "SUCCESS" "Configuration de zsh terminée."
    log_message "MSG" "INFO" "Redémarrez votre shell pour appliquer les changements : exec zsh"
}