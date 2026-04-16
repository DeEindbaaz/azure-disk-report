<#
.SYNOPSIS
    Generates a weekly HTML report of unattached Azure disks and unused Public IPs.

.DESCRIPTION
    This script scans Azure subscriptions for:
    - Unattached managed disks
    - Unused Public IP addresses
    And generates a detailed HTML report with cost information.

.PARAMETER OutputPath
    Path where the HTML report will be saved. Default: current directory

.PARAMETER SendEmail
    If specified, sends the report via email (requires email configuration)

.PARAMETER EmailTo
    Email recipient address(es) - comma separated

.PARAMETER EmailFrom
    Email sender address

.PARAMETER SmtpServer
    SMTP server address

.PARAMETER SubscriptionIds
    Specific subscription IDs to scan. If not provided, scans all accessible subscriptions.

.EXAMPLE
    .\Generate-AzureResourceReport.ps1 -OutputPath "C:\Reports"

.EXAMPLE
    .\Generate-AzureResourceReport.ps1 -SendEmail -EmailTo "admin@company.com" -EmailFrom "reports@company.com" -SmtpServer "smtp.company.com"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = $PWD.Path,
    
    [Parameter(Mandatory=$false)]
    [switch]$SendEmail,
    
    [Parameter(Mandatory=$false)]
    [string[]]$EmailTo,
    
    [Parameter(Mandatory=$false)]
    [string]$EmailFrom,
    
    [Parameter(Mandatory=$false)]
    [string]$SmtpServer,

    [Parameter(Mandatory=$false)]
    [string[]]$SubscriptionIds
)

#Requires -Modules Az.Accounts, Az.Compute, Az.Network

# Initialize variables
$reportDate = Get-Date -Format "yyyy-MM-dd"
$reportTime = Get-Date -Format "HH:mm:ss"
$reportFileName = "Azure-UnusedResources-Report-$reportDate.html"
$reportPath = Join-Path -Path $OutputPath -ChildPath $reportFileName

# Arrays to store results
$unattachedDisks = @()
$unusedPublicIPs = @()
$totalDiskCost = 0
$totalIPCost = 0

Write-Host "Starting Azure Resource Report Generation..."
Write-Host "Report Date: $reportDate $reportTime"

# Function to calculate monthly disk cost (estimated)
function Get-DiskMonthlyCost {
    param(
        [string]$DiskSize,
        [string]$SkuName,
        [string]$Location
    )
    
    # Simplified cost estimation (EUR per month) - adjust based on your region
    $costPerGB = switch ($SkuName) {
        'Premium_LRS' { 0.184 }     # Premium SSD
        'StandardSSD_LRS' { 0.145 } # Standard SSD
        'Standard_LRS' { 0.040 }    # Standard HDD
        'UltraSSD_LRS' { 0.280 }    # Ultra SSD
        default { 0.100 }
    }
    
    return [math]::Round([int]$DiskSize * $costPerGB, 2)
}

# Function to get Public IP monthly cost (estimated)
function Get-PublicIPMonthlyCost {
    param(
        [string]$SkuName
    )
    
    # Azure Public IP pricing (EUR per month) - Basic/Standard
    return switch ($SkuName) {
        'Standard' { 3.65 }   # ~$0.005/hour
        'Basic' { 2.50 }
        default { 2.50 }
    }
}

