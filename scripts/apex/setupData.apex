/*
This script automates the creation of all foundational data required for a
functional Revenue Cloud scratch org. [cite: 1]
It is designed to be idempotent, meaning
it can be run multiple times without creating duplicate records. [cite: 2]
Execution: sfdx force:apex:execute -f scripts/apex/setupData.apex [cite: 3]
*/
User adminUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = true LIMIT 1];
try { 
    // --- Part 1: Legal Entity & Billing Setup ---
    System.debug('Executing Part 1: Legal Entity & Billing Setup');
    LegalEntity le = createLegalEntity();
    BillingPolicy bp = createBillingPolicy();
    BillingTreatment bt = createBillingTreatment(bp.Id, le.Id);
    BillingTreatmentItem bti = createBillingTreatmentItem(bt.Id);
    activateBillingRecords(bp, bt, bti);
    // --- Part 2: Tax Setup --- [cite: 6]
    System.debug('Executing Part 2: Tax Setup');
    TaxPolicy taxPolicy = createTaxPolicy();
    TaxTreatment taxTreatment = createTaxTreatment(taxPolicy.Id, le.Id); 
    activateTaxPolicy(taxPolicy, taxTreatment.Id);

    // --- Part 3: Payment Terms Setup ---
    System.debug('Executing Part 3: Payment Terms Setup');
    createDefaultPaymentTerm(); 

    // --- Part 4: Product Catalog Setup ---
    System.debug('Executing Part 4: Product Catalog Setup');
    createProductCatalogAndModels();
} catch (Exception e) { 
    System.debug('ERROR during setup script execution: ' + e.getMessage());
    System.debug('Stack Trace: ' + e.getStackTraceString()); 
}


// =========================================================================
// --- Helper Methods for Data Creation ---
// =========================================================================

// --- Part 1: Legal Entity & Billing Setup Methods ---
private LegalEntity createLegalEntity() {
    List<LegalEntity> existing = [SELECT Id FROM LegalEntity WHERE Name = 'Dev Legal Entity' LIMIT 1];
    if (!existing.isEmpty()) { 
        System.debug('INFO: Legal Entity "Dev Legal Entity" already exists.');
        return existing[0];
    } 
    LegalEntity le = new LegalEntity(
        Name = 'Dev Legal Entity',
        CompanyName = 'Demo Company',
        Status = 'Active',
        LegalEntityStreet = '123 Demo St',
        LegalEntityCity = 'Demo City',
        LegalEntityState = 'CA',
        LegalEntityPostalCode = '90210',
        LegalEntityCountry = 'United States' 
    );
    insert le; 
    System.debug('SUCCESS: Created Legal Entity with ID: ' + le.Id);
    return le;
}

private BillingPolicy createBillingPolicy() {
    List<BillingPolicy> existing = [SELECT Id FROM BillingPolicy WHERE Name = 'Default Billing Policy' LIMIT 1];
    if (!existing.isEmpty()) { 
        System.debug('INFO: Billing Policy "Default Billing Policy" already exists.');
        return existing[0];
    } 
    BillingPolicy bp = new BillingPolicy(
        Name = 'Default Billing Policy',
        BillingTreatmentSelection = 'Default',
        Status = 'Draft'
    );
    insert bp; 
    System.debug('SUCCESS: Created Billing Policy with ID: ' + bp.Id);
    return bp;
}

private BillingTreatment createBillingTreatment(Id policyId, Id legalEntityId) {
    BillingTreatment bt = new BillingTreatment(
        Name = 'Default Billing Treatment',
        BillingPolicyId = policyId,
        LegalEntityId = legalEntityId,
        Status = 'Draft',
        ExcludeFromBilling = 'No'
    );
    insert bt; 
    System.debug('SUCCESS: Created Billing Treatment with ID: ' + bt.Id);
    return bt;
}

private BillingTreatmentItem createBillingTreatmentItem(Id treatmentId) {
    BillingTreatmentItem bti = new BillingTreatmentItem(
        Name = 'Default Billing Treatment Item',
        BillingTreatmentId = treatmentId,
        Status = 'Draft',
        Handling0Amount = 'CreateInvoice',
        ProcessingOrder = 1,
        Type = 'Remainder',
        BillingType = 'Advance',
        Sequencing = 'Manual',
        Controller = 'BillingScheduleGroup'
    );
    insert bti; 
    System.debug('SUCCESS: Created Billing Treatment Item with ID: ' + bti.Id);
    return bti;
}

