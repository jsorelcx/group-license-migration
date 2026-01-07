# Prerequisites: Install-Module Microsoft.Graph
# Run as Administrator or user with Directory Reader permissions

# 1. Define targets: Strictly SPE_E5 and SPE_E3
$TargetSkuNames = @("SPE_E5", "SPE_E3")

$UserList = @(
#Insert list of user UPNs here, seperated by commas
)

# 2. Connect
# This will open an interactive login prompt. Ensure you are logged into the correct tenant.
Connect-MgGraph -Scopes "User.Read.All", "Directory.Read.All", "Group.Read.All", "Organization.Read.All" -NoWelcome

Write-Host "Fetching global SKU data..." -ForegroundColor Cyan

# 3. Get all Subscribed SKUs (REST method for stability)
try {
    $AllSkusResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/subscribedSkus"
    $AllSkus = $AllSkusResponse.value
}
catch {
    Write-Error "Failed to retrieve SKUs: $_"
    return
}

$MasterReport = New-Object System.Collections.Generic.List[PSCustomObject]

# 4. Process Users
foreach ($UPN in $UserList) {
    Write-Host "Checking $UPN..." -ForegroundColor Yellow
    $FoundAnyTarget = $false
    
    try {
        $User = Get-MgUser -UserId $UPN -Property Id, DisplayName, UserPrincipalName, LicenseAssignmentStates -ErrorAction Stop

        if ($User.LicenseAssignmentStates) {
            foreach ($State in $User.LicenseAssignmentStates) {
                
                # Resolve Name
                $SkuInfo = $AllSkus | Where-Object { $_.skuId -eq $State.SkuId }
                $SkuName = if ($SkuInfo) { $SkuInfo.skuPartNumber } else { "Unknown" }

                # FILTER: Check if this license is in our strict target list
                if ($SkuName -in $TargetSkuNames) {
                    $FoundAnyTarget = $true
                    
                    # Resolve Source
                    if ($null -ne $State.AssignedByGroup) {
                        $AssignmentType = "Inherited (Group)"
                        try {
                            $GroupInfo = Get-MgGroup -GroupId $State.AssignedByGroup -ErrorAction Stop
                            $SourceName = $GroupInfo.DisplayName
                        }
                        catch { $SourceName = "Unknown Group ($($State.AssignedByGroup))" }
                    }
                    else {
                        $AssignmentType = "Direct"
                        $SourceName = "Direct Assignment"
                    }

                    $MasterReport.Add([PSCustomObject]@{
                        UserUPN        = $User.UserPrincipalName
                        DisplayName    = $User.DisplayName
                        License        = $SkuName
                        Type           = $AssignmentType
                        Source         = $SourceName
                        Status         = $State.State
                    })
                }
            }
        }
        
        # If user exists but has NONE of the target licenses
        if (-not $FoundAnyTarget) {
            $MasterReport.Add([PSCustomObject]@{
                UserUPN        = $User.UserPrincipalName
                DisplayName    = $User.DisplayName
                License        = "Not Assigned"
                Type           = "-"
                Source         = "-"
                Status         = "-"
            })
        }
    }
    catch {
        Write-Warning "Could not find user: $UPN"
    }
}

# 5. Output
Write-Host "`nStrict License Report (SPE_E5 & SPE_E3):" -ForegroundColor Green
$MasterReport | Format-Table -AutoSize
