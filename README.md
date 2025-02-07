# Crowdstrike Auto-Installer
 Powershell script that automatically installs Crowdstrike, along with other administrative tasks. This project was created for my colleagues who repeatedly skip steps with the installation process, therefore leading to myself having to do the same job twice. 
 I'm aiming to create it into a one click process.

# Personal Notes
CrowdstrikeAutoInstaller.ps1 had the problem of it being a two step process (entirely defeating the purpose of this project). And also there were security issues as either the API key had to be hardcoded into the script. Or IT agents would have to type in a second command manually with the API keys which may not be stored securely.

In order to address the security issue, many options were taken into consideration like using the opensource tool PS2EXE to convert the script into an exe. file. Then encrypting the said exe. file. However, PS2EXE has its vulnerabilities according to research.
Another option was to set environmental variables, but this made the process more complicated than it had to be.

CrowdstrikeAutoInstallerV2.ps1 helps with the security issue by storing the API keys in a config file. This config file is stored in the cloud securely in our company's enterprise licensed Google Drive. Only employees have access to the said file.
The script creates a temporarily location for both the Crowdstrike installer and the config file. The script draws the API keys from the config file, then proceeds to install Crowdstrike, retrieve the hostname and the AID. The output is left in the command-line for the agent to copy and record in their tickets.

26/01/25 Ran into issues with device policy. Set execution policy to RemoteSigned, but may run into issues with Mark of The Web (MoTW). 
Looking to test MoTW issues when testing script on device once security team is willing to share access to API Keys from Crowdstrike portal...

28/01/25 Spoke with the Cyber Security team. Currently experiencing difficulties getting API access. Spoke with one of their Security Analysts and Head of Security and supposedly the WindowSensor exe. file automatically checks the sensor update policy, so the configuration file is not needed. Looking to improve the code with a 3rd version without the config calls and sensor update policy function...

07/02/2025 Came across issue where after calling the Download-File function, the WindowsSensor exe. file doesn't completely download (file was only 3KB big as opposed to the usual size of 153M. After some research, it seems Google Drive links are known to sometimes redirect to a different URL to handle large file downloads. the Invoke-Webrequest call won't handle the redirection properly... use -AllowUnencryptedAuthentication flag for handling the redirect.
