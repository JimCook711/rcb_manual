/*
This script assigns the necessary Permission Sets to the default user.
It is designed to be idempotent and will not re-assign existing permissions.
*/
User targetUser = [SELECT Id FROM User WHERE Name = 'User User' LIMIT 1];

// Existing assignments to avoid duplicates
Set<Id> alreadyAssignedPS = new Set<Id>();
for (PermissionSetAssignment psa : [SELECT PermissionSetId FROM PermissionSetAssignment WHERE AssigneeId = :targetUser.Id]) {
    alreadyAssignedPS.add(psa.PermissionSetId);
}

List<String> permSetNames = new List<String>{
    'AnalyticsStoreUser',
    'BREDesigner',
    'BRERuntime',
    'CorePricingAdmin',
    'CorePricingDesignTimeUser',
    'CorePricingManager',
    'CorePricingRunTimeUser',
    'DataProcessingEngineUser',
    'PaymentsAdministrator',
    'PlaceSupplementalOrders',
    'ProductCatalogManagementAdministrator',
    'ProductCatalogManagementViewer',
    'ProductDiscoveryAdmin',
    'ProductDiscoveryUser',
    'RevLifecycleManagementCoreCPQAssetization',
    'RevLifecycleManagementCreateOrderFromQuote',
    'RevLifecycleManagementCreateContractApi',
    'RevLifecycleManagementInitiateAmendmentApi',
    'RevLifecycleManagementInitiateCancellationApi',
    'RevLifecycleManagementInitiateRenewalApi',
    'RevLifecycleManagementPlaceOrderApi',
    'RevLifecycleManagementProductAndPriceConfigurationApi',
    'RevenueLifecycleManagementBillingAdmin',
    'RevenueLifecycleManagementBillingCreateInvoiceFromBillingScheduleApi',
    'RevenueLifecycleManagementBillingOperations',
    'RevenueLifecycleManagementBillingVoidPostedInvoiceApi',
    'RevenueLifecycleManagementCreateBillingScheduleFromBillingTransactionApi',
    'RevenueLifecycleManagementProductImportApi'
};

List<PermissionSetAssignment> toInsert = new List<PermissionSetAssignment>();
for (String psName : permSetNames) {
    List<PermissionSet> psList = [SELECT Id FROM PermissionSet WHERE Name = :psName LIMIT 1];
    if (!psList.isEmpty()) {
        PermissionSet ps = psList[0];
        if (!alreadyAssignedPS.contains(ps.Id)) {
            toInsert.add(new PermissionSetAssignment(
                AssigneeId = targetUser.Id,
                PermissionSetId = ps.Id
            ));
        } else {
            System.debug('Already assigned: ' + psName);
        }
    } else {
        System.debug('Not found: ' + psName);
    }
}

if (!toInsert.isEmpty()) {
    insert toInsert;
    System.debug('Assigned ' + toInsert.size() + ' new permission sets.');
} else {
    System.debug('No new permission sets to assign.');
}
