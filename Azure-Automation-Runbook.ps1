# Azure Automation Runbook Version
# Dit is een aangepaste versie voor gebruik in Azure Automation

<#
.SYNOPSIS
    Azure Automation Runbook - Generates weekly HTML report of unused Azure resources.

.DESCRIPTION
    This runbook scans for unattached disks and unused Public IPs, then stores
    the report in an Azure Storage Account and optionally sends via email.

.NOTES
    Requirements:
    - Managed Identity enabled on Automation Account
    - Reader role on subscriptions to scan
    - Storage Contributor role on storage account (for report storage)
    
    Automation Account Modules Required:
    - Az.Accounts
    - Az.Compute
    - Az.Network
    - Az.Storage (if storing in blob storage)
#>

param(
    [Parameter(Mandatory=$false)]
    [string[]]$SubscriptionIds,
    
    [Parameter(Mandatory=$false)]
    [string]$StorageAccountName,
    
    [Parameter(Mandatory=$false)]
    [string]$StorageAccountResourceGroup,
    
    [Parameter(Mandatory=$false)]
    [string]$StorageContainerName = "reports",
    
    [Parameter(Mandatory=$false)]
    [string]$SendGridApiKey,  # Store in Automation Variables (encrypted)
    
    [Parameter(Mandatory=$false)]
    [string]$EmailTo,
    
    [Parameter(Mandatory=$false)]
    [string]$EmailFrom
)

# Initialize
$ErrorActionPreference = "Stop"
$reportDate = Get-Date -Format "yyyy-MM-dd"
$reportTime = Get-Date -Format "HH:mm:ss"

# Arrays to store results
$unattachedDisks = @()
$unusedPublicIPs = @()
$totalDiskCost = 0
$totalIPCost = 0

Write-Output "====================================="
Write-Output "Azure Resource Report - Runbook"
Write-Output "Date: $reportDate $reportTime"
Write-Output "====================================="

# Function to calculate monthly disk cost
function Get-DiskMonthlyCost {
    param([string]$DiskSize, [string]$SkuName, [string]$Location)
    
    $costPerGB = switch ($SkuName) {
        'Premium_LRS' { 0.184 }
        'StandardSSD_LRS' { 0.145 }
        'Standard_LRS' { 0.040 }
        'UltraSSD_LRS' { 0.280 }
        default { 0.100 }
    }
    
    return [math]::Round([int]$DiskSize * $costPerGB, 2)
}

# Function to get Public IP monthly cost
function Get-PublicIPMonthlyCost {
    param([string]$SkuName)
    $cost = switch ($SkuName) {
        'Standard' { 3.65 }
        'Basic' { 2.50 }
        default { 2.50 }
    }
    return $cost
}

