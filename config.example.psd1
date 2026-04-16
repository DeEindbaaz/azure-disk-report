# Azure Resource Report Configuration
# Kopieer dit bestand naar config.psd1 en pas aan naar uw wensen

@{
    # Output Settings
    OutputPath = "C:\Reports\Azure"
    
    # Subscription Settings (laat leeg om alle subscriptions te scannen)
    SubscriptionIds = @(
        # "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
        # "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
    )
    
    # Email Settings
    Email = @{
        Enabled = $false
        To = @(
            "admin@company.com",
            "team@company.com"
        )
        From = "azure-reports@company.com"
        SmtpServer = "smtp.company.com"
        # SmtpPort = 587  # Optional
        # UseSSL = $true  # Optional
    }
    
    # Cost Estimation (USD per GB/month voor disks)
    # Pas aan op basis van uw Azure regio
    DiskCosts = @{
        Premium_LRS = 0.184      # Premium SSD
        StandardSSD_LRS = 0.145  # Standard SSD
        Standard_LRS = 0.040     # Standard HDD
        UltraSSD_LRS = 0.280     # Ultra SSD
    }
    
    # Public IP Costs (USD per maand)
    PublicIPCosts = @{
        Standard = 3.65
        Basic = 2.50
    }
    
    # Report Settings
    Report = @{
        OpenInBrowser = $true
        IncludeTimestamp = $true
        DateFormat = "yyyy-MM-dd"
    }
    
    # Filters (optioneel - uncomment om te gebruiken)
    # Filters = @{
    #     ExcludeResourceGroups = @("test-rg", "dev-rg")
    #     ExcludeLocations = @("westeurope")
    #     MinDiskSizeGB = 0  # Alleen disks groter dan deze waarde
    # }
}
