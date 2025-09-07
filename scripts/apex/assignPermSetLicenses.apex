/*
This script assigns the necessary Permission Set LICENSES to the default user
and provides detailed logging for any licenses not found in the org.
It is designed to be idempotent and will not re-assign existing licenses.
*/
User targetUser = [SELECT Id FROM User WHERE Name = 'User User' LIMIT 1];

List<String> pslDeveloperNames = new List<String>{
    'BREDesigner', 
    'BRERuntime', 
    'BillingAdvancedPsl', 
    'CorePricingDesignTime',
    'CorePricingRunTime', 
    'DataProcessingEnginePsl', 
    'ObligationManagementUser', 
    'ProductCatalogManagementAdministratorPsl', 
    'ProductCatalogManagementViewerPsl', 
    'ProductDiscoveryUserPsl', 
    'RevLifecycleMgmtBillingPsl', 
    'RevenueLifecycleManagementUserPsl', 
    'SalesforcePaymentsIntUserPsl', 
    'SonicEmbeddedStorePsl'
};

// Query for all available licenses from the master list
Map<String, PermissionSetLicense> foundLicenses = new Map<String, PermissionSetLicense>();
for (PermissionSetLicense psl : [SELECT Id, DeveloperName FROM PermissionSetLicense WHERE DeveloperName IN :pslDeveloperNames]) {
    foundLicenses.put(psl.DeveloperName, psl);
}

// Compare the master list against what was found and log any discrepancies
for (String pslName : pslDeveloperNames) {
    if (!foundLicenses.containsKey(pslName)) {
        System.debug('ERROR: Permission Set License not found in this org: ' + pslName);
    }
}

// Get all Permission Set Licenses already assigned to the user to avoid duplicates.
Set<Id> alreadyAssignedPSLIds = new Set<Id>();
for (PermissionSetLicenseAssign psla : [
    SELECT PermissionSetLicenseId
    FROM PermissionSetLicenseAssign
    WHERE AssigneeId = :targetUser.Id
]) {
    alreadyAssignedPSLIds.add(psla.PermissionSetLicenseId);
}

// Create a list to hold the new license assignments.
List<PermissionSetLicenseAssign> licensesToAssign = new List<PermissionSetLicenseAssign>();

// Loop through the licenses that were ACTUALLY FOUND in the org
for (PermissionSetLicense psl : foundLicenses.values()) {
    // Check if the license is not already assigned
    if (!alreadyAssignedPSLIds.contains(psl.Id)) {
        licensesToAssign.add(new PermissionSetLicenseAssign(
            AssigneeId = targetUser.Id,
            PermissionSetLicenseId = psl.Id
        ));
    } else {
        System.debug('INFO: License already assigned to user: ' + psl.DeveloperName);
    }
}

// Insert the new license assignments if any exist.
if (!licensesToAssign.isEmpty()) {
    insert licensesToAssign;
    System.debug('SUCCESS: Successfully assigned ' + licensesToAssign.size() + ' new permission set licenses.');
} else {
    System.debug('INFO: No new permission set licenses to assign. The user may already have them all.');
}