private void activateBillingRecords(BillingPolicy bp, BillingTreatment bt, BillingTreatmentItem bti) {
    bti.Status = 'Active';
    update bti;
    System.debug('SUCCESS: Billing Treatment Item status set to Active.'); 

    bt.Status = 'Active';
    update bt;
    System.debug('SUCCESS: Billing Treatment status set to Active.');
    bp.DefaultBillingTreatmentId = bt.Id; 
    bp.Status = 'Active';
    update bp;
    System.debug('SUCCESS: Billing Policy updated and set to Active.');
}


// --- Part 2: Tax Setup Methods ---
private TaxPolicy createTaxPolicy() {
    List<TaxPolicy> existing = [SELECT Id FROM TaxPolicy WHERE Name = 'Default Tax Policy' LIMIT 1];
    if (!existing.isEmpty()) { 
        System.debug('INFO: Tax Policy "Default Tax Policy" already exists.');
        return existing[0];
    } 
    TaxPolicy tp = new TaxPolicy(
        Name = 'Default Tax Policy',
        Status = 'Draft',
        TreatmentSelection = 'Default'
    );
    insert tp; 
    System.debug('SUCCESS: Created Tax Policy with ID: ' + tp.Id);
    return tp;
}

private TaxTreatment createTaxTreatment(Id taxPolicyId, Id legalEntityId) {
    TaxTreatment tt = new TaxTreatment(
        Name = 'Default Tax Treatment',
        TaxPolicyId = taxPolicyId,
        LegalEntityId = legalEntityId,
        Status = 'Active'
    );
    insert tt; 
    System.debug('SUCCESS: Created Tax Treatment with ID: ' + tt.Id);
    return tt;
}

private void activateTaxPolicy(TaxPolicy tp, Id taxTreatmentId) {
    tp.DefaultTaxTreatmentId = taxTreatmentId;
    tp.Status = 'Active';
    update tp;
    System.debug('SUCCESS: Tax Policy updated and set to Active.'); 
}


// --- Part 3: Payment Terms Setup Method ---
private void createDefaultPaymentTerm() {
    List<PaymentTerm> existing = [SELECT Id FROM PaymentTerm WHERE Name = 'Default Payment Term' AND IsDefault = true LIMIT 1];
    if (!existing.isEmpty()) { 
        System.debug('INFO: Default Payment Term "Default Payment Term" already exists.');
        return;
    } 
    PaymentTerm pt = new PaymentTerm(
        Name = 'Default Payment Term',
        Status = 'Draft'        
    );
    insert pt; 

    PaymentTermItem pti = new PaymentTermItem(
        PaymentTermId = pt.Id,
        Type = 'Period-Based',
        PaymentTimeFrame = 'Standard',
        PeriodUnit = 'Days',
        Period = 30
    );
    insert pti; 
    System.debug('SUCCESS: Created default Payment Term "Default Payment Term".');

    // Activate Payment Term
    pt.Status = 'Active';
    pt.IsDefault = true; 
    update pt;
    System.debug('SUCCESS: Default Payment Term "Default Payment Term" set to Active.');
}


