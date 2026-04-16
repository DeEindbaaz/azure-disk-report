<#
.SYNOPSIS
    Creates a Windows Scheduled Task to run the Azure Resource Report weekly.

.DESCRIPTION
    This script sets up a weekly scheduled task in Windows Task Scheduler that runs
    the Generate-AzureResourceReport.ps1 script every Monday at 08:00.

.PARAMETER ReportPath
    Path where reports will be saved

.PARAMETER TaskTime
    Time when the task should run (default: 08:00)

.PARAMETER TaskDay
    Day of the week to run (default: Monday)

.PARAMETER ScriptPath
    Full path to the Generate-AzureResourceReport.ps1 script

.EXAMPLE
    .\Setup-WeeklyTask.ps1 -ReportPath "C:\Reports"

.EXAMPLE
    .\Setup-WeeklyTask.ps1 -ReportPath "C:\Reports" -TaskTime "09:00" -TaskDay "Friday"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ReportPath = "C:\Reports\Azure",
    
    [Parameter(Mandatory=$false)]
    [string]$TaskTime = "08:00",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday')]
    [string]$TaskDay = "Monday",

    [Parameter(Mandatory=$false)]
    [string]$ScriptPath
)

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator to create scheduled tasks."
    Write-Host "Please restart PowerShell as Administrator and try again."
    exit 1
}

Write-Host "Setting up Azure Weekly Resource Report Scheduled Task..."

# Determine script path
if (-not $ScriptPath) {
    $ScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Generate-AzureResourceReport.ps1"
}

if (-not (Test-Path $ScriptPath)) {
    Write-Error "Script not found at: $ScriptPath"
    exit 1
}

Write-Host "Script Location: $ScriptPath"

# Create report directory if it doesn't exist
if (-not (Test-Path $ReportPath)) {
    Write-Host "Creating report directory: $ReportPath"
    New-Item -ItemType Directory -Path $ReportPath -Force | Out-Null
}

Write-Host "Report Output Path: $ReportPath"

# Task configuration
$taskName = "Azure-Weekly-Resource-Report"
$description = "Generates weekly report of unattached Azure disks and unused Public IPs"

# Check if task already exists
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existingTask) {
    $response = Read-Host "Task '$taskName' already exists. Overwrite? (Y/N)"
    if ($response -ne 'Y' -and $response -ne 'y') {
        Write-Host "Operation cancelled."
        exit 0
    }
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "Existing task removed."
}

try {
    # Create the action
    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$ScriptPath`" -OutputPath `"$ReportPath`""

    # Create the trigger (weekly on specified day at specified time)
    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $TaskDay -At $TaskTime

    # Create the principal (run as current user)
    $principal = New-ScheduledTaskPrincipal `
        -UserId "$env:USERDOMAIN\$env:USERNAME" `
        -LogonType S4U `
        -RunLevel Highest

    # Create settings
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RunOnlyIfNetworkAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Hours 2)

    # Register the task
    Register-ScheduledTask `
        -TaskName $taskName `
        -Description $description `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Settings $settings | Out-Null

    Write-Host "`nScheduled Task created successfully!"
    Write-Host "`nTask Details:"
    Write-Host "  Name: $taskName"
    Write-Host "  Schedule: Every $TaskDay at $TaskTime"
    Write-Host "  Script: $ScriptPath"
    Write-Host "  Output: $ReportPath"
    Write-Host "  User: $env:USERDOMAIN\$env:USERNAME"

    # Ask if user wants to test run now
    Write-Host "`n"
    $testRun = Read-Host "Do you want to run the task now to test it? (Y/N)"
    if ($testRun -eq 'Y' -or $testRun -eq 'y') {
        Write-Host "`nStarting test run..."
        Start-ScheduledTask -TaskName $taskName
        Start-Sleep -Seconds 2
        
        $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName
        Write-Host "Task Status: $($taskInfo.LastTaskResult)"
        Write-Host "Last Run Time: $($taskInfo.LastRunTime)"
        
        Write-Host "`nCheck the report directory for output: $ReportPath"
    }

    Write-Host "`nTo manage this task:"
    Write-Host "  - View: Get-ScheduledTask -TaskName '$taskName'"
    Write-Host "  - Run manually: Start-ScheduledTask -TaskName '$taskName'"
    Write-Host "  - Disable: Disable-ScheduledTask -TaskName '$taskName'"
    Write-Host "  - Remove: Unregister-ScheduledTask -TaskName '$taskName' -Confirm:`$false"
    Write-Host "  - Or use Task Scheduler GUI: taskschd.msc"

} catch {
    Write-Error "Failed to create scheduled task: $_"
    exit 1
}
