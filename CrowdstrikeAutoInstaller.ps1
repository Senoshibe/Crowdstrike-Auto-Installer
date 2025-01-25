# Direct download link for Crowdstrike installer exe. file shared on Google Drive.
[string] $InstallerDownloadUrl = "https://drive.google.com/uc?id=1-OP5MJSRkVUlvrrLaEQwrA9FSW3s9SnW&export=download"

# Temporary path to store the downloaded installer
[string] $TempInstallerPath = "$env:TEMP\WindowsSensor.exe"

# Function to log messages
function Write-Log {
    param (
        [string] $Message
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$Timestamp] $Message"
}

# Function to download the installer
function Download-FalconInstaller {
    Write-Log "Downloading Falcon sensor installer..."
    try {
        # Use Invoke-WebRequest to download the file
        Invoke-WebRequest -Uri $InstallerDownloadUrl -OutFile $TempInstallerPath -UseBasicParsing
        Write-Log "Download complete: $TempInstallerPath"
    } catch {
        Write-Log "Failed to download installer: $_"
        throw "Failed to download Falcon installer."
    }
}

# Function to install the Falcon sensor
function Install-FalconSensor {
    Write-Log "Installing Falcon sensor..."
    if (-Not (Test-Path $TempInstallerPath)) {
        Write-Log "Installer not found at $TempInstallerPath."
        throw "Installer missing."
    }
    Start-Process -FilePath $TempInstallerPath -ArgumentList "/install /quiet" -Wait
    Write-Log "Falcon sensor installation complete."
}

# Function to retrieve the hostname
function Get-Hostname {
    Write-Log "Retrieving hostname..."
    try {
        $Hostname = $env:COMPUTERNAME
        Write-Log "Hostname: $Hostname"
        return $Hostname
    } catch {
        Write-Log "Failed to retrieve hostname: $_"
        throw "Failed to get hostname."
    }
}

# Function to retrieve the Agent ID (AID)
function Get-AgentID {
    Write-Log "Retrieving Agent ID (AID)..."
    try {
        # Ensure Falcon sensor service is running
        $ServiceName = "CSFalconService"
        if ((Get-Service -Name $ServiceName -ErrorAction SilentlyContinue).Status -ne "Running") {
            Write-Log "Falcon sensor service is not running. Starting it now..."
            Start-Service -Name $ServiceName
            Start-Sleep -Seconds 10
        }

        # Check for Agent ID in registry
        $RegistryPath = "HKLM:\SOFTWARE\CrowdStrike\Agent"
        $AID = (Get-ItemProperty -Path $RegistryPath).AID
        Write-Log "Agent ID (AID): $AID"
        return $AID
    } catch {
        Write-Log "Failed to retrieve Agent ID: $_"
        throw "Failed to get Agent ID (AID)."
    }
}

# Main script execution
try {
    # Step 1: Download the installer
    Download-FalconInstaller

    # Step 2: Install the Falcon sensor
    Install-FalconSensor

    # Step 3: Retrieve hostname
    $Hostname = Get-Hostname

    # Step 4: Retrieve Agent ID (AID)
    $AgentID = Get-AgentID

    # Output results
    Write-Log "Installation completed successfully!"
    Write-Log "Hostname: $Hostname"
    Write-Log "Agent ID (AID): $AgentID"
} finally {
    # Clean up the temporary installer after installation
    if (Test-Path $TempInstallerPath) {
        Remove-Item -Path $TempInstallerPath -Force
        Write-Log "Temporary installer removed."
    }
}
#Run following command in Powershell:
#.\Install-FalconSensor.ps1 -FalconClientId "your-client-id" -FalconClientSecret "your-client-secret" -SensorUpdatePolicyName "default_policy"