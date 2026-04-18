# Azure Unused Resources Weekly Report

## Overzicht

Dit PowerShell script genereert automatisch een wekelijks HTML-rapport van:
- **Unattached Managed Disks** - Schijven die niet aan een VM gekoppeld zijn
- **Unused Public IP Addresses** - Publieke IP-adressen die niet in gebruik zijn

Het rapport bevat ook geschatte maandelijkse kosten om u te helpen bij het optimaliseren van uw Azure-uitgaven.

## Bestanden in deze Repository

- **Generate-AzureResourceReport.ps1** - Hoofdscript voor lokale uitvoering
- **Azure-Automation-Runbook.ps1** - Versie voor Azure Automation (met Managed Identity)
- **Setup-WeeklyTask.ps1** - Installeert Windows Scheduled Task
- **Test-Configuration.ps1** - Valideert omgeving en Azure connectie
- **AZURE-AUTOMATION-GUIDE.md** - Complete deployment guide voor Azure Automation
- **QUICKSTART.md** - Snelle start instructies
- **README.md** - Deze file

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

### Optie 3: Azure Automation Runbook (Aanbevolen voor Enterprise)
Voor enterprise omgevingen kunt u dit script als Azure Automation Runbook deployen.

**Zie [AZURE-AUTOMATION-GUIDE.md](AZURE-AUTOMATION-GUIDE.md) voor complete deployment instructies.**

Quick setup:
1. Maak een **Automation Account** met PowerShell 5.1 runtime
2. Installeer modules in deze **specifieke versies** (compatibiliteit getest):
   - Az.Accounts 2.15.0
   - Az.Compute 4.31.0
   - Az.Network 4.20.0
   - Az.Storage 4.8.0
3. Upload **Azure-Automation-Runbook.ps1** (niet Generate-AzureResourceReport.ps1)
4. Schakel **Managed Identity** in
5. Wijs **Reader** + **Storage Account Contributor** rechten toe
6. Configureer **Storage Account** voor rapport opslag
7. Maak een **Schedule** aan (bijvoorbeeld: elke maandag 08:00)

**Belangrijk**: Module versies zijn kritisch! Az.Compute 7.x werkt niet met Az.Accounts 2.x in PS 5.1.

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

### Azure Automation: "Az.Compute module could not be loaded"
Dit is een module compatibiliteit probleem in PowerShell 5.1 runtime.

**Oplossing**: Gebruik Az.Compute 4.31.0 in plaats van 7.x
```powershell
# In Azure Portal -> Automation Account -> Modules
# Verwijder Az.Compute (als 7.x geïnstalleerd is)
# Installeer Az.Compute 4.31.0 met specifieke URL:
# https://www.powershellgallery.com/api/v2/package/Az.Compute/4.31.0

# Wacht tot ProvisioningState = Succeeded
```

**Werkende module combinatie voor PS 5.1**:
- Az.Accounts: 2.15.0 ✓
- Az.Compute: 4.31.0 ✓ (NIET 7.x)
- Az.Network: 4.20.0 ✓
- Az.Storage: 4.8.0 ✓

### "Insufficient permissions" errors
```powershell
# Check your current role assignments
Get-AzRoleAssignment -SignInName "your-email@company.com"

# Voor Azure Automation Managed Identity:
Get-AzRoleAssignment -ObjectId "managed-identity-principal-id"
```

### Azure Automation: Storage permission errors
Zorg dat Managed Identity beide rollen heeft:
- **Reader** op subscription (voor scannen resources)
- **Storage Account Contributor** op storage account (voor listKeys)

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
