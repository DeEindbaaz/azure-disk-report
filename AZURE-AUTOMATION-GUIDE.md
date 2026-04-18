# Azure Automation Deployment Guide

## Overview

This guide helps you deploy the Resource Report script as an Azure Automation Runbook for enterprise-level automation.

## Architecture

```
Azure Automation Account (Managed Identity)
    ↓
Scans all Subscriptions (Reader access)
    ↓
Generates HTML Report
    ↓
Stores in Azure Storage Blob
    ↓
Sends Email via SendGrid (optional)
```

## Deployment Steps

### Step 1: Create Automation Account

```powershell
# Variables
$resourceGroup = "rg-automation"
$location = "westeurope"
$automationAccountName = "aa-resource-reports"
$storageAccountName = "stresourcereports"  # Must be unique

# Create Resource Group
New-AzResourceGroup -Name $resourceGroup -Location $location

# Create Automation Account
New-AzAutomationAccount `
    -Name $automationAccountName `
    -Location $location `
    -ResourceGroupName $resourceGroup `
    -AssignSystemIdentity

Write-Host "Automation Account created: $automationAccountName"
```

### Step 2: Enable Managed Identity

```powershell
# Managed Identity is already enabled via -AssignSystemIdentity
# Get the Principal ID
$aa = Get-AzAutomationAccount -ResourceGroupName $resourceGroup -Name $automationAccountName
$principalId = $aa.Identity.PrincipalId

Write-Host "Managed Identity Principal ID: $principalId"
```

### Step 3: Assign Reader Permissions

```powershell
# Assign Reader role to all subscriptions that need to be scanned
$subscriptions = Get-AzSubscription | Where-Object { $_.State -eq 'Enabled' }

foreach ($sub in $subscriptions) {
    Set-AzContext -SubscriptionId $sub.Id
    
    New-AzRoleAssignment `
        -ObjectId $principalId `
        -RoleDefinitionName "Reader" `
        -Scope "/subscriptions/$($sub.Id)" `
        -ErrorAction SilentlyContinue
    
    Write-Host "Assigned Reader to: $($sub.Name)"
}
```

### Step 4: Create Storage Account for Reports

```powershell
# Create Storage Account
New-AzStorageAccount `
    -ResourceGroupName $resourceGroup `
    -Name $storageAccountName `
    -Location $location `
    -SkuName Standard_LRS `
    -Kind StorageV2

# Assign Storage Blob Data Contributor role
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccountName

New-AzRoleAssignment `
    -ObjectId $principalId `
    -RoleDefinitionName "Storage Blob Data Contributor" `
    -Scope $storageAccount.Id

Write-Host "Storage Account created: $storageAccountName"
```

### Step 5: Install Required Modules

```powershell
# Modules required in Automation Account
$modules = @(
    @{ Name = 'Az.Accounts'; Version = 'latest' }
    @{ Name = 'Az.Compute'; Version = 'latest' }
    @{ Name = 'Az.Network'; Version = 'latest' }
    @{ Name = 'Az.Storage'; Version = 'latest' }
)

foreach ($module in $modules) {
    Write-Host "Installing module: $($module.Name)..."
    
    New-AzAutomationModule `
        -ResourceGroupName $resourceGroup `
        -AutomationAccountName $automationAccountName `
        -Name $module.Name `
        -ContentLinkUri "https://www.powershellgallery.com/api/v2/package/$($module.Name)"
    
    # Wait for module to install
    do {
        Start-Sleep -Seconds 10
        $moduleStatus = Get-AzAutomationModule `
            -ResourceGroupName $resourceGroup `
            -AutomationAccountName $automationAccountName `
            -Name $module.Name
    } while ($moduleStatus.ProvisioningState -ne 'Succeeded')
    
    Write-Host "  OK - $($module.Name) installed"
}
```

### Step 6: Upload Runbook

```powershell
# Upload the runbook script
$runbookName = "Generate-AzureResourceReport"
$runbookPath = ".\Azure-Automation-Runbook.ps1"

Import-AzAutomationRunbook `
    -ResourceGroupName $resourceGroup `
    -AutomationAccountName $automationAccountName `
    -Name $runbookName `
    -Type PowerShell `
    -Path $runbookPath `
    -Force

# Publish the runbook
Publish-AzAutomationRunbook `
    -ResourceGroupName $resourceGroup `
    -AutomationAccountName $automationAccountName `
    -Name $runbookName

Write-Host "Runbook published: $runbookName"
```

### Step 7: Configure Variables (optional)

```powershell
# Save configuration as Automation Variables
New-AzAutomationVariable `
    -ResourceGroupName $resourceGroup `
    -AutomationAccountName $automationAccountName `
    -Name "StorageAccountName" `
    -Value $storageAccountName `
    -Encrypted $false

New-AzAutomationVariable `
    -ResourceGroupName $resourceGroup `
    -AutomationAccountName $automationAccountName `
    -Name "StorageAccountResourceGroup" `
    -Value $resourceGroup `
    -Encrypted $false

# For SendGrid (optional)
# New-AzAutomationVariable `
#     -ResourceGroupName $resourceGroup `
#     -AutomationAccountName $automationAccountName `
#     -Name "SendGridApiKey" `
#     -Value "YOUR-SENDGRID-API-KEY" `
#     -Encrypted $true
```

### Step 8: Create Schedule

```powershell
# Create weekly schedule (every Monday 08:00)
$timeZone = "W. Europe Standard Time"
$startTime = (Get-Date).Date.AddDays(1).AddHours(8)  # Tomorrow at 08:00