try {
    Write-Output "Connecting to Azure using Managed Identity..."
    
    # Connect using Managed Identity
    Connect-AzAccount -Identity | Out-Null
    
    Write-Output "Successfully connected to Azure"
    
    # Get subscriptions to scan
    if ($SubscriptionIds) {
        $subscriptions = $SubscriptionIds | ForEach-Object { 
            Get-AzSubscription -SubscriptionId $_ 
        }
    } else {
        Write-Output "Retrieving all accessible subscriptions..."
        $subscriptions = Get-AzSubscription | Where-Object { $_.State -eq 'Enabled' }
    }
    
    Write-Output "Found $($subscriptions.Count) subscription(s) to scan"
    
    # Scan each subscription
    foreach ($subscription in $subscriptions) {
        Write-Output "Scanning subscription: $($subscription.Name)"
        Set-AzContext -SubscriptionId $subscription.Id | Out-Null
        
        # Get unattached disks
        $disks = Get-AzDisk
        foreach ($disk in $disks) {
            if (-not $disk.ManagedBy) {
                $monthlyCost = Get-DiskMonthlyCost -DiskSize $disk.DiskSizeGB -SkuName $disk.Sku.Name -Location $disk.Location
                $totalDiskCost += $monthlyCost
                
                $unattachedDisks += [PSCustomObject]@{
                    SubscriptionName = $subscription.Name
                    SubscriptionId = $subscription.Id
                    DiskName = $disk.Name
                    ResourceGroup = $disk.ResourceGroupName
                    Location = $disk.Location
                    SizeGB = $disk.DiskSizeGB
                    SkuName = $disk.Sku.Name
                    CreatedTime = $disk.TimeCreated
                    MonthlyCost = $monthlyCost
                }
            }
        }
        
        # Get unused Public IPs
        $publicIPs = Get-AzPublicIpAddress
        foreach ($pip in $publicIPs) {
            if (-not $pip.IpConfiguration) {
                $monthlyCost = Get-PublicIPMonthlyCost -SkuName $pip.Sku.Name
                $totalIPCost += $monthlyCost
                
                $unusedPublicIPs += [PSCustomObject]@{
                    SubscriptionName = $subscription.Name
                    IPName = $pip.Name
                    ResourceGroup = $pip.ResourceGroupName
                    Location = $pip.Location
                    IPAddress = if ($pip.IpAddress) { $pip.IpAddress } else { "Not Assigned" }
                    SkuName = $pip.Sku.Name
                    MonthlyCost = $monthlyCost
                }
            }
        }
    }
    
    Write-Output "`nScan Complete:"
    Write-Output "  Unattached Disks: $($unattachedDisks.Count)"
    Write-Output "  Unused Public IPs: $($unusedPublicIPs.Count)"
    Write-Output "  Total Monthly Cost: `$$([math]::Round($totalDiskCost + $totalIPCost, 2))"
    
    # Generate HTML Report
    Write-Output "`nGenerating HTML report..."
    
    $htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Azure Unused Resources Report - $reportDate</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1400px; margin: 0 auto; background-color: white; padding: 30px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #0078d4; border-bottom: 3px solid #0078d4; padding-bottom: 10px; }
        h2 { color: #333; margin-top: 30px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin: 20px 0; }
        .summary-card { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; }
        .summary-card.cost { background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); }
        .summary-card h3 { margin: 0 0 10px 0; font-size: 14px; }
        .summary-card .value { font-size: 32px; font-weight: bold; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th { background-color: #0078d4; color: white; padding: 12px; text-align: left; }
        td { padding: 12px; border-bottom: 1px solid #ddd; }
        tr:hover { background-color: #f8f9fa; }
        .cost { color: #d32f2f; font-weight: bold; }
        .no-data { text-align: center; padding: 40px; color: #666; font-style: italic; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Azure Unused Resources Report</h1>
        <p><strong>Generated:</strong> $reportDate at $reportTime (Azure Automation)</p>
        <p><strong>Subscriptions Scanned:</strong> $($subscriptions.Count)</p>

        <div class="summary">
            <div class="summary-card">
                <h3>UNATTACHED DISKS</h3>
                <div class="value">$($unattachedDisks.Count)</div>
            </div>
            <div class="summary-card">
                <h3>UNUSED PUBLIC IPs</h3>
                <div class="value">$($unusedPublicIPs.Count)</div>
            </div>
            <div class="summary-card cost">
                <h3>MONTHLY COST</h3>
                <div class="value">$([math]::Round($totalDiskCost + $totalIPCost, 2))</div>
            </div>
        </div>

        <h2>Unattached Managed Disks</h2>
"@
    
    if ($unattachedDisks.Count -gt 0) {
        $htmlReport += "<table><thead><tr><th>Subscription</th><th>Disk Name</th><th>Resource Group</th><th>Size (GB)</th><th>SKU</th><th>Monthly Cost</th></tr></thead><tbody>"
        foreach ($disk in $unattachedDisks) {
            $htmlReport += "<tr><td>$($disk.SubscriptionName)</td><td>$($disk.DiskName)</td><td>$($disk.ResourceGroup)</td><td>$($disk.SizeGB)</td><td>$($disk.SkuName)</td><td class='cost'>`$$($disk.MonthlyCost)</td></tr>"
        }
        $htmlReport += "</tbody></table>"
    } else {
        $htmlReport += '<div class="no-data">No unattached disks found</div>'
    }
    
    $htmlReport += "<h2>Unused Public IP Addresses</h2>"
    
    if ($unusedPublicIPs.Count -gt 0) {
        $htmlReport += "<table><thead><tr><th>Subscription</th><th>IP Name</th><th>Resource Group</th><th>IP Address</th><th>SKU</th><th>Monthly Cost</th></tr></thead><tbody>"
        foreach ($pip in $unusedPublicIPs) {
            $htmlReport += "<tr><td>$($pip.SubscriptionName)</td><td>$($pip.IPName)</td><td>$($pip.ResourceGroup)</td><td>$($pip.IPAddress)</td><td>$($pip.SkuName)</td><td class='cost'>`$$($pip.MonthlyCost)</td></tr>"
        }
        $htmlReport += "</tbody></table>"
    } else {
        $htmlReport += '<div class="no-data">No unused Public IPs found</div>'
    }
    
    $htmlReport += "</div></body></html>"
    
    # Store report in Azure Storage (if configured)
    if ($StorageAccountName -and $StorageAccountResourceGroup) {
        Write-Output "Uploading report to Azure Storage..."
        
        $fileName = "Azure-UnusedResources-Report-$reportDate.html"
        $tempFile = [System.IO.Path]::GetTempFileName() + ".html"
        $htmlReport | Out-File -FilePath $tempFile -Encoding UTF8
        
        # Switch to storage account subscription context
        $storageAccount = Get-AzStorageAccount -ResourceGroupName $StorageAccountResourceGroup -Name $StorageAccountName
        $ctx = $storageAccount.Context
        
        # Create container if it doesn't exist
        $container = Get-AzStorageContainer -Name $StorageContainerName -Context $ctx -ErrorAction SilentlyContinue
        if (-not $container) {
            New-AzStorageContainer -Name $StorageContainerName -Context $ctx -Permission Off | Out-Null
        }
        
        # Upload file
        Set-AzStorageBlobContent -File $tempFile -Container $StorageContainerName -Blob $fileName -Context $ctx -Force | Out-Null
        Remove-Item $tempFile
        
        Write-Output "Report uploaded: $fileName"
        
        # Get SAS URL (valid for 30 days)
        $sasToken = New-AzStorageBlobSASToken -Container $StorageContainerName -Blob $fileName -Context $ctx -Permission r -ExpiryTime (Get-Date).AddDays(30)
        $reportUrl = "$($storageAccount.PrimaryEndpoints.Blob)$StorageContainerName/$fileName$sasToken"
        Write-Output "Report URL: $reportUrl"
    }
    
    # Send email via SendGrid (if configured)
    if ($SendGridApiKey -and $EmailTo -and $EmailFrom) {
        Write-Output "Sending email notification..."
        
        $headers = @{
            "Authorization" = "Bearer $SendGridApiKey"
            "Content-Type" = "application/json"
        }
        
        $body = @{
            personalizations = @(
                @{
                    to = @(@{ email = $EmailTo })
                    subject = "Azure Unused Resources Report - $reportDate"
                }
            )
            from = @{ email = $EmailFrom }
            content = @(
                @{
                    type = "text/html"
                    value = $htmlReport
                }
            )
        } | ConvertTo-Json -Depth 10
        
        try {
            Invoke-RestMethod -Uri "https://api.sendgrid.com/v3/mail/send" -Method Post -Headers $headers -Body $body
            Write-Output "Email sent successfully"
        } catch {
            Write-Warning "Failed to send email: $_"
        }
    }
    
    Write-Output "`n====================================="
    Write-Output "Runbook completed successfully"
    Write-Output "====================================="
    
} catch {
    Write-Error "Runbook failed: $_"
    throw
}
