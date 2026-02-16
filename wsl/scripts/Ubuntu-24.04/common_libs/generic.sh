#!/bin/bash

# Fonction de log
# log_message <type> <level> <message>
# type: STEP, MSG
# level : SUCCESS, INFO, WARN, ERROR, CRIT, DEBUG
log_message() {
    local type="$1"
    local level="$2"
    local message="$3"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    # Définir la couleur selon le level
    local color_reset="\033[0m"
    local color_success="\033[1;32m"   # Vert
    local color_info="\033[1;34m"     # Bleu
    local color_warn="\033[1;33m"     # Jaune
    local color_error="\033[1;31m"    # Rouge
    local color_crit="\033[1;41m"     # Rouge fond blanc
    local color_debug="\033[1;36m"    # Cyan
    local color_step="\033[1;44m"     # Blanc fond bleu

    local color=""
    case "$level" in
        SUCCESS) color="$color_success" ;;
        INFO) color="$color_info" ;;
        WARN) color="$color_warn" ;;
        ERROR) color="$color_error" ;;
        CRIT) color="$color_crit" ;;
        DEBUG) color="$color_debug" ;;
        *) color="$color_reset" ;;
    esac
    case $"type" in
        STEP) color="$color_step" ;;
        *) ;;
    esac    
    local prefix=""
    local suffix=""
    case "$type" in
	    STEP) prefix="#####" ; suffix="#####" ;;
	    *) prefix="    " ; suffix="" ;;
    esac

    # Affichage coloré à l'écran
    echo -e "[$timestamp] ${color}[$type] $prefix $message $suffix${color_reset}"

    # Écriture sans couleur dans le fichier log
    echo "[$timestamp] [$type] $prefix $message $suffix" >> "$LOG_FILE"
}

# Mise à jour des alias dans le fichier .aliases
# update_alias <name> <command>
update_alias() {
    local alias_name="$1"
    local alias_command="$2"
    local alias_file="$HOME/.aliases"

    # Créer le fichier s'il n'existe pas
    if [ ! -f "$alias_file" ]; then
        touch "$alias_file"
    fi

    # Vérifier si l'alias existe déjà
    if ! grep -q "^alias $alias_name=" "$alias_file"; then
        echo "alias $alias_name='$alias_command'" >> "$alias_file"
        log_message "MSG" "SUCCESS" "Alias ajouté : $alias_name -> $alias_command"
    else
        log_message "MSG" "INFO" "Alias '$alias_name' déjà présent, aucune modification effectuée."
    fi
}

# Mise à jour des variables dans le fichier .variables
# update_vars <name> <command>
update_vars() {
    local vars_name="$1"
    local vars_command="$2"
    local vars_file="$HOME/.variables"

    # Créer le fichier s'il n'existe pas
    if [ ! -f "$vars_file" ]; then
        touch "$vars_file"
    fi

    # Vérifier si la variable existe déjà
    if ! grep -q "^export $vars_name=" "$vars_file"; then
        echo "export $vars_name='$vars_command'" >>"$vars_file"
        log_message "MSG" "SUCCESS" "Variable ajoutée : $vars_name -> $vars_command"
    else
        log_message "MSG" "INFO" "Variable '$vars_name' déjà présente, aucune modification effectuée."
    fi
}

# Exécution de commandes avec gestion des erreurs
# run_commands <error_log_file> <commandes[@]>
run_commands() {
    local error_log="$1"
    shift
    local commands=("$@")

    # Nettoyer le fichier d'erreur
    > "$error_log"

    for cmd in "${commands[@]}"; do
        eval "$cmd" > /dev/null 2>>"$error_log"
        local status=$?
        if [[ $status -ne 0 ]]; then
            log_message "MSG" "ERROR" "La commande '$cmd' a échoué avec le code $status. Erreur : "
	        cat "$error_log"
            return 1
        fi
    done

    return 0
}