New-AzAutomationSchedule `
    -ResourceGroupName $resourceGroup `
    -AutomationAccountName $automationAccountName `
    -Name "WeeklyMonday8AM" `
    -StartTime $startTime `
    -WeekInterval 1 `
    -DaysOfWeek Monday `
    -TimeZone $timeZone

# Link schedule to runbook
Register-AzAutomationScheduledRunbook `
    -ResourceGroupName $resourceGroup `
    -AutomationAccountName $automationAccountName `
    -RunbookName $runbookName `
    -ScheduleName "WeeklyMonday8AM" `
    -Parameters @{
        StorageAccountName = $storageAccountName
        StorageAccountResourceGroup = $resourceGroup
        StorageContainerName = "reports"
    }

Write-Host "Schedule created and linked"
```

### Step 9: Test the Runbook

```powershell
# Start test run
$job = Start-AzAutomationRunbook `
    -ResourceGroupName $resourceGroup `
    -AutomationAccountName $automationAccountName `
    -Name $runbookName `
    -Parameters @{
        StorageAccountName = $storageAccountName
        StorageAccountResourceGroup = $resourceGroup
        StorageContainerName = "reports"
    }

Write-Host "Test job started: $($job.JobId)"
Write-Host "Monitoring job status..."

# Monitor job
do {
    Start-Sleep -Seconds 5
    $jobStatus = Get-AzAutomationJob `
        -ResourceGroupName $resourceGroup `
        -AutomationAccountName $automationAccountName `
        -Id $job.JobId
    
    Write-Host "Status: $($jobStatus.Status)"
} while ($jobStatus.Status -notin @('Completed', 'Failed', 'Stopped', 'Suspended'))

# Get output
$output = Get-AzAutomationJobOutput `
    -ResourceGroupName $resourceGroup `
    -AutomationAccountName $automationAccountName `
    -Id $job.JobId `
    -Stream Output

Write-Host "`nJob Output:"
$output | ForEach-Object {
    Get-AzAutomationJobOutputRecord `
        -ResourceGroupName $resourceGroup `
        -AutomationAccountName $automationAccountName `
        -JobId $job.JobId `
        -Id $_.StreamRecordId
}

if ($jobStatus.Status -eq 'Completed') {
    Write-Host "`nTest run completed successfully!"
    Write-Host "Check the Storage Account for the generated report."
} else {
    Write-Host "Job failed. Check the error output above."
}
```

## Monitoring & Maintenance

### View Recent Jobs
```powershell
Get-AzAutomationJob `
    -ResourceGroupName $resourceGroup `
    -AutomationAccountName $automationAccountName `
    -RunbookName $runbookName |
    Select-Object JobId, Status, StartTime, EndTime |
    Format-Table
```

### View Stored Reports
```powershell
$ctx = (Get-AzStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccountName).Context
Get-AzStorageBlob -Container "reports" -Context $ctx |
    Select-Object Name, LastModified, Length |
    Sort-Object LastModified -Descending |
    Format-Table
```

### Download Latest Report
```powershell
$ctx = (Get-AzStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccountName).Context
$latestBlob = Get-AzStorageBlob -Container "reports" -Context $ctx |
    Sort-Object LastModified -Descending |
    Select-Object -First 1

Get-AzStorageBlobContent `
    -Container "reports" `
    -Blob $latestBlob.Name `
    -Context $ctx `
    -Destination ".\latest-report.html" `
    -Force

Start-Process ".\latest-report.html"
```

## Troubleshooting

### Runbook fails with "Access Denied"
**Solution:** Check if the Managed Identity has Reader permissions:
```powershell
Get-AzRoleAssignment -ObjectId $principalId
```

### Modules not found
**Solution:** Wait until modules are fully installed:
```powershell
Get-AzAutomationModule -ResourceGroupName $resourceGroup -AutomationAccountName $automationAccountName
```

### Reports are not saved
**Solution:** Check Storage permissions:
```powershell
Get-AzRoleAssignment -Scope (Get-AzStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccountName).Id
```

## Cost Estimation

- **Automation Account**: ~$0/month (first 500 minutes free, then $0.002/min)
- **Storage Account**: ~$1-5/month (depending on report size and retention)
- **Execution**: ~5-10 minutes per week = free within free tier

**Total: ~$1-5 per month** for fully managed enterprise solution

## Email Setup with SendGrid

1. Register for [SendGrid](https://sendgrid.com/)
2. Create API Key with "Mail Send" permission
3. Save API Key as encrypted variable:
```powershell
New-AzAutomationVariable `
    -ResourceGroupName $resourceGroup `
    -AutomationAccountName $automationAccountName `
    -Name "SendGridApiKey" `
    -Value "YOUR-API-KEY" `
    -Encrypted $true
```

4. Update runbook parameters with email addresses

## Best Practices

1. Use Managed Identity instead of credentials
2. Implement lifecycle policy on Storage Account (delete old reports after 90 days)
3. Enable diagnostics on Automation Account
4. Set up alerts for failed runs
5. Tag resources for cost tracking
6. Review reports monthly and take action

## More Information

- [Azure Automation Documentation](https://docs.microsoft.com/azure/automation/)
- [Managed Identities](https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/)
- [Azure Storage Lifecycle Management](https://docs.microsoft.com/azure/storage/blobs/lifecycle-management-overview)
