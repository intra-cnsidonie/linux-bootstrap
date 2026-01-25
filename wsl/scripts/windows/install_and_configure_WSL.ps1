param(
    [Parameter(Mandatory=$true)]
    [string]$distroName
)

# Demander le nom final pour l'instance WSL
$defaultName = $distroName
$wslInstanceName = Read-Host "Enter the name of the WSL instance (default: $defaultName)"

# Utiliser la valeur par défaut si aucune saisie
if ([string]::IsNullOrWhiteSpace($wslInstanceName)) {
    $wslInstanceName = $defaultName
}

# Demander les informations de l'utilisateur
$username = Read-Host "Enter the username to create"
while ([string]::IsNullOrWhiteSpace($username)) {
    Write-Host "Username cannot be empty." -ForegroundColor Yellow
    $username = Read-Host "Enter the username to create"
}

$securePassword = Read-Host "Enter the password for $username" -AsSecureString
$confirmPassword = Read-Host "Confirm the password" -AsSecureString

# Convertir en texte clair pour comparaison
$BSTR1 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
$password1 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR1)
$BSTR2 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($confirmPassword)
$password2 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR2)

if ($password1 -ne $password2) {
    Write-Host "Passwords do not match." -ForegroundColor Red
    exit 1
}

Write-Host "`nInstalling distribution: $distroName"
Write-Host "WSL instance name: $wslInstanceName"
Write-Host "User: $username"

# Downloading and installing the distribution
try {
    Write-Host "`nDownloading and installing $distroName in progress..."
    
    # Check if the distribution already exists
    $existingDistros = wsl -l -q 2>$null | ForEach-Object { $_.Trim() -replace '\x00','' }
    $distroExists = $existingDistros -contains $wslInstanceName
    
    if ($distroExists) {
        Write-Host "The distribution $wslInstanceName already exists." -ForegroundColor Yellow
        $overwrite = Read-Host "Do you want to remove and reinstall it? (Y/N)"
        if ($overwrite -eq "Y" -or $overwrite -eq "y") {
            Write-Host "Removing $wslInstanceName..." -ForegroundColor Yellow
            wsl --unregister $wslInstanceName
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Distribution removed." -ForegroundColor Green
            } else {
                Write-Host "Error during removal." -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host "Installation cancelled." -ForegroundColor Yellow
            exit 0
        }
    }
    
    # Install the distribution (this will download it but not launch it interactively if we finish quickly)
    Write-Host "Installing the distribution (max 5 minutes)..."
    
    # Alternative method: use wsl --install with prior configuration
    # Install without launching by using the import of a base distribution
    
    # First, ensure the base distribution is available
    $tempDir = Join-Path $env:TEMP "wsl-install-$wslInstanceName"
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
    
    # Install the distribution with wsl --install and immediately set root as default
    $installJob = Start-Job -ScriptBlock {
        param($distro, $instanceName)
        wsl --install -d $distro --name $instanceName 2>&1
    } -ArgumentList $distroName, $wslInstanceName
    
    # Wait a bit for the installation to start
    Start-Sleep -Seconds 3
    
    # Wait for the installation to finish
    Wait-Job $installJob -Timeout 300 | Out-Null
    $installResult = Receive-Job $installJob
    Remove-Job $installJob -Force
    
    # Terminate all instances of the distribution
    Write-Host "Stopping the distribution..."
    wsl --terminate $wslInstanceName 2>$null
    Start-Sleep -Seconds 2
    
    Write-Host "Distribution installed!" -ForegroundColor Green
    
    # Create the user in the distribution
    Write-Host "`nCreating user $username..."
    
    # Create the user with password
    $createUserCmd = "useradd -m -s /bin/bash $username && echo '${username}:${password1}' | chpasswd && usermod -aG sudo $username"
    wsl -d $wslInstanceName -u root bash -c $createUserCmd
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "User $username created successfully!" -ForegroundColor Green
        
        # Set the default user for this distribution
        Write-Host "Setting wsl.conf parameters with $username as the default user..."
        $hostname = $wslInstanceName.Replace(".", "-")
        wsl -d $wslInstanceName -u root bash -c "echo '[boot]' > /etc/wsl.conf && echo 'systemd=true' >> /etc/wsl.conf && echo '' >> /etc/wsl.conf && echo '[user]' >> /etc/wsl.conf && echo 'default=$username' >> /etc/wsl.conf && echo '' >> /etc/wsl.conf && echo '[automount]' >> /etc/wsl.conf && echo 'enabled=true' >> /etc/wsl.conf && echo 'options=metadata,umask=22,fmask=11' >> /etc/wsl.conf && echo '' >> /etc/wsl.conf && echo '[network]' >> /etc/wsl.conf && echo 'hostname=$hostname' >> /etc/wsl.conf && echo '' >> /etc/wsl.conf && echo '[interop]' >> /etc/wsl.conf && echo 'enabled=true' >> /etc/wsl.conf && echo 'appendWindowsPath=true' >> /etc/wsl.conf"
        
        # Restart the distribution to apply changes
        Write-Host "Restarting the distribution..."
        wsl --terminate $wslInstanceName
        Start-Sleep -Seconds 2
        
        Write-Host "`nInstallation completed!" -ForegroundColor Green
        Write-Host "WSL Instance: $wslInstanceName" -ForegroundColor Cyan
        Write-Host "User: $username" -ForegroundColor Cyan
        Write-Host "`nYou can connect with: wsl ~ -d $wslInstanceName -u $username" -ForegroundColor Cyan
    } else {
        Write-Host "Error creating the user." -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
} finally {
    # Clean up sensitive variables
    if ($password1) { $password1 = $null }
    if ($password2) { $password2 = $null }
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR1)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR2)
}

Write-Host "[WSL] Welcome configuration of $wslInstanceName" -ForegroundColor Cyan
Write-Host "=========================================================================" -ForegroundColor Cyan

Write-Host "`n[WSL] Repository cloning..." -ForegroundColor Yellow

$gitRepoUrl = "https://github.com/intra-cnsidonie/linux-bootstrap.git"
$gitBranch = "feat/wsl"

$launchScript = "mkdir -p ~/wsl_install_src ; cd ~/wsl_install_src ; if [ ! -d linux-bootstrap ]; then git clone -b $gitBranch $gitRepoUrl ; fi && cd linux-bootstrap/wsl/scripts/$distroName && ./launch.sh"

wsl -d $wslInstanceName -u $username bash -ic "$launchScript"

Write-Host "`nPress any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
