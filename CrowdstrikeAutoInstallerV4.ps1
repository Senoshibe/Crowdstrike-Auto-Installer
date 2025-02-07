# Set execution policy for the current session to RemoteSigned
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force

# Direct download link for Crowdstrike installer exe. file shared on Google Drive.
[string] $InstallerDownloadUrl = "https://drive.google.com/uc?export=download&id=1jgqtWqXIOITXjouf5MpTPDrTEEokjVMU"

# Temporary paths to store the downloaded installer
[string] $TempInstallerPath = "$env:TEMP\WindowsSensor.exe"

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
        $response = Invoke-WebRequest -Uri $DownloadUrl -Method Get -Headers @{ "User-Agent" = "Mozilla/5.0" } -MaximumRedirection 5
        # Adding the header User-Agent = "Mozilla/5.0" mimics a browser request. Sometimes, Google Drive might check the User-Agent to ensure the request is coming from the web browser.
        # Ensure the content is written to the desintation path
        $response.Content | Out-File -FilePath $DestinationPath -Force
        Write-Log "Download complete: $DestinationPath"
    } catch {
        Write-Log "Failed to download file: $_"
        throw "Failed to download file."
    }
}

# Function to wait for the Falcon sensor service to be running
function Wait-ForService {
    param (
        [string] $ServiceName
    )
    Write-Log "Waiting for service '$ServiceName' to start..."
    $MaxAttempts = 30   # Max number of attempts
    $WaitTime = 5       # Time to wait between checks (in seconds)
    $Attempts = 0

    while ($Attempts -lt $MaxAttempts) {
        $Service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($Service -and $Service.Status -eq "Running") {
            Write-Log "Service '$ServiceName' is running."
            return $true
        }
        $Attempts++
        Write-Log "Attempt $Attempts of $MaxAttempts. Service not yet running. Waiting for $WaitTime seconds..."
        Start-Sleep -Seconds $WaitTime
    }

    Write-Log "Failed to start service '$ServiceName' after $MaxAttempts attempts."
    return $false
}

# Function to install the Falcon sensor
function Install-FalconSensor {
    Write-Log "Starting Falcon sensor installation..."
    if (-Not (Test-Path $TempInstallerPath)) {
        Write-Log "Installer not found at $TempInstallerPath."
        throw "Installer missing."
    }
    try {
        $CustomerID = "26D3E3798219457ABA974E6DE7B52432-53"  # Replace with your actual Customer ID
        Write-Log "Running installer with Customer ID..."
        Start-Process -FilePath $TempInstallerPath -ArgumentList "/install /quiet CID=$CustomerID" -Wait
        Write-Log "Installer finished running."
    } catch {
        Write-Log "Error during installation: $_"
        throw "Installer execution failed."
    }

    # Check if the service is installed after the installer runs
    $ServiceName = "CSFalconService"
    $Service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if (-Not $Service) {
        Write-Log "Service '$ServiceName' not found after installation."
        throw "Falcon sensor service not installed."
    } else {
        Write-Log "Service '$ServiceName' installed and running."
    }
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

    # Step 1: Download the installer
    Download-File -DownloadUrl $InstallerDownloadUrl -DestinationPath $TempInstallerPath

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
    # Clean up the temporary files after installation
    if (Test-Path $TempInstallerPath) {
        Remove-Item -Path $TempInstallerPath -Force
        Write-Log "Temporary installer removed."
    }
}
