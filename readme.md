# Microsoft 365 Group-Based License Migration

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue) ![License](https://img.shields.io/badge/License-GPLv3-green)

## Overview
This toolkit automates the migration of Microsoft 365 users from direct license assignments to **Group-Based Licensing**. It is designed to target specific SKUs (SPE_E3 and SPE_E5) and ensures a safe transition by auditing the state before and after changes.

## Repository Contents
* **`Audit-TargetLicenses.ps1`**: Generates a report of current license assignment types (Direct vs. Inherited).
* **`Add-BulkGroupMembers.ps1`**: Adds a list of users to the target licensing group in Azure AD / Entra ID.
* **`Remove-DirectLicenses.ps1`**: Removes the specific direct assignments once the group license is active.

## Prerequisites
* **PowerShell 5.1** or later.
* **Microsoft.Graph module** installed (`Install-Module Microsoft.Graph`).
* **Permissions:** User must be an Administrator or have equivalent Graph API scopes (`User.ReadWrite.All`, `GroupMember.ReadWrite.All`).

## Migration Workflow

### 1. Audit Current State
Run `Audit-TargetLicenses.ps1` to identify the current license status of your target users.
1.  Open the script.
2.  Populate the `$UserList` array with the target User Principal Names (UPNs).
3.  Run the script.
4.  **Verify:** Ensure the output shows the users currently have "Direct" assignments for E3/E5.

### 2. Add Users to Licensing Group
Use `Add-BulkGroupMembers.ps1` to provision the group license.
1.  Obtain the **Object ID** of your target licensing group from the Azure Portal.
2.  Paste the ID into the `$TargetGroupId` variable at the top of the script.
3.  Populate the `$UserList` array with the same users from Step 1.
4.  Run the script.

### 3. Remove Direct Assignments
Once users are members of the group, use `Remove-DirectLicenses.ps1` to clean up the redundant direct licenses.
1.  Populate the `$UserList` array.
2.  Run the script.
3.  *Note: The script includes safety checks to ensure it only removes the specific target SKUs.*

### 4. Final Validation
Re-run `Audit-TargetLicenses.ps1`.
* **Success Criteria:** The output should now show the License Type as **"Inherited (Group)"** for all users.

## Disclaimer
These scripts are provided "as is" for educational and portfolio purposes. Always test in a non-production environment or with a small pilot group before running against production users.

## License
This project is licensed under the [GNU General Public License v3.0](LICENSE).
