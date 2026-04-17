# Azure Unused Resources Weekly Report

## Overzicht

Dit PowerShell script genereert automatisch een wekelijks HTML-rapport van:
- **Unattached Managed Disks** - Schijven die niet aan een VM gekoppeld zijn
- **Unused Public IP Addresses** - Publieke IP-adressen die niet in gebruik zijn

Het rapport bevat ook geschatte maandelijkse kosten om u te helpen bij het optimaliseren van uw Azure-uitgaven.

## Vereisten

### PowerShell Modules
Het script vereist de volgende Azure PowerShell modules:
```powershell
Install-Module -Name Az.Accounts -Force -AllowClobber
Install-Module -Name Az.Compute -Force -AllowClobber
Install-Module -Name Az.Network -Force -AllowClobber
```

### Azure Permissions
Uw Azure-account moet minimaal **Reader** permissies hebben op de subscriptions die u wilt scannen.

## Gebruik

### Basis Gebruik
```powershell
# Genereer rapport in huidige directory
.\Generate-AzureResourceReport.ps1

# Genereer rapport in specifieke directory
.\Generate-AzureResourceReport.ps1 -OutputPath "C:\Reports"

# Scan specifieke subscriptions
.\Generate-AzureResourceReport.ps1 -SubscriptionIds "sub-id-1","sub-id-2"
```

### Met Email Notificatie
```powershell
.\Generate-AzureResourceReport.ps1 `
    -SendEmail `
    -EmailTo "admin@company.com","team@company.com" `
    -EmailFrom "azure-reports@company.com" `
    -SmtpServer "smtp.company.com"
```

## Wekelijkse Automatisering

### Optie 1: Windows Task Scheduler
Gebruik het meegeleverde script om een wekelijkse taak in te stellen:

```powershell
.\Setup-WeeklyTask.ps1 -ReportPath "C:\Reports"
```

Dit creëert een Windows Scheduled Task die elke maandag om 08:00 het rapport genereert.

### Optie 2: Handmatige Task Scheduler Setup
1. Open **Task Scheduler**
2. Klik op **Create Task**
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

### Optie 3: Azure Automation Runbook
Voor enterprise omgevingen kunt u dit script als Azure Automation Runbook deployen:
1. Maak een **Automation Account**
2. Import het script als **Runbook**
3. Schakel **Managed Identity** in
4. Wijs **Reader** rechten toe aan de Managed Identity
5. Maak een **Schedule** aan (wekelijks)

## Rapport Features

Het gegenereerde HTML rapport bevat:
- **Summary Dashboard** met totaal aantal resources en kosten
- **Detailed Disk Table** met naam, grootte, SKU, en kosten
- **Public IP Table** met allocation method en kosten
- **Cost Estimates** per resource en totaal
- **Action Items** met besparingsmogelijkheden

## Tips voor Kostenbesparing

Na het bekijken van het rapport:

### Voor Unattached Disks:
```powershell
# Verwijder een disk (LET OP: Data wordt verwijderd!)
Remove-AzDisk -ResourceGroupName "RG-Name" -DiskName "DiskName" -Force

# Maak eerst een snapshot (backup)
$disk = Get-AzDisk -ResourceGroupName "RG-Name" -DiskName "DiskName"
$snapshotConfig = New-AzSnapshotConfig -SourceUri $disk.Id -CreateOption Copy -Location $disk.Location
New-AzSnapshot -Snapshot $snapshotConfig -SnapshotName "backup-snapshot" -ResourceGroupName "RG-Name"
```

### Voor Unused Public IPs:
```powershell
# Verwijder een ongebruikt Public IP
Remove-AzPublicIpAddress -ResourceGroupName "RG-Name" -Name "IP-Name" -Force
```

## Security Best Practices

1. **Gebruik Managed Identity** wanneer mogelijk (Azure Automation)
2. **Beperk access** tot alleen de benodigde subscriptions
3. **Versleutel email credentials** als u SMTP gebruikt
4. **Review rapporten** regelmatig en neem actie op oude resources
5. **Test eerst** in een development omgeving

## Output

Het script genereert:
- **HTML Rapport**: `Azure-UnusedResources-Report-YYYY-MM-DD.html`
- **Console Output**: Samenvatting met aantallen en kosten
- **Auto-open**: Rapport wordt automatisch in browser geopend

## Troubleshooting

### "Module not found" errors
```powershell
# Update alle Az modules
Update-Module -Name Az -Force
```

### "Insufficient permissions" errors
```powershell
# Check your current role assignments
Get-AzRoleAssignment -SignInName "your-email@company.com"
```

### "Connect-AzAccount" hangt
```powershell
# Clear cached credentials
Clear-AzContext -Force
Connect-AzAccount
```

## Contact & Support

Voor vragen of problemen, maak een issue aan in de repository.

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
