 # Azure Automation Deployment Guide

## Overzicht

Deze guide helpt u bij het deployen van het Resource Report script als Azure Automation Runbook voor enterprise-level automatisering.

## Architectuur

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

## Deployment Stappen

### Stap 1: Creëer Automation Account

```powershell
# Variables
$resourceGroup = "rg-automation"
$location = "westeurope"
$automationAccountName = "aa-resource-reports"
$storageAccountName = "stresourcereports"  # Moet uniek zijn

# Creëer Resource Group
New-AzResourceGroup -Name $resourceGroup -Location $location

# Creëer Automation Account
New-AzAutomationAccount `
    -Name $automationAccountName `
    -Location $location `
    -ResourceGroupName $resourceGroup `
    -AssignSystemIdentity

Write-Host "Automation Account created: $automationAccountName"
```

### Stap 2: Schakel Managed Identity in

```powershell
# Managed Identity is al enabled via -AssignSystemIdentity
# Haal de Principal ID op
$aa = Get-AzAutomationAccount -ResourceGroupName $resourceGroup -Name $automationAccountName
$principalId = $aa.Identity.PrincipalId

Write-Host "Managed Identity Principal ID: $principalId"
```

### Stap 3: Wijs Reader Rechten toe

```powershell
# Wijs Reader role toe op alle subscriptions die gescand moeten worden
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

### Stap 4: Creëer Storage Account voor Reports

```powershell
# Creëer Storage Account
New-AzStorageAccount `
    -ResourceGroupName $resourceGroup `
    -Name $storageAccountName `
    -Location $location `
    -SkuName Standard_LRS `
    -Kind StorageV2

# Wijs Storage Blob Data Contributor role toe
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccountName

New-AzRoleAssignment `
    -ObjectId $principalId `
    -RoleDefinitionName "Storage Blob Data Contributor" `
    -Scope $storageAccount.Id

Write-Host "Storage Account created: $storageAccountName"
```

### Stap 5: Installeer Required Modules

```powershell
# Modules die benodigd zijn in Automation Account
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

### Stap 6: Upload Runbook

```powershell
# Upload het runbook script
$runbookName = "Generate-AzureResourceReport"
$runbookPath = ".\Azure-Automation-Runbook.ps1"

Import-AzAutomationRunbook `
    -ResourceGroupName $resourceGroup `
    -AutomationAccountName $automationAccountName `
    -Name $runbookName `
    -Type PowerShell `
    -Path $runbookPath `
    -Force

# Publiceer het runbook
Publish-AzAutomationRunbook `
    -ResourceGroupName $resourceGroup `
    -AutomationAccountName $automationAccountName `
    -Name $runbookName

Write-Host "Runbook published: $runbookName"
```

### Stap 7: Configureer Variables (optioneel)

```powershell
# Sla configuratie op als Automation Variables
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

# Voor SendGrid (optioneel)
# New-AzAutomationVariable `
#     -ResourceGroupName $resourceGroup `
#     -AutomationAccountName $automationAccountName `
#     -Name "SendGridApiKey" `
#     -Value "YOUR-SENDGRID-API-KEY" `
#     -Encrypted $true
```

### Stap 8: Creëer Schedule

```powershell
# Creëer wekelijks schema (elke maandag 08:00)
$timeZone = "W. Europe Standard Time"
$startTime = (Get-Date).Date.AddDays(1).AddHours(8)  # Morgen om 08:00

New-AzAutomationSchedule `
    -ResourceGroupName $resourceGroup `
    -AutomationAccountName $automationAccountName `
    -Name "WeeklyMonday8AM" `
    -StartTime $startTime `
    -WeekInterval 1 `
    -DaysOfWeek Monday `
    -TimeZone $timeZone

# Link schedule aan runbook
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

### Stap 9: Test het Runbook

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

### Runbook faalt met "Access Denied"
**Oplossing:** Controleer of de Managed Identity Reader rechten heeft:
```powershell
Get-AzRoleAssignment -ObjectId $principalId
```

### Modules niet gevonden
**Oplossing:** Wacht tot modules volledig geïnstalleerd zijn:
```powershell
Get-AzAutomationModule -ResourceGroupName $resourceGroup -AutomationAccountName $automationAccountName
```

### Reports worden niet opgeslagen
**Oplossing:** Controleer Storage rechten:
```powershell
Get-AzRoleAssignment -Scope (Get-AzStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccountName).Id
```

## Kosten Schatting

- **Automation Account**: ~$0/maand (first 500 minutes free, then $0.002/min)
- **Storage Account**: ~$1-5/maand (afhankelijk van report grootte en retentie)
- **Uitvoering**: ~5-10 minuten per week = gratis binnen free tier

**Totaal: ~$1-5 per maand** voor volledig beheerde enterprise solution

## Email Setup met SendGrid

1. Registreer voor [SendGrid](https://sendgrid.com/)
2. Creëer API Key met "Mail Send" permission
3. Sla API Key op als encrypted variable:
```powershell
New-AzAutomationVariable `
    -ResourceGroupName $resourceGroup `
    -AutomationAccountName $automationAccountName `
    -Name "SendGridApiKey" `
    -Value "YOUR-API-KEY" `
    -Encrypted $true
```

4. Update runbook parameters met email addresses

## Best Practices

1. Gebruik Managed Identity in plaats van credentials
2. Implement lifecycle policy op Storage Account (delete oude reports na 90 dagen)
3. Enable diagnostics op Automation Account
4. Set up alerts voor failed runs
5. Tag resources voor cost tracking
6. Review reports maandelijks en neem actie

## Meer Informatie

- [Azure Automation Documentation](https://docs.microsoft.com/azure/automation/)
- [Managed Identities](https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/)
- [Azure Storage Lifecycle Management](https://docs.microsoft.com/azure/storage/blobs/lifecycle-management-overview)