try {
    # Check if already connected to Azure
    $context = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $context) {
        Write-Host "Connecting to Azure..."
        Connect-AzAccount
    } else {
        Write-Host "Using existing Azure connection: $($context.Account.Id)"
    }

    # Get subscriptions to scan
    if ($SubscriptionIds) {
        $subscriptions = $SubscriptionIds | ForEach-Object { 
            Get-AzSubscription -SubscriptionId $_ 
        }
    } else {
        Write-Host "Retrieving all accessible subscriptions..."
        $subscriptions = Get-AzSubscription | Where-Object { $_.State -eq 'Enabled' }
    }

    Write-Host "Found $($subscriptions.Count) subscription(s) to scan"

    # Scan each subscription
    foreach ($subscription in $subscriptions) {
        Write-Host "`nScanning subscription: $($subscription.Name) ($($subscription.Id))"
        Set-AzContext -SubscriptionId $subscription.Id | Out-Null

        # Get unattached disks
        Write-Host "  - Checking for unattached disks..."
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
                    SkuTier = $disk.Sku.Tier
                    CreatedTime = $disk.TimeCreated
                    MonthlyCost = $monthlyCost
                }
            }
        }
        Write-Host "    Found $($unattachedDisks.Count) unattached disk(s) in this subscription"

        # Get unused Public IPs
        Write-Host "  - Checking for unused Public IPs..."
        $publicIPs = Get-AzPublicIpAddress
        
        foreach ($pip in $publicIPs) {
            if (-not $pip.IpConfiguration) {
                $monthlyCost = Get-PublicIPMonthlyCost -SkuName $pip.Sku.Name
                $totalIPCost += $monthlyCost
                
                $unusedPublicIPs += [PSCustomObject]@{
                    SubscriptionName = $subscription.Name
                    SubscriptionId = $subscription.Id
                    IPName = $pip.Name
                    ResourceGroup = $pip.ResourceGroupName
                    Location = $pip.Location
                    IPAddress = if ($pip.IpAddress) { $pip.IpAddress } else { "Not Assigned" }
                    AllocationMethod = $pip.PublicIpAllocationMethod
                    SkuName = $pip.Sku.Name
                    MonthlyCost = $monthlyCost
                }
            }
        }
        Write-Host "    Found $($unusedPublicIPs.Count) unused Public IP(s) in this subscription"
    }

    Write-Host "`nGenerating HTML report..."

    # Generate HTML Report
    $htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Azure Unused Resources Report - $reportDate</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
            background-color: white;
            padding: 30px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            border-radius: 8px;
        }
        h1 {
            color: #0078d4;
            border-bottom: 3px solid #0078d4;
            padding-bottom: 10px;
        }
        h2 {
            color: #333;
            margin-top: 30px;
            border-left: 4px solid #0078d4;
            padding-left: 10px;
        }
        .summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }
        .summary-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .summary-card.cost {
            background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
        }
        .summary-card h3 {
            margin: 0 0 10px 0;
            font-size: 14px;
            opacity: 0.9;
        }
        .summary-card .value {
            font-size: 32px;
            font-weight: bold;
            margin: 5px 0;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
            box-shadow: 0 2px 4px rgba(0,0,0,0.05);
        }
        th {
            background-color: #0078d4;
            color: white;
            padding: 12px;
            text-align: left;
            font-weight: 600;
            position: sticky;
            top: 0;
        }
        td {
            padding: 12px;
            border-bottom: 1px solid #ddd;
        }
        tr:hover {
            background-color: #f8f9fa;
        }
        tr:nth-child(even) {
            background-color: #f9f9f9;
        }
        .cost {
            color: #d32f2f;
            font-weight: bold;
        }
        .no-data {
            text-align: center;
            padding: 40px;
            color: #666;
            font-style: italic;
            background-color: #f9f9f9;
            border-radius: 4px;
        }
        .footer {
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
            color: #666;
            font-size: 12px;
            text-align: center;
        }
        .warning {
            background-color: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 15px;
            margin: 20px 0;
            border-radius: 4px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Azure Unused Resources Report</h1>
        <p><strong>Report Generated:</strong> $reportDate at $reportTime</p>
        <p><strong>Subscriptions Scanned:</strong> $($subscriptions.Count)</p>

        <div class="summary">
            <div class="summary-card">
                <h3>UNATTACHED DISKS</h3>
                <div class="value">$($unattachedDisks.Count)</div>
                <p>Total unused disks found</p>
            </div>
            <div class="summary-card">
                <h3>UNUSED PUBLIC IPs</h3>
                <div class="value">$($unusedPublicIPs.Count)</div>
                <p>Total unused IPs found</p>
            </div>
            <div class="summary-card cost">
                <h3>ESTIMATED MONTHLY COST</h3>
                <div class="value">$([math]::Round($totalDiskCost + $totalIPCost, 2))</div>
                <p>USD per month (approx.)</p>
            </div>
        </div>

        <div class="warning">
            <strong>Action Required:</strong> Review and delete unused resources to optimize costs. 
            Estimated annual savings: <strong>`$$([math]::Round(($totalDiskCost + $totalIPCost) * 12, 2))</strong>
        </div>

        <h2>Unattached Managed Disks ($($unattachedDisks.Count))</h2>
"@

    if ($unattachedDisks.Count -gt 0) {
        $htmlReport += @"
        <table>
            <thead>
                <tr>
                    <th>Subscription</th>
                    <th>Disk Name</th>
                    <th>Resource Group</th>
                    <th>Location</th>
                    <th>Size (GB)</th>
                    <th>SKU</th>
                    <th>Created</th>
                    <th>Monthly Cost (USD)</th>
                </tr>
            </thead>
            <tbody>
"@
        foreach ($disk in $unattachedDisks) {
            $htmlReport += @"
                <tr>
                    <td>$($disk.SubscriptionName)</td>
                    <td>$($disk.DiskName)</td>
                    <td>$($disk.ResourceGroup)</td>
                    <td>$($disk.Location)</td>
                    <td>$($disk.SizeGB)</td>
                    <td>$($disk.SkuName)</td>
                    <td>$($disk.CreatedTime.ToString("yyyy-MM-dd"))</td>
                    <td class="cost">`$$($disk.MonthlyCost)</td>
                </tr>
"@
        }
        $htmlReport += @"
            </tbody>
        </table>
        <p><strong>Total Disk Cost:</strong> <span class="cost">`$$([math]::Round($totalDiskCost, 2))/month</span></p>
"@
    } else {
        $htmlReport += '<div class="no-data">No unattached disks found - Great job!</div>'
    }

    $htmlReport += @"
        <h2>Unused Public IP Addresses ($($unusedPublicIPs.Count))</h2>
"@

    if ($unusedPublicIPs.Count -gt 0) {
        $htmlReport += @"
        <table>
            <thead>
                <tr>
                    <th>Subscription</th>
                    <th>IP Name</th>
                    <th>Resource Group</th>
                    <th>Location</th>
                    <th>IP Address</th>
                    <th>Allocation</th>
                    <th>SKU</th>
                    <th>Monthly Cost (USD)</th>
                </tr>
            </thead>
            <tbody>
"@
        foreach ($pip in $unusedPublicIPs) {
            $htmlReport += @"
                <tr>
                    <td>$($pip.SubscriptionName)</td>
                    <td>$($pip.IPName)</td>
                    <td>$($pip.ResourceGroup)</td>
                    <td>$($pip.Location)</td>
                    <td>$($pip.IPAddress)</td>
                    <td>$($pip.AllocationMethod)</td>
                    <td>$($pip.SkuName)</td>
                    <td class="cost">`$$($pip.MonthlyCost)</td>
                </tr>
