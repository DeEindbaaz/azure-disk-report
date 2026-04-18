# Azure Unused Resources Weekly Report

## Overview

This PowerShell script automatically generates a weekly HTML report of:
- **Unattached Managed Disks** - Disks not attached to any VM
- **Unused Public IP Addresses** - Public IP addresses that are not in use

The report also includes estimated monthly costs to help you optimize your Azure spending.

## Files in this Repository

- **Generate-AzureResourceReport.ps1** - Main script for local execution
- **Azure-Automation-Runbook.ps1** - Version for Azure Automation (with Managed Identity)
- **Setup-WeeklyTask.ps1** - Installs Windows Scheduled Task
- **Test-Configuration.ps1** - Validates environment and Azure connectivity
- **AZURE-AUTOMATION-GUIDE.md** - Complete deployment guide for Azure Automation
- **QUICKSTART.md** - Quick start instructions
- **README.md** - This file

## Requirements

### PowerShell Modules
The script requires the following Azure PowerShell modules:
```powershell
Install-Module -Name Az.Accounts -Force -AllowClobber
Install-Module -Name Az.Compute -Force -AllowClobber
Install-Module -Name Az.Network -Force -AllowClobber
```

### Azure Permissions
Your Azure account must have at least **Reader** permissions on the subscriptions you want to scan.

## Usage

### Basic Usage
```powershell
# Generate report in current directory
.\Generate-AzureResourceReport.ps1

# Generate report in specific directory
.\Generate-AzureResourceReport.ps1 -OutputPath "C:\Reports"

# Scan specific subscriptions
.\Generate-AzureResourceReport.ps1 -SubscriptionIds "sub-id-1","sub-id-2"
```

### With Email Notification
```powershell
.\Generate-AzureResourceReport.ps1 `
    -SendEmail `
    -EmailTo "admin@company.com","team@company.com" `
    -EmailFrom "azure-reports@company.com" `
    -SmtpServer "smtp.company.com"
```

## Weekly Automation

### Option 1: Windows Task Scheduler
Use the included script to set up a weekly task:

```powershell
.\Setup-WeeklyTask.ps1 -ReportPath "C:\Reports"
```

This creates a Windows Scheduled Task that generates the report every Monday at 08:00.

### Option 2: Manual Task Scheduler Setup
1. Open **Task Scheduler**
2. Click on **Create Task**
3. General tab:
   - Name: "Azure Weekly Resource Report"
   - Run whether user is logged on or not
   - Run with highest privileges
4. Triggers tab:
   - New → Weekly
   - Start: Monday 08:00
   - Recur every 1 week
5. Actions tab:
   - Action: Start a program
   - Program: `powershell.exe`
   - Arguments: `-ExecutionPolicy Bypass -File "C:\Path\To\Generate-AzureResourceReport.ps1" -OutputPath "C:\Reports"`

### Option 3: Azure Automation Runbook (Recommended for Enterprise)
For enterprise environments, you can deploy this script as an Azure Automation Runbook.

**See [AZURE-AUTOMATION-GUIDE.md](AZURE-AUTOMATION-GUIDE.md) for complete deployment instructions.**

Quick setup:
1. Create an **Automation Account** with PowerShell 5.1 runtime
2. Install modules in these **specific versions** (compatibility tested):
   - Az.Accounts 2.15.0
   - Az.Compute 4.31.0
   - Az.Network 4.20.0
   - Az.Storage 4.8.0
3. Upload **Azure-Automation-Runbook.ps1** (not Generate-AzureResourceReport.ps1)
4. Enable **Managed Identity**
5. Assign **Reader** + **Storage Account Contributor** roles
6. Configure **Storage Account** for report storage
7. Create a **Schedule** (e.g., every Monday 08:00)

**Important**: Module versions are critical! Az.Compute 7.x does not work with Az.Accounts 2.x in PS 5.1.

## Report Features

The generated HTML report contains:
- **Summary Dashboard** with total resource count and costs
- **Detailed Disk Table** with name, size, SKU, and costs
- **Public IP Table** with allocation method and costs
- **Cost Estimates** per resource and total
- **Action Items** with cost-saving opportunities

## Cost Optimization Tips

After reviewing the report:

### For Unattached Disks:
```powershell
# Remove a disk (WARNING: Data will be deleted!)
Remove-AzDisk -ResourceGroupName "RG-Name" -DiskName "DiskName" -Force

# Create a snapshot first (backup)
$disk = Get-AzDisk -ResourceGroupName "RG-Name" -DiskName "DiskName"
$snapshotConfig = New-AzSnapshotConfig -SourceUri $disk.Id -CreateOption Copy -Location $disk.Location
New-AzSnapshot -Snapshot $snapshotConfig -SnapshotName "backup-snapshot" -ResourceGroupName "RG-Name"
```

### For Unused Public IPs:
```powershell
# Remove an unused Public IP
Remove-AzPublicIpAddress -ResourceGroupName "RG-Name" -Name "IP-Name" -Force
```

## Security Best Practices

1. **Use Managed Identity** when possible (Azure Automation)
2. **Limit access** to only required subscriptions
3. **Encrypt email credentials** if using SMTP
4. **Review reports** regularly and take action on old resources
5. **Test first** in a development environment

## Output

The script generates:
- **HTML Report**: `Azure-UnusedResources-Report-YYYY-MM-DD.html`
- **Console Output**: Summary with counts and costs
- **Auto-open**: Report opens automatically in browser

## Troubleshooting

### "Module not found" errors
```powershell
# Update all Az modules
Update-Module -Name Az -Force
```

### Azure Automation: "Az.Compute module could not be loaded"
This is a module compatibility issue in PowerShell 5.1 runtime.

**Solution**: Use Az.Compute 4.31.0 instead of 7.x
```powershell
# In Azure Portal -> Automation Account -> Modules
# Remove Az.Compute (if 7.x is installed)
# Install Az.Compute 4.31.0 with specific URL:
# https://www.powershellgallery.com/api/v2/package/Az.Compute/4.31.0

# Wait until ProvisioningState = Succeeded
```

**Working module combination for PS 5.1**:
- Az.Accounts: 2.15.0
- Az.Compute: 4.31.0 (NOT 7.x)
- Az.Network: 4.20.0
- Az.Storage: 4.8.0

### "Insufficient permissions" errors
```powershell
# Check your current role assignments
Get-AzRoleAssignment -SignInName "your-email@company.com"

# For Azure Automation Managed Identity:
Get-AzRoleAssignment -ObjectId "managed-identity-principal-id"
```

### Azure Automation: Storage permission errors
Ensure the Managed Identity has both roles:
- **Reader** on subscription (for scanning resources)
- **Storage Account Contributor** on storage account (for listKeys)

### "Connect-AzAccount" hangs
```powershell
# Clear cached credentials
Clear-AzContext -Force
Connect-AzAccount
```

## Contact & Support

For questions or issues, create an issue in the repository.

## Changelog

### Version 1.0 (2026-04-13)
- Initial release
- Support voor unattached disks
- Support voor unused public IPs
- HTML rapport generatie
- Cost estimation
- Email notificaties
- Multi-subscription support

## License

MIT License - Vrij te gebruiken en aan te passen voor uw organisatie.
