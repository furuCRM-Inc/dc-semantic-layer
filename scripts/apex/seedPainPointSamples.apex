/**
 * Anonymous Apex — seed Semantic Registry with 3 pain point samples.
 * Run: sf apex run --file scripts/apex/seedPainPointSamples.apex --target-org <alias>
 *
 * Pain Point 1 — Static read-only definition lacks action guardrails
 * Pain Point 2 — No write-back pre-execution constraints
 * Pain Point 3 — Static definitions can't switch context (Enterprise vs SMB)
 */

List<Semantic_Registry__c> entries = new List<Semantic_Registry__c>();

// ──────────────────────────────────────────────────────────────────────────────
// PAIN POINT 1
// Data Cloud knows "churn score > 80%" but cannot express the action exception:
// "Do not send auto-discount to customers with an active CRM claim"
// ──────────────────────────────────────────────────────────────────────────────
entries.add(new Semantic_Registry__c(
    Entity_Name__c                  = 'ChurnRiskProfile__dlm',
    Entity_Type__c                  = 'DMO',
    Target_DMO__c                   = 'Individual__dlm',
    Verified_Field_Mappings_JSON__c = JSON.serialize(new Map<String, Object>{
        'ChurnScore__c'  => 'churnRiskScore',
        'CustomerId__c'  => 'IndividualId',
        'TenureMonths__c'=> 'customerTenureMonths'
    }),
    Business_Logic_Rules__c         =
        'Churn risk score > 80% qualifies for re-engagement outreach.\n' +
        'EXCEPTION: If the customer has an open CRM Case with Status = "In Progress" or "Escalated", ' +
        'do NOT send automated discount offers — route to a human support agent instead.\n' +
        'Recalculation lag: churn score is refreshed every 24 h; check timestamp before acting.',
    Status__c                       = 'Active',
    Verified_By__c                  = UserInfo.getUserId()
));

// ──────────────────────────────────────────────────────────────────────────────
// PAIN POINT 2
// Data Cloud can predict "Opportunity should be Closed-Won" but has no awareness
// of CRM validation rules or permission checks required before the write-back
// ──────────────────────────────────────────────────────────────────────────────
entries.add(new Semantic_Registry__c(
    Entity_Name__c                  = 'OpportunitySignalDLO__dlm',
    Entity_Type__c                  = 'DLO',
    Target_DMO__c                   = 'SalesOrder__dlm',
    Verified_Field_Mappings_JSON__c = JSON.serialize(new Map<String, Object>{
        'SignalId__c'       => 'Id',
        'PredictedStage__c' => 'StageName',
        'SignalAmount__c'   => 'Amount',
        'PredictedClose__c' => 'CloseDate'
    }),
    Business_Logic_Rules__c         =
        'Pre-execution checklist before updating Opportunity Stage to Closed-Won:\n' +
        '(1) CloseDate must be set and must not be in the future.\n' +
        '(2) Amount must be greater than 0.\n' +
        '(3) Confirm the running user has Edit permission on the Opportunity record.\n' +
        '(4) Verify no open blocking approval process exists on the record.\n' +
        'If any check fails: create a human approval Task, set owner to Opportunity owner, ' +
        'do NOT retry automatically — log the failure reason in the Task description.',
    Status__c                       = 'Active',
    Verified_By__c                  = UserInfo.getUserId()
));

// ──────────────────────────────────────────────────────────────────────────────
// PAIN POINT 3a — Enterprise agent context
// "Qualified Lead" means ARR >= 50M JPY, MEDDIC required
// ──────────────────────────────────────────────────────────────────────────────
entries.add(new Semantic_Registry__c(
    Entity_Name__c                  = 'QualifiedLeadProfile__dlm',
    Entity_Type__c                  = 'DMO',
    Context_Tag__c                  = 'Enterprise',
    Target_DMO__c                   = 'Individual__dlm',
    Verified_Field_Mappings_JSON__c = JSON.serialize(new Map<String, Object>{
        'LeadId__c'         => 'IndividualId',
        'AnnualRevenue__c'  => 'ARR__c',
        'EmployeeCount__c'  => 'NumberOfEmployees__c',
        'QualScore__c'      => 'MEDDICScore__c'
    }),
    Business_Logic_Rules__c         =
        'Enterprise qualified lead definition (context: Enterprise AE agent):\n' +
        '- Annual Revenue >= 50,000,000 JPY AND Employee Count >= 500\n' +
        '- Assign to Enterprise Account Executive queue\n' +
        '- MEDDIC qualification (Metrics/Economic Buyer/Decision Criteria/Decision Process/' +
        'Identify Pain/Champion) required before progressing to Stage 2\n' +
        '- Do not auto-send pricing — route to AE for personalised proposal',
    Status__c                       = 'Active',
    Verified_By__c                  = UserInfo.getUserId()
));

// ──────────────────────────────────────────────────────────────────────────────
// PAIN POINT 3b — SMB agent context
// Same entity, completely different qualifying logic and routing
// ──────────────────────────────────────────────────────────────────────────────
entries.add(new Semantic_Registry__c(
    Entity_Name__c                  = 'QualifiedLeadProfile__dlm',
    Entity_Type__c                  = 'DMO',
    Context_Tag__c                  = 'SMB',
    Target_DMO__c                   = 'Individual__dlm',
    Verified_Field_Mappings_JSON__c = JSON.serialize(new Map<String, Object>{
        'LeadId__c'         => 'IndividualId',
        'AnnualRevenue__c'  => 'ARR__c',
        'EmployeeCount__c'  => 'NumberOfEmployees__c'
    }),
    Business_Logic_Rules__c         =
        'SMB qualified lead definition (context: SMB pooled agent):\n' +
        '- Annual Revenue < 10,000,000 JPY OR Employee Count < 100\n' +
        '- Assign to SMB round-robin pooled queue\n' +
        '- Check self-serve trial eligibility first; offer 14-day free trial if eligible\n' +
        '- Simplified BANT (Budget/Authority/Need/Timeline) only\n' +
        '- Auto-send pricing PDF if trial declined',
    Status__c                       = 'Active',
    Verified_By__c                  = UserInfo.getUserId()
));

insert entries;
System.debug('Inserted ' + entries.size() + ' Semantic_Registry__c entries for pain point samples.');
for (Semantic_Registry__c e : entries) {
    System.debug('  → ' + e.Entity_Name__c + ' [' + e.Entity_Type__c + ']' +
        (String.isNotBlank(e.Context_Tag__c) ? ' context=' + e.Context_Tag__c : ''));
}