"@
        }
        $htmlReport += @"
            </tbody>
        </table>
        <p><strong>Total IP Cost:</strong> <span class="cost">`$$([math]::Round($totalIPCost, 2))/month</span></p>
"@
    } else {
        $htmlReport += '<div class="no-data">No unused Public IPs found - Great job!</div>'
    }

    $htmlReport += @"
        <div class="footer">
            <p>This report was automatically generated by Azure Resource Optimization Script</p>
            <p>Report Path: $reportPath</p>
        </div>
    </div>
</body>
</html>
"@

    # Save the report
    $htmlReport | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Host "`nReport generated successfully!"
    Write-Host "Report saved to: $reportPath"

    # Display summary
    Write-Host "`nSUMMARY:"
    Write-Host "  Unattached Disks: $($unattachedDisks.Count)"
    Write-Host "  Unused Public IPs: $($unusedPublicIPs.Count)"
    Write-Host "  Estimated Monthly Cost: `$$([math]::Round($totalDiskCost + $totalIPCost, 2))"
    Write-Host "  Estimated Yearly Cost: `$$([math]::Round(($totalDiskCost + $totalIPCost) * 12, 2))"

    # Send email if requested
    if ($SendEmail) {
        if (-not $EmailTo -or -not $EmailFrom -or -not $SmtpServer) {
            Write-Warning "Email parameters incomplete. Skipping email send."
        } else {
            try {
                Write-Host "`nSending email report..."
                $emailSubject = "Azure Unused Resources Report - $reportDate"
                $emailBody = "Please find attached the Azure unused resources report for $reportDate.`n`n"
                $emailBody += "Summary:`n"
                $emailBody += "- Unattached Disks: $($unattachedDisks.Count)`n"
                $emailBody += "- Unused Public IPs: $($unusedPublicIPs.Count)`n"
                $emailBody += "- Estimated Monthly Cost: `$$([math]::Round($totalDiskCost + $totalIPCost, 2))`n"
                
                Send-MailMessage -To $EmailTo -From $EmailFrom -Subject $emailSubject `
                    -Body $emailBody -SmtpServer $SmtpServer -Attachments $reportPath
                
                Write-Host "Email sent successfully!"
            } catch {
                Write-Warning "Failed to send email: $_"
            }
        }
    }

    # Open the report in default browser
    Write-Host "`nOpening report in browser..."
    Start-Process $reportPath

} catch {
    Write-Error "An error occurred: $_"
    Write-Error $_.ScriptStackTrace
    exit 1
}
