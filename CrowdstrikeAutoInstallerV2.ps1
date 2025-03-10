# Set execution policy for the current session to RemoteSigned
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force

# Direct download link for Crowdstrike installer exe. file shared on Google Drive.
[string] $InstallerDownloadUrl = "https://drive.google.com/uc?id=1-OP5MJSRkVUlvrrLaEQwrA9FSW3s9SnW&export=download"

# Direct download link for the config file shared on Google Drive.
[string] $ConfigDownloadUrl = "https://drive.google.com/uc?id=CROWDSTRIKEAUTOINSTALLERCONFIG_ID&export=download"

# Temporary paths to store the downloaded installer and config file
[string] $TempInstallerPath = "$env:TEMP\WindowsSensor.exe"
[string] $TempConfigPath = "$env:TEMP\CrowdstrikeAutoInstallerConfig.json"

# Function to log messages
function Write-Log {
    param (
        [string] $Message
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$Timestamp] $Message"
}

# Function to download a file from Google Drive
function Download-File {
    param (
        [string] $DownloadUrl,
        [string] $DestinationPath
    )
    Write-Log "Downloading file from $DownloadUrl..."
    try {
        # Use Invoke-WebRequest to download the file
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $DestinationPath
        Write-Log "Download complete: $DestinationPath"
    } catch {
        Write-Log "Failed to download file: $_"
        throw "Failed to download file."
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
            #This may cause problems if server takes longer than 10 seconds to connect.... possibly adding loop?
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
    # Step 1: Download the config file
    Download-File -DownloadUrl $ConfigDownloadUrl -DestinationPath $TempConfigPath

    # Step 2: Parse the config file
    $config = Get-Content $TempConfigPath | ConvertFrom-Json

    # Retrieve parameters from the config file
    $FalconClientId = $config.FalconClientId
    $FalconClientSecret = $config.FalconClientSecret
    $SensorUpdatePolicyName = $config.SensorUpdatePolicyName

    # Step 3: Download the installer
    Download-File -DownloadUrl $InstallerDownloadUrl -DestinationPath $TempInstallerPath

    # Step 4: Install the Falcon sensor
    Install-FalconSensor

    # Step 5: Retrieve hostname
    $Hostname = Get-Hostname

    # Step 6: Retrieve Agent ID (AID)
    $AgentID = Get-AgentID

    # Output results
    Write-Log "Installation completed successfully!"
    Write-Log "Hostname: $Hostname"
    Write-Log "Agent ID (AID): $AgentID"
} finally {
    # Clean up the temporary files after installation
    if (Test-Path $TempInstallerPath) {
        Remove-Item -Path $TempInstallerPath -Force
        Write-Log "Temporary installer removed."
    }
    if (Test-Path $TempConfigPath) {
        Remove-Item -Path $TempConfigPath -Force
        Write-Log "Temporary config file removed."
    }
}