# Installation d'un logiciel
# install_software <software_name> <software_dir>
install_software() {
    local software_name="$1"
    local software_dir="$2"

    log_message "STEP" "" "Installation de ${software_name}"

    gum confirm "Souhaitez-vous installer ${software_name} ?"
    if [ $? -ne 0 ]; then
        log_message "MSG" "INFO" "Installation de ${software_name} ignorée par l'utilisateur"
        return
    fi

    # Détection de cycle
    if [[ "${installed_software[$software_name]}" == "in_progress" ]]; then
        log_message "MSG" "WARN" "Cycle détecté : $software_name est déjà en cours d'installation. Ignoré."
        return
    fi

    # Si déjà installé, on saute
    if [[ "${installed_software[$software_name]}" == "done" ]]; then
        return
    fi

    if [ ! -d "$software_dir/$software_name/$OS" ]; then
        log_message "MSG" "ERROR" "Répertoire $software_dir/$software_name/$OS introuvable, logiciel ignoré."
        return
    fi

    log_message "MSG" "INFO" "Installation de $software_name"
    installed_software["$software_name"]="in_progress"

    # on source les fonctions si existantes
    if [ -d "$software_dir/$software_name/custom_libs" ]; then
        log_message "MSG" "INFO" "Sourcing des fonctions dédiées à $software_name"
        for func_file in "$software_dir/$software_name/custom_libs"/*; do
            [ -f "$func_file" ] && source "$func_file"
        done
    fi

    # Dépendances
    log_message "MSG" "INFO" "Recherche des dépendances"
    if [ -f "$software_dir/$software_name/dependencies" ]; then
        while IFS= read -r dep; do
            local dep_dir="$software_dir/$dep"
            if [ -d "$dep_dir" ]; then
                install_software "$dep" "$dep_dir"
            else
                log_message "MSG" "ERROR" "Dépendance $dep ignorée : répertoire $dep_dir introuvable."
            fi
        done < "$software_dir/$software_name/dependencies"
    fi

    # install.sh
    if [ -f "$software_dir/$software_name/install.sh" ]; then
        log_message "MSG" "INFO" "Exécution de install.sh"
        bash "$software_dir/$software_name/install.sh"
        local exit_code=$?
        if [ $exit_code -eq 0 ]; then
            log_message "MSG" "SUCCESS" "install.sh terminé avec succès (code $exit_code)"
        else
            log_message "MSG" "ERROR" "install.sh a échoué (code $exit_code)"
        fi
    fi

    # alias
    if [ -f "$software_dir/$software_name/alias" ]; then
        log_message "MSG" "INFO" "Ajout des alias"
        while IFS= read -r alias_line; do
            alias_def="${alias_line#alias }"
            nom_alias="${alias_def%%=*}"
            commande_alias="${alias_def#*=}"

	    update_alias "${nom_alias}" "${commande_alias}"
        done < "$software_dir/$software_name/alias"
    fi

    # variables
    if [ -f "$software_dir/$software_name/variables" ]; then
        log_message "MSG" "INFO" "Ajout des variables"
        while IFS= read -r vars_line; do
            vars_def="${vars_line#export }"
            var="${vars_def%%=*}"
            value="${vars_def#*=}"

	    update_vars "${var}" "${value}"
        done < "$software_dir/$software_name/variables"
    fi

    # dotfiles
    if [ -d "$software_dir/$software_name/dotfiles" ]; then
        log_message "MSG" "INFO" "Ajout des dotfiles"
        config_file="$software_dir/$software_name/dotfiles/config.txt"
        if [ -f "$config_file" ]; then
	    src="$software_dir/$software_name//dotfiles/config"
	    if [ ! -d "$src" ] ; then
                log_message "MSG" "ERROR" "Aucun fichiers de config présents"
		continue
            fi
            while IFS= read -r raw_path || [ -n "$raw_path" ]; do
                expanded_path=$(echo "$raw_path" | envsubst)
                # Vérification de sécurité : le chemin doit être absolu
                if [[ "$expanded_path" == /* ]]; then
	            dest_dir=$(dirname "$expanded_path")
                    if [ ! -d "$dest_dir" ]; then
                        if ! mkdir -p "$dest_dir"; then
                            log_message "MSG" "ERROR" "Impossible de créer le répertoire '$dest_dir'."
                            continue
                        fi
                    fi
                    if cp -r "${src}" "$expanded_path"; then
                        log_message "MSG" "INFO" "Copie réussie vers : $expanded_path"
                    else
                        log_message "MSG" "ERROR" "Erreur lors de la copie vers : $expanded_path"
                    fi
                else
	            log_message "MSG" "ERROR" "Chemin non valide ou potentiellement dangereux : $expanded_path"
		fi
            done < "$config_file"
        fi
    fi

    installed_software["$software_name"]="done"
}

# Exécution des scripts personnalisés
# run_custom <custom_scripts_directory>
run_custom() {
    log_message "STEP" "" "Exécution des scripts personnalisés"

    local custom_dir="$1"

    # Vérifie si le répertoire custom existe
    if [ ! -d "$custom_dir" ]; then
        log_message "MSG" "WARN" "Le répertoire '$custom_dir' n'existe pas. Aucun script personnalisé à exécuter."
        return
    fi

    # Vérifie s'il y a des fichiers .sh dans le répertoire
    sh_files=("$custom_dir"/*.sh)
    if [ ! -e "${sh_files[0]}" ]; then
        log_message "MSG" "WARN" "Aucun script .sh trouvé dans '$custom_dir'."
        return
    fi

    # Exécution des scripts
    for script in "${sh_files[@]}"; do
        log_message "MSG" "INFO" "-> Exécution de $script"
        bash "$script"
    done
}

# Ajout d'une commande à un fichier sudoers
# add_command_to_sudoers <command> <sudoers_file>
add_command_to_sudoers() {
    local cmd="$1"
    local sudoers_file="$2"

    # Vérifie si la commande est déjà présente
    if sudo grep -qF "$cmd" "$sudoers_file" 2>/dev/null; then
        return
    fi

    # Ajoute la commande au fichier sudoers
    echo "$cmd" | sudo tee -a "$sudoers_file" > /dev/null
    if [ $? -eq 0 ]; then
        log_message "MSG" "SUCCESS" "Commande '$cmd' ajoutée à $sudoers_file."
    else
        log_message "MSG" "ERROR" "Échec de l'ajout de la commande '$cmd' à $sudoers_file."
    fi
}

# Création des fichiers de variables d'environnement et d'alias
# create_shell_dotfiles <shell>
create_shell_dotfiles() {
    local shell="$1"
    case "$shell" in
        bash)
            local shell_rc="$HOME/.bashrc"
            ;;
        zsh)
            local shell_rc="$HOME/.zshrc"
            ;;
        *)
            log_message "MSG" "ERROR" "Shell non supporté : $shell"
            return 1
            ;;
    esac
    log_message "MSG" "INFO" "Création des fichiers de variables d'environnement et d'alias"

    # Création du fichier .aliases
    if [ ! -f "$HOME/.aliases" ]; then
        cat > "$HOME/.aliases" << 'EOF'
# Fichier d'alias personnalisés
# Ce fichier est automatiquement sourcé par $shell_rc

EOF
        log_message "MSG" "SUCCESS" "Fichier $HOME/.aliases créé"
    fi

    # Création du fichier .variables
    if [ ! -f "$HOME/.variables" ]; then
        cat > "$HOME/.variables" << 'EOF'
# Fichier de variables d'environnement personnalisées
# Ce fichier est automatiquement sourcé par $shell_rc

EOF
        log_message "MSG" "SUCCESS" "Fichier $HOME/.variables créé"
    fi

    # Ajout du sourcing dans $shell_rc pour .aliases
    if ! grep -q "source ~/.aliases" "$shell_rc" && ! grep -q ". ~/.aliases" "$shell_rc"; then
        echo "" >> "$shell_rc"
        echo "# Source des alias personnalisés" >> "$shell_rc"
        echo "if [ -f ~/.aliases ]; then" >> "$shell_rc"
        echo "    . ~/.aliases" >> "$shell_rc"
        echo "fi" >> "$shell_rc"
        log_message "MSG" "SUCCESS" "Sourcing de ~/.aliases ajouté à $shell_rc"
    fi

    # Ajout du sourcing dans $shell_rc pour .variables
    if ! grep -q "source ~/.variables" "$shell_rc" && ! grep -q ". ~/.variables" "$shell_rc"; then
        echo "" >> "$shell_rc"
        echo "# Source des variables d'environnement personnalisées" >> "$shell_rc"
        echo "if [ -f ~/.variables ]; then" >> "$shell_rc"
        echo "    . ~/.variables" >> "$shell_rc"
        echo "fi" >> "$shell_rc"
        log_message "MSG" "SUCCESS" "Sourcing de ~/.variables ajouté à $shell_rc"
    fi

    log_message "MSG" "SUCCESS" "Fichiers d'environnement configurés avec succès"
}

# Fonction pour configurer le hostname via /etc/wsl.conf
# configure_wsl_hostname
configure_wsl_hostname() {
    log_message "STEP" "" "Configuration du hostname via /etc/wsl.conf"
    
    # Vérifier que WSL_DISTRO_NAME est défini
    if [[ -n "$WSL_DISTRO_NAME" ]]; then
        local WSL_CONF_FILE="/etc/wsl.conf"
        # Remplacer les points par des tirets pour éviter l'interprétation FQDN
        local HOSTNAME_VALUE="${WSL_DISTRO_NAME//./-}"
        
        # Créer le fichier wsl.conf s'il n'existe pas
        if [[ ! -f "$WSL_CONF_FILE" ]]; then
            log_message "MSG" "INFO" "Création du fichier $WSL_CONF_FILE"
            sudo tee "$WSL_CONF_FILE" > /dev/null << EOF
[network]
hostname = $HOSTNAME_VALUE
EOF
            log_message "MSG" "SUCCESS" "Hostname configuré: $HOSTNAME_VALUE"
        else
            # Vérifier si la section [network] existe
            if grep -q "^\[network\]" "$WSL_CONF_FILE"; then
                # Vérifier si hostname est déjà configuré
                if grep -q "^hostname\s*=" "$WSL_CONF_FILE"; then
                    # Vérifier si c'est la bonne valeur
                    local current_hostname=$(grep "^hostname\s*=" "$WSL_CONF_FILE" | sed 's/hostname\s*=\s*//')
                    if [[ "$current_hostname" != "$HOSTNAME_VALUE" ]]; then
                        log_message "MSG" "INFO" "Mise à jour du hostname: $current_hostname -> $HOSTNAME_VALUE"
                        sudo sed -i "s/^hostname\s*=.*/hostname = $HOSTNAME_VALUE/" "$WSL_CONF_FILE"
                        log_message "MSG" "SUCCESS" "Hostname mis à jour: $HOSTNAME_VALUE"
                    else
                        log_message "MSG" "SUCCESS" "Hostname déjà configuré correctement: $HOSTNAME_VALUE"
                        exit 0
                    fi
                else
                    # Ajouter hostname à la section [network] existante
                    log_message "MSG" "INFO" "Ajout du hostname à la section [network] existante"
                    sudo sed -i '/^\[network\]/a hostname = '"$HOSTNAME_VALUE" "$WSL_CONF_FILE"
                    log_message "MSG" "SUCCESS" "Hostname ajouté: $HOSTNAME_VALUE"
                fi
            else
                # Ajouter la section [network] avec hostname
                log_message "MSG" "INFO" "Ajout de la section [network] avec hostname"
                sudo tee -a "$WSL_CONF_FILE" > /dev/null << EOF

[network]
hostname = $HOSTNAME_VALUE
EOF
                log_message "MSG" "SUCCESS" "Section [network] et hostname ajoutés: $HOSTNAME_VALUE"
            fi
        fi
        
        log_message "MSG" "INFO" "Note: Redémarrez WSL pour que le changement de hostname prenne effet"
        log_message "MSG" "INFO" "Commande: wsl --terminate $WSL_DISTRO_NAME puis relancer"
    else
        log_message "MSG" "WARN" "Variable WSL_DISTRO_NAME non définie - hostname non configuré"
    fi
}
