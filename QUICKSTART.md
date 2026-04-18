# Quick Start Guide - Azure Resource Report

## Quick Start in 3 Steps

### Step 1: Install Azure PowerShell Modules
Open PowerShell as Administrator and execute:
```powershell
Install-Module -Name Az -Force -AllowClobber -Scope CurrentUser
```

### Step 2: Test the script manually
```powershell
# Navigate to the script directory
cd "c:\Code\Projects\Personal\disk-ip-weeky-report"

# Execute the script
.\Generate-AzureResourceReport.ps1
```

You will be prompted to log in to Azure. After successful login, the report will be generated.

### Step 3: Automate weekly (optional)
```powershell
# Open PowerShell as Administrator
.\Setup-WeeklyTask.ps1 -ReportPath "C:\Reports\Azure"
```

## Checklist

- [ ] Azure PowerShell modules installed
- [ ] Azure account with Reader permissions
- [ ] Script successfully executed manually
- [ ] Report generated and opened in browser
- [ ] (Optional) Weekly task configured
- [ ] (Optional) Email notifications configured

## Frequently Asked Questions

### Q: What Azure permissions do I need?
**A:** At minimum **Reader** permissions on the subscriptions you want to scan.

### Q: How long does scanning take?
**A:** Approximately 30 seconds per subscription, depending on the number of resources.

### Q: Are resources deleted?
**A:** No! The script only reads information and generates a report. It does not delete any resources.

### Q: Can I scan multiple subscriptions at once?
**A:** Yes, by default the script scans all subscriptions you have access to.

### Q: How accurate are the cost estimates?
**A:** The costs are estimates based on public Azure pricing (US East). Actual costs may vary by region and EA agreement.

### Q: Can I run this in Azure Automation?
**A:** Yes! The script is fully compatible with Azure Automation Runbooks. Use a Managed Identity for authentication.

## Troubleshooting

### Problem: "Cannot connect to Azure"
**Solution:**
```powershell
Clear-AzContext -Force
Connect-AzAccount
```

### Problem: "Module Az.Compute not found"
**Solution:**
```powershell
Install-Module Az.Compute -Force -Scope CurrentUser
Install-Module Az.Network -Force -Scope CurrentUser
```

### Problem: "Access Denied"
**Solution:** Ask your Azure administrator for Reader permissions on the relevant subscription(s), or assign them yourself if you have the ability to do so.

## Need Help?

See the complete [README.md](README.md) for detailed information.
