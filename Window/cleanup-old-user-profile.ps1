<#
.SYNOPSIS
This script is designed to completely remove a local user profile from a Windows computer.

.DESCRIPTION
Before proceeding with the removal, the script will prompt the user for confirmation. A progress bar is also displayed during the removal process to show the progress and status of the removal. The script requires the user to specify the name of the local user account whose profile needs to be removed. For example, to remove the local user profile for the user “JohnDoe”, you would use Remove-LocalUserProfileCompletely -Username "JohnDoe".

.AUTHOR
Karanvir
#>

[CmdletBinding()]
param (
    [Parameter(ValueFromPipelineByPropertyName, Mandatory=$true)]
    [string]$Username
)

function Remove-LocalUserProfileCompletely {
    param (
        [Parameter(ValueFromPipelineByPropertyName, Mandatory=$true)]
        [string]$Username
    )

    Write-Verbose "Getting user account..."
    $user = Get-LocalUser -Name $Username -ErrorAction Stop

    Write-Verbose "Removing user account from the local account database..."
    Write-Progress -Activity "Removing user account from the local account database" -Status "Removing user account..." -PercentComplete 0
    Remove-LocalUser -SID $user.SID -ErrorAction SilentlyContinue
    Write-Progress -Activity "Removing user account from the local account database" -Completed

    Write-Verbose "Removing user profile directory..."
    $profilePath = "C:\Users\$Username"
    if (Test-Path -Path $profilePath) {
        $profileSize = (Get-ChildItem $profilePath -Recurse | Measure-Object -Property Length -Sum).Sum
        $template = Create-ProgressBarTemplate -Width 30
        Write-Progress -Activity "Removing user profile directory" -Status "Removing files..." -PercentComplete 0
        Get-ChildItem $profilePath -Recurse | ForEach-Object {
            Remove-Item -Path $_.FullName -Force -Recurse -ErrorAction SilentlyContinue
            $progress = $_.Length * 100 / $profileSize
            $status = $template -f $progressBar, $progress, $_.FullName
            Write-Progress -Activity "Removing user profile directory" -Status $status -PercentComplete $progress
        }
        Remove-Item -Path $profilePath -Force -Recurse -ErrorAction SilentlyContinue
    } else {
        Write-Warning "User profile directory for '$Username' not found."
    }

    Write-Verbose "Removing user profile from the registry..."
    $userProfile = Get-CimInstance -Class Win32_UserProfile | Where-Object { $_.SID -eq $user.SID } -ErrorAction SilentlyContinue
    if ($userProfile) {
        Remove-CimInstance -InputObject $userProfile -ErrorAction SilentlyContinue
    } else {
        Write-Warning "No local user profile found in the registry for '$Username'."
    }

    Write-Host "Local user profile for '$Username' has been completely removed."
}

try {
    Write-Verbose "Removing local user profile completely for '$Username'..."
    Remove-LocalUserProfileCompletely -Username $Username
} catch {
    Write-Warning "Error encountered: $_"
}

Test-LocalUserProfileRemoved -Name $Username