// --- Part 4: Product Catalog Setup Method ---
private void createProductCatalogAndModels() {
    System.debug('Starting Product Catalog creation...');
    // --- NEW CODE BLOCK START ---
    // Get Standard Pricebook and ensure it's active
    Pricebook2 standardPricebook = [SELECT Id, IsActive FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
    if (!standardPricebook.IsActive) {
        standardPricebook.IsActive = true;
        update standardPricebook;
        System.debug('SUCCESS: Standard Price Book has been activated.');
    } else {
        System.debug('INFO: Standard Price Book was already active.');
    }
    Id standardPricebookId = standardPricebook.Id;
    // --- NEW CODE BLOCK END ---

    // Create Catalog, Category, and Selling Models
    ProductCatalog catalog = getOrCreateCatalog('Demo Catalog', 'Sales', 'DEMO'); 
    ProductCategory category = getOrCreateCategory('Demo Products', catalog.Id); 
    
    Map<String, ProductSellingModel> sellingModels = new Map<String, ProductSellingModel>{
        'One Time' => getOrCreateSellingModel('One Time', 'OneTime', null, null),
        'Monthly' => getOrCreateSellingModel('Monthly', 'TermDefined', 1, 'Months'),
        'Yearly' => getOrCreateSellingModel('Yearly', 'TermDefined', 1, 'Annual')
    };
    // Define Products to Create [cite: 44]
    List<Map<String, Object>> productDefs = new List<Map<String, Object>>{
        new Map<String, Object>{'Name' => 'Down Payment', 'Code' => 'DEMO-001', 'Model' => 'One Time', 'Price' => 700.00},
        new Map<String, Object>{'Name' => 'Monthly Payment', 'Code' => 'DEMO-002', 'Model' => 'Monthly', 'Price' => 200.00},
        new Map<String, Object>{'Name' => 'Annual Payment', 'Code' => 'DEMO-003', 'Model' => 'Yearly', 'Price' => 1000.00}
    };
    // Check for existing products [cite: 45]
    List<String> productCodes = new List<String>();
    for(Map<String, Object> def : productDefs) { 
        productCodes.add((String)def.get('Code'));
    } 
    Set<String> existingProductCodes = new Set<String>();
    for(Product2 p : [SELECT ProductCode FROM Product2 WHERE ProductCode IN :productCodes]) {
        existingProductCodes.add(p.ProductCode);
    } 
    
    if(existingProductCodes.size() == productDefs.size()){
        System.debug('INFO: All demo products already exist. Skipping product creation.');
        return; 
    }

    // Create Products, Options, and Pricebook Entries
    for (Map<String, Object> def : productDefs) {
        if(existingProductCodes.contains((String)def.get('Code'))) continue;
        Product2 newProd = new Product2( 
            Name = (String)def.get('Name'),
            ProductCode = (String)def.get('Code'),
            IsActive = true
        );
        insert newProd;

        ProductSellingModelOption psmOption = new ProductSellingModelOption(
            ProductSellingModelId = sellingModels.get((String)def.get('Model')).Id,
            Product2Id = newProd.Id,
            IsDefault = true
        );
        insert psmOption; 

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = newProd.Id,
            ProductSellingModelId = sellingModels.get((String)def.get('Model')).Id,
            IsActive = true,
            UnitPrice = (Decimal)def.get('Price')
        );
        insert pbe; 
        
        System.debug('SUCCESS: Created Product: ' + newProd.Name);
    }
}

private ProductCatalog getOrCreateCatalog(String name, String type, String code) {
    List<ProductCatalog> existing = [SELECT Id FROM ProductCatalog WHERE Name = :name LIMIT 1];
    if (!existing.isEmpty()) { return existing[0]; } 
    ProductCatalog pc = new ProductCatalog(Name = name, CatalogType = type, Code = code);
    insert pc; 
    return pc;
}

private ProductCategory getOrCreateCategory(String name, Id catalogId) {
    List<ProductCategory> existing = [SELECT Id FROM ProductCategory WHERE Name = :name AND CatalogId = :catalogId LIMIT 1];
    if (!existing.isEmpty()) { return existing[0]; } 
    ProductCategory pcat = new ProductCategory(Name = name, CatalogId = catalogId, IsNavigational = true);
    insert pcat; 
    return pcat;
}

private ProductSellingModel getOrCreateSellingModel(String name, String type, Integer term, String termUnit) {
    List<ProductSellingModel> existing = [SELECT Id FROM ProductSellingModel WHERE Name = :name LIMIT 1];
    if (!existing.isEmpty()) { return existing[0]; } 
    ProductSellingModel psm = new ProductSellingModel(
        Name = name,
        SellingModelType = type,
        PricingTerm = term,
        PricingTermUnit = termUnit,
        Status = 'Active'
    );
    insert psm; 
    return psm;
}

// --- Part 5: Transactional Data Setup Methods ---
private void createTransactionalData() {
    System.debug('Starting Transactional Data creation...');
    Account acc = getOrCreateAccount('Chargent Dev');
    Contact con = getOrCreateContact('Chargent Dev', acc.Id);
    Opportunity opp = getOrCreateOpportunity('RCB Testing Opportunity', acc.Id);
    Quote quote = getOrCreateQuote('RCB Testing Quote', opp.Id);
    addProductsToQuote(quote.Id);
}

private Account getOrCreateAccount(String name) {
    List<Account> existing = [SELECT Id FROM Account WHERE Name = :name LIMIT 1];
    if (!existing.isEmpty()) {
        System.debug('INFO: Account "' + name + '" already exists.');
        return existing[0];
    }
    Account acc = new Account(
        Name = name,
        Phone = '415-275-1115',
        BillingStreet = '870 Market Street, Suite 809',
        BillingCity = 'San Francisco',
        BillingState = 'CA',
        BillingPostalCode = '94102',
        BillingCountry = 'United States of America',
        ShippingStreet = '870 Market Street, Suite 809',
        ShippingCity = 'San Francisco',
        ShippingState = 'CA',
        ShippingPostalCode = '94102',
        ShippingCountry = 'United States of America'
    );
    insert acc;
    System.debug('SUCCESS: Created Account "' + name + '" with ID: ' + acc.Id);
    return acc;
}

