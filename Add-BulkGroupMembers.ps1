# Prerequisites: Install-Module Microsoft.Graph
# Run as Administrator

# 1. Configuration
$TargetGroupId = "AAAAAAAAAAAA-AAAAAAAAAAA-AAAAAAAAAA" # <--- Paste the Group Object ID here
$UserList = @(
#Insert list of user UPNs here, seperated by commas
)

# 2. Connect
# We need GroupMember.ReadWrite.All to modify group membership
Connect-MgGraph -Scopes "GroupMember.ReadWrite.All", "User.Read.All" -NoWelcome

Write-Host "Starting bulk addition to group..." -ForegroundColor Cyan

# 3. Process Users
foreach ($UPN in $UserList) {
    try {
        # A. Resolve UPN to User Object ID (Required for the 'New-MgGroupMember' command)
        $User = Get-MgUser -UserId $UPN -ErrorAction Stop
        
        # B. Add to Group
        # 'New-MgGroupMember' is the command to add a member
        New-MgGroupMember -GroupId $TargetGroupId -DirectoryObjectId $User.Id -ErrorAction Stop
        
        Write-Host "SUCCESS: Added $UPN" -ForegroundColor Green
    }
    catch {
        # Check if the error is simply that they are already in the group
        if ($_.Exception.Message -match "One or more added object references already exist") {
            Write-Host "SKIPPED: $UPN is already a member." -ForegroundColor Gray
        }
        # Check if the user ID wasn't found
        elseif ($_.CategoryInfo.Reason -eq "Request_ResourceNotFound") {
            Write-Warning "FAILED: User '$UPN' not found in directory."
        }
        else {
            Write-Error "FAILED: Could not add $UPN - $($_.Exception.Message)"
        }
    }
}

Write-Host "`nOperation Complete." -ForegroundColor Cyan
