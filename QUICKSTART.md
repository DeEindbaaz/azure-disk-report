# Quick Start Guide - Azure Resource Report

## Snelstart in 3 stappen

### Stap 1: Installeer Azure PowerShell Modules
Open PowerShell als Administrator en voer uit:
```powershell
Install-Module -Name Az -Force -AllowClobber -Scope CurrentUser
```

### Stap 2: Test het script handmatig
```powershell
# Navigeer naar de script directory
cd "c:\Code\Projects\Personal\disk-ip-weeky-report"

# Voer het script uit
.\Generate-AzureResourceReport.ps1
```

Je wordt gevraagd om in te loggen bij Azure. Na succesvolle login wordt het rapport gegenereerd.

### Stap 3: Automatiseer wekelijks (optioneel)
```powershell
# Open PowerShell als Administrator
.\Setup-WeeklyTask.ps1 -ReportPath "C:\Reports\Azure"
```

## Checklist

- [ ] Azure PowerShell modules geïnstalleerd
- [ ] Azure account met Reader rechten
- [ ] Script succesvol handmatig uitgevoerd
- [ ] Rapport gegenereerd en geopend in browser
- [ ] (Optioneel) Wekelijkse taak ingesteld
- [ ] (Optioneel) Email notificaties geconfigureerd

## Veelgestelde Vragen

### Q: Welke Azure rechten heb ik nodig?
**A:** Minimaal **Reader** rechten op de subscriptions die je wilt scannen.

### Q: Hoelang duurt het scannen?
**A:** Ongeveer 30 seconden per subscription, afhankelijk van het aantal resources.

### Q: Worden er resources verwijderd?
**A:** Nee! Het script leest alleen informatie en genereert een rapport. Het verwijdert geen resources.

### Q: Kan ik meerdere subscriptions tegelijk scannen?
**A:** Ja, standaard scant het script alle subscriptions waartoe je toegang hebt.

### Q: Hoe nauwkeurig zijn de kostenschattingen?
**A:** De kosten zijn schattingen op basis van publieke Azure prijzen (US East). Werkelijke kosten kunnen variëren per regio en EA-agreement.

### Q: Kan ik dit in Azure Automation draaien?
**A:** Ja! Het script is volledig compatibel met Azure Automation Runbooks. Gebruik een Managed Identity voor authenticatie.

## Troubleshooting

### Probleem: "Cannot connect to Azure"
**Oplossing:**
```powershell
Clear-AzContext -Force
Connect-AzAccount
```

### Probleem: "Module Az.Compute not found"
**Oplossing:**
```powershell
Install-Module Az.Compute -Force -Scope CurrentUser
Install-Module Az.Network -Force -Scope CurrentUser
```

### Probleem: "Access Denied"
**Oplossing:** Vraag je Azure administrator om Reader rechten op de betreffende subscription(s), of ken deze aan jezelf toe als je daar de mogelijkheid toe hebt.

## Hulp nodig?

Bekijk de volledige [README.md](README.md) voor gedetailleerde informatie.
