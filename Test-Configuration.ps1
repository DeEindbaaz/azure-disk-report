# Test Script - Validatie van Azure Configuratie
# Dit script test of alles correct geconfigureerd is

Write-Host "Azure Resource Report - Configuration Test"
Write-Host "=" * 60

$allPassed = $true

# Test 1: Check PowerShell Version
Write-Host "`n[1/5] Checking PowerShell Version..."
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -ge 5) {
    Write-Host "  OK - PowerShell $($psVersion.ToString())"
} else {
    Write-Host "  ERROR - PowerShell version too old. Need 5.0 or higher."
    $allPassed = $false
}

# Test 2: Check Azure Modules
Write-Host "`n[2/5] Checking Azure PowerShell Modules..."
$requiredModules = @('Az.Accounts', 'Az.Compute', 'Az.Network')
foreach ($module in $requiredModules) {
    $installed = Get-Module -ListAvailable -Name $module
    if ($installed) {
        Write-Host "  OK - $module - Installed (v$($installed[0].Version))"
    } else {
        Write-Host "  ERROR - $module - NOT INSTALLED"
        Write-Host "     Install with: Install-Module -Name $module -Force"
        $allPassed = $false
    }
}

# Test 3: Check Script Files
Write-Host "`n[3/5] Checking Script Files..."
$scriptFile = Join-Path $PSScriptRoot "Generate-AzureResourceReport.ps1"
if (Test-Path $scriptFile) {
    Write-Host "  OK - Main script found"
} else {
    Write-Host "  ERROR - Main script NOT FOUND: $scriptFile"
    $allPassed = $false
}

# Test 4: Check Azure Connection
Write-Host "`n[4/5] Checking Azure Connection..."
try {
    $context = Get-AzContext -ErrorAction SilentlyContinue
    if ($context) {
        Write-Host "  OK - Connected to Azure"
        Write-Host "     Account: $($context.Account.Id)"
        Write-Host "     Subscription: $($context.Subscription.Name)"
        
        # Try to get subscriptions
        $subs = Get-AzSubscription -ErrorAction SilentlyContinue
        Write-Host "     Accessible Subscriptions: $($subs.Count)"
    } else {
        Write-Host "  WARNING - Not connected to Azure"
        Write-Host "     Run 'Connect-AzAccount' to connect"
    }
} catch {
    Write-Host "  WARNING - Could not check Azure connection: $_"
}

# Test 5: Check Permissions
Write-Host "`n[5/5] Checking Permissions..."
try {
    if ($context) {
        # Try to get a disk (this will fail if no Reader permission)
        $testDisks = Get-AzDisk -ErrorAction SilentlyContinue | Select-Object -First 1
        Write-Host "  OK - Can read Azure resources"
    } else {
        Write-Host "  WARNING - Cannot test - not connected to Azure"
    }
} catch {
    Write-Host "  ERROR - Permission issue: $_"
    Write-Host "     Ensure you have Reader rights on subscriptions"
    $allPassed = $false
}

# Summary
Write-Host "`n" + "=" * 60
if ($allPassed -and $context) {
    Write-Host "All tests passed! You're ready to generate reports."
    Write-Host "`nNext step:"
    Write-Host "  .\Generate-AzureResourceReport.ps1"
} elseif ($context) {
    Write-Host "Some tests failed. Please fix the issues above."
} else {
    Write-Host "Please connect to Azure first: Connect-AzAccount"
}

Write-Host ""
