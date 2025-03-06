# Set execution policy for the current session to RemoteSigned
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force

# Direct download link for Crowdstrike installer exe. file shared on Google Drive.
[string] $InstallerDownloadUrl = "https://www.dropbox.com/scl/fi/7bmmnchaob17qthczv85x/FalconSensor_Windows.exe?rlkey=1comfzf6svpr9e93t2wrbv9zz&st=vtrd14hs&dl=1"

# Temporary paths to store the downloaded installer
[string] $TempInstallerPath = "$env:TEMP\FalconSensor_Windows.exe"

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
        # Download the file and save directly to DestinationPath
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $DestinationPath -Headers @{ "User-Agent" = "Mozilla/5.0" } -MaximumRedirection 5
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
        Start-Process -FilePath $TempInstallerPath -ArgumentList "/install /quiet /norestart CID=$CustomerID" -Wait
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

        #Wait for the service to start (check every 5 seconds)
        $MaxAttempts = 12 
        $WaitTime = 5

        $Attempts = 0
        while ($Attempts -lt $MaxAttempts) {
            $Service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            if ($Service -and $Service.Status -eq "Running") {
                Write-Log "Falcon sensor service is running."
                break
            }
            $Attempts++
            Write-Log "Attempt $Attempts of $MaxAttempts. Waiting for service to start..."
            Start-Sleep -Seconds $WaitTime
        }

        if ($Attempts -ge $MaxAttempts) {
            Write-Log "Falcon sensor service did not start within the expected time."
            throw "Falcon sensor service not running after $($MaxAttempts * $WaitTime) seconds."
        }

        #Add wait time to ensure Falcon sensor is initialized fully
        Write-Log "Waiting for Falcon sensor to fully initialize..."
        Start-Sleep -Seconds 30

        # Use REG QUERY to retrieve the Agent ID (AID)
        $regOutput = reg query "HKLM\System\CurrentControlSet\Services\CSAgent\Sim" /f AG

        # Extract AID from output
        $AID = $regOutput -match "AG\s+(\S+)" | Out-Null; $matches[1]
        
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