private Contact getOrCreateContact(String name, Id accountId) {
    List<Contact> existing = [SELECT Id FROM Contact WHERE LastName = :name AND AccountId = :accountId LIMIT 1];
    if (!existing.isEmpty()) {
        System.debug('INFO: Contact "' + name + '" already exists.');
        return existing[0];
    }
    Contact con = new Contact(
        AccountId = accountId,
        LastName = name,
        Phone = '415-275-1115',
        Email = 'test@test.com'
    );
    insert con;
    System.debug('SUCCESS: Created Contact "' + name + '" with ID: ' + con.Id);
    return con;
}

private Opportunity getOrCreateOpportunity(String name, Id accountId) {
    List<Opportunity> existing = [SELECT Id FROM Opportunity WHERE Name = :name AND AccountId = :accountId LIMIT 1];
    if (!existing.isEmpty()) {
        System.debug('INFO: Opportunity "' + name + '" already exists.');
        return existing[0];
    }
    Opportunity opp = new Opportunity(
        Name = name,
        AccountId = accountId,
        StageName = 'Prospecting',
        CloseDate = Date.today().addMonths(1)
    );
    insert opp;
    System.debug('SUCCESS: Created Opportunity "' + name + '" with ID: ' + opp.Id);
    return opp;
}

private Quote getOrCreateQuote(String name, Id opportunityId) {
    List<Quote> existing = [SELECT Id FROM Quote WHERE Name = :name AND OpportunityId = :opportunityId LIMIT 1];
    if (!existing.isEmpty()) {
        System.debug('INFO: Quote "' + name + '" already exists.');
        return existing[0];
    }
    
    Pricebook2 standardPricebook = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];

    Quote q = new Quote(
        Name = name,
        OpportunityId = opportunityId,
        Pricebook2Id = standardPricebook.Id
    );
    insert q;
    System.debug('SUCCESS: Created Quote "' + name + '" with ID: ' + q.Id);
    return q;
}

private void addProductsToQuote(Id quoteId) {
    List<QuoteLineItem> existingQLIs = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :quoteId];
    if (!existingQLIs.isEmpty()) {
        System.debug('INFO: Quote already has line items. Skipping product addition.');
        return;
    }
    
    Pricebook2 standardPricebook = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];

    // Get the products we created earlier
    Map<String, Product2> products = new Map<String, Product2>();
    for(Product2 p : [SELECT Id, ProductCode FROM Product2 WHERE ProductCode IN ('DEMO-001', 'DEMO-002', 'DEMO-003')]) {
        products.put(p.ProductCode, p);
    }
    
    // Get the corresponding Pricebook Entries
    Map<Id, PricebookEntry> pbes = new Map<Id, PricebookEntry>();
    for (PricebookEntry pbe : [SELECT Id, Product2Id, UnitPrice FROM PricebookEntry WHERE Pricebook2Id = :standardPricebook.Id AND Product2Id IN :products.values()]) {
        pbes.put(pbe.Product2Id, pbe);
    }
    
    // Create Quote Line Items
    List<QuoteLineItem> qlisToInsert = new List<QuoteLineItem>();
    if (products.get('DEMO-001') != null) {
        qlisToInsert.add(new QuoteLineItem(
            QuoteId = quoteId,
            Product2Id = products.get('DEMO-001').Id,
            PricebookEntryId = pbes.get(products.get('DEMO-001').Id).Id,
            Quantity = 1,
            UnitPrice = pbes.get(products.get('DEMO-001').Id).UnitPrice
        ));
    }
    if (products.get('DEMO-002') != null) {
        qlisToInsert.add(new QuoteLineItem(
            QuoteId = quoteId,
            Product2Id = products.get('DEMO-002').Id,
            PricebookEntryId = pbes.get(products.get('DEMO-002').Id).Id,
            Quantity = 1,
            UnitPrice = pbes.get(products.get('DEMO-002').Id).UnitPrice
        ));
    }
    if (products.get('DEMO-003') != null) {
        qlisToInsert.add(new QuoteLineItem(
            QuoteId = quoteId,
            Product2Id = products.get('DEMO-003').Id,
            PricebookEntryId = pbes.get(products.get('DEMO-003').Id).Id,
            Quantity = 1,
            UnitPrice = pbes.get(products.get('DEMO-003').Id).UnitPrice
        ));
    }

    if (!qlisToInsert.isEmpty()) {
        insert qlisToInsert;
        System.debug('SUCCESS: Added ' + qlisToInsert.size() + ' products to the Quote.');
    }
}