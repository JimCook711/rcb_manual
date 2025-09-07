/*
This script automates the creation of foundational data for a
functional Revenue Cloud scratch org.

NOTE: The automated cleanup and recreation of Pricing Procedures
has been removed. Please configure Context Definitions and
Pricing Procedures manually as per your setup guide.

Execution: sfdx force:apex:execute -f scripts/apex/setupData.apex
*/

try {
    // --- Part 1: Legal Entity & Billing Setup ---
    System.debug('Executing Part 1: Legal Entity & Billing Setup');
    LegalEntity le = createLegalEntity();
    BillingPolicy bp = createBillingPolicy();
    BillingTreatment bt = createBillingTreatment(bp.Id, le.Id);
    BillingTreatmentItem bti = createBillingTreatmentItem(bt.Id);
    activateBillingRecords(bp, bt, bti);

    // --- Part 2: Tax Setup ---
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

    // --- Part 5: Transactional Data Creation ---
    System.debug('Executing Part 5: Transactional Data Creation');
    createTransactionalData();

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
        Status = 'Active'
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
    Pricebook2 standardPricebook = [SELECT Id, IsActive FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
    if (!standardPricebook.IsActive) {
        standardPricebook.IsActive = true;
        update standardPricebook;
        System.debug('SUCCESS: Standard Price Book has been activated.');
    } else {
        System.debug('INFO: Standard Price Book was already active.');
    }
    Id standardPricebookId = standardPricebook.Id;

    ProductCatalog catalog = getOrCreateCatalog('Demo Catalog', 'Sales', 'DEMO');
    ProductCategory category = getOrCreateCategory('Demo Products', catalog.Id);

    Map<String, ProductSellingModel> sellingModels = new Map<String, ProductSellingModel>{
        'One Time' => getOrCreateSellingModel('One Time', 'OneTime', null, null),
        'Monthly' => getOrCreateSellingModel('Monthly', 'TermDefined', 1, 'Months'),
        'Yearly' => getOrCreateSellingModel('Yearly', 'TermDefined', 1, 'Annual')
    };

    List<Map<String, Object>> productDefs = new List<Map<String, Object>>{
        new Map<String, Object>{'Name' => 'Down Payment', 'Code' => 'DEMO-001', 'Model' => 'One Time', 'Price' => 700.00},
        new Map<String, Object>{'Name' => 'Monthly Payment', 'Code' => 'DEMO-002', 'Model' => 'Monthly', 'Price' => 200.00},
        new Map<String, Object>{'Name' => 'Annual Payment', 'Code' => 'DEMO-003', 'Model' => 'Yearly', 'Price' => 1000.00}
    };
    
    List<String> productCodes = new List<String>();
    for(Map<String, Object> def : productDefs) {
        productCodes.add((String)def.get('Code'));
    }
    
    List<PricebookEntry> existingPBEs = [SELECT Id FROM PricebookEntry WHERE Product2.ProductCode IN :productCodes AND Pricebook2Id = :standardPricebookId];
    if(!existingPBEs.isEmpty()){
        delete existingPBEs;
        System.debug('DELETED ' + existingPBEs.size() + ' existing pricebook entries for demo products.');
    }

    Set<String> existingProductCodes = new Set<String>();
    for(Product2 p : [SELECT ProductCode FROM Product2 WHERE ProductCode IN :productCodes]) {
        existingProductCodes.add(p.ProductCode);
    }

    if(existingProductCodes.size() == productDefs.size()){
        System.debug('INFO: All demo products already exist. Re-creating pricebook entries.');
    }

    for (Map<String, Object> def : productDefs) {
        Product2 prod;
        List<Product2> prods = [SELECT Id, Name, ProductCode FROM Product2 WHERE ProductCode = :(String)def.get('Code') LIMIT 1];
        if(prods.isEmpty()){
             prod = new Product2(
                Name = (String)def.get('Name'),
                ProductCode = (String)def.get('Code'),
                IsActive = true
            );
            insert prod;
             System.debug('SUCCESS: Created Product: ' + prod.Name);
        } else {
            prod = prods[0];
        }

        ProductSellingModelOption psmOption = new ProductSellingModelOption(
            ProductSellingModelId = sellingModels.get((String)def.get('Model')).Id,
            Product2Id = prod.Id,
            IsDefault = true
        );
        insert psmOption;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = prod.Id,
            ProductSellingModelId = sellingModels.get((String)def.get('Model')).Id,
            IsActive = true,
            UnitPrice = (Decimal)def.get('Price')
        );
        insert pbe;
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
    Opportunity opp = getOrCreateOpportunity('RCB Testing Opportunity', acc);
    Quote quote = getOrCreateQuote('RCB Testing Quote', opp, acc, con);
    addProductsToQuote(quote.Id);
}

private Account getOrCreateAccount(String name) {
    List<Account> existing = [
        SELECT Id, Name, Phone, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry
        FROM Account WHERE Name = :name LIMIT 1
    ];
    if (!existing.isEmpty()) {
        System.debug('INFO: Account "' + name + '" already exists.');
        return existing[0];
    }
    Account acc = new Account(
        Name = name,
        Phone = '415-275-1115',
        BillingStreet = '870 Market Street',
        BillingCity = 'San Francisco',
        BillingState = 'CA',
        BillingPostalCode = '94102',
        BillingCountry = 'USA',
        ShippingStreet = '870 Market Street',
        ShippingCity = 'San Francisco',
        ShippingState = 'CA',
        ShippingPostalCode = '94102',
        ShippingCountry = 'USA'
    );
    insert acc;
    System.debug('SUCCESS: Created Account "' + name + '" with ID: ' + acc.Id);
    return acc;
}

private Contact getOrCreateContact(String name, Id accountId) {
    List<Contact> existing = [
        SELECT Id, LastName, Phone, Email
        FROM Contact WHERE LastName = :name AND AccountId = :accountId LIMIT 1
    ];
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

private Opportunity getOrCreateOpportunity(String name, Account acc) {
    List<Opportunity> existing = [SELECT Id FROM Opportunity WHERE Name = :name AND AccountId = :acc.Id LIMIT 1];
    if (!existing.isEmpty()) {
        System.debug('INFO: Opportunity "' + name + '" already exists.');
        return existing[0];
    }
    Opportunity opp = new Opportunity(
        Name = name,
        AccountId = acc.Id,
        StageName = 'Prospecting',
        CloseDate = Date.today().addMonths(1)
    );
    insert opp;
    System.debug('SUCCESS: Created Opportunity "' + name + '" with ID: ' + opp.Id);
    return opp;
}

private Quote getOrCreateQuote(String name, Opportunity opp, Account acc, Contact con) {
    List<Quote> existing = [SELECT Id FROM Quote WHERE Name = :name AND OpportunityId = :opp.Id LIMIT 1];
    if (!existing.isEmpty()) {
        System.debug('INFO: Quote "' + name + '" already exists.');
        return existing[0];
    }

    Pricebook2 standardPricebook = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];

    Quote q = new Quote(
        Name = name,
        OpportunityId = opp.Id,
        Pricebook2Id = standardPricebook.Id,
        ExpirationDate = Date.today().addDays(30),
        Description = 'Quote created for ' + acc.Name + ' via automated script.',
        ContactId = con.Id,
        Phone = con.Phone,
        Email = con.Email,
        BillingName = acc.Name,
        BillingStreet = acc.BillingStreet,
        BillingCity = acc.BillingCity,
        BillingState = acc.BillingState,
        BillingPostalCode = acc.BillingPostalCode,
        BillingCountry = acc.BillingCountry,
        ShippingName = acc.Name,
        ShippingStreet = acc.ShippingStreet,
        ShippingCity = acc.ShippingCity,
        ShippingState = acc.ShippingState,
        ShippingPostalCode = acc.ShippingPostalCode,
        ShippingCountry = acc.ShippingCountry
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

    Map<String, Product2> products = new Map<String, Product2>();
    for(Product2 p : [SELECT Id, ProductCode FROM Product2 WHERE ProductCode IN ('DEMO-001', 'DEMO-002', 'DEMO-003')]) {
        products.put(p.ProductCode, p);
    }

    Map<Id, PricebookEntry> pbes = new Map<Id, PricebookEntry>();
    for (PricebookEntry pbe : [SELECT Id, Product2Id, UnitPrice FROM PricebookEntry WHERE Pricebook2Id = :standardPricebook.Id AND Product2Id IN :products.values()]) {
        pbes.put(pbe.Product2Id, pbe);
    }

    List<QuoteLineItem> qlisToInsert = new List<QuoteLineItem>();
    if (products.get('DEMO-001') != null && pbes.get(products.get('DEMO-001').Id) != null) {
        qlisToInsert.add(new QuoteLineItem(
            QuoteId = quoteId,
            Product2Id = products.get('DEMO-001').Id,
            PricebookEntryId = pbes.get(products.get('DEMO-001').Id).Id,
            Quantity = 1,
            UnitPrice = pbes.get(products.get('DEMO-001').Id).UnitPrice
        ));
    }
    if (products.get('DEMO-002') != null && pbes.get(products.get('DEMO-002').Id) != null) {
        qlisToInsert.add(new QuoteLineItem(
            QuoteId = quoteId,
            Product2Id = products.get('DEMO-002').Id,
            PricebookEntryId = pbes.get(products.get('DEMO-002').Id).Id,
            Quantity = 1,
            UnitPrice = pbes.get(products.get('DEMO-002').Id).UnitPrice
        ));
    }
    if (products.get('DEMO-003') != null && pbes.get(products.get('DEMO-003').Id) != null) {
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