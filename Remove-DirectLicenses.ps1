# Prerequisites: Install-Module Microsoft.Graph
# Run as Administrator

# 1. Define targets
$TargetSkuNames = @("SPE_E5", "SPE_E3")

$UserList = @(
#Insert list of user UPNs here, seperated by commas
)

# 2. Connect
# We need User.ReadWrite.All to assign/remove licenses
Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.Read.All" -NoWelcome

Write-Host "Fetching SKU definitions..." -ForegroundColor Cyan

# 3. Resolve SKU Names to IDs
# We need the specific GUIDs for SPE_E3 and SPE_E5 to pass to the remove command
try {
    $AllSkusResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/subscribedSkus"
    $AllSkus = $AllSkusResponse.value
    
    # Create a simple list of the Target SkuIds
    $TargetSkuIds = $AllSkus | Where-Object { $_.skuPartNumber -in $TargetSkuNames } | Select-Object -ExpandProperty skuId
}
catch {
    Write-Error "Failed to retrieve SKUs: $_"
    return
}

# 4. Process Users
foreach ($UPN in $UserList) {
    Write-Host "Processing $UPN..." -NoNewline

    try {
        # Get User and their current license states
        $User = Get-MgUser -UserId $UPN -Property Id, UserPrincipalName, LicenseAssignmentStates -ErrorAction Stop
        
        # Identify Direct Assignments to Remove
        $LicensesToRemove = @()

        if ($User.LicenseAssignmentStates) {
            foreach ($State in $User.LicenseAssignmentStates) {
                # Condition 1: Must be one of our Target SKUs (E3 or E5)
                # Condition 2: Must be DIRECT (AssignedByGroup is null)
                if (($State.SkuId -in $TargetSkuIds) -and ($null -eq $State.AssignedByGroup)) {
                    $LicensesToRemove += $State.SkuId
                }
            }
        }

        # Perform Removal if targets found
        if ($LicensesToRemove.Count -gt 0) {
            # Set-MgUserLicense expects -RemoveLicenses to be an array of SkuID strings
            Set-MgUserLicense -UserId $User.Id -RemoveLicenses $LicensesToRemove -AddLicenses @() -ErrorAction Stop
            
            Write-Host " [SUCCESS]" -ForegroundColor Green
            Write-Host "   - Removed $($LicensesToRemove.Count) license(s)." -ForegroundColor Gray
        }
        else {
            Write-Host " [SKIPPED]" -ForegroundColor Yellow
            Write-Host "   - No DIRECT assignments of SPE_E3/E5 found." -ForegroundColor Gray
        }
    }
    catch {
        Write-Host " [FAILED]" -ForegroundColor Red
        Write-Warning "   - Error: $($_.Exception.Message)"
    }
}

Write-Host "`nLicense cleanup complete." -ForegroundColor Cyan
