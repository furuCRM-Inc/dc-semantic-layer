@IsTest
private class AgentforceSemanticResolverTest {

    @TestSetup
    static void makeData() {
        insert new List<Semantic_Registry__c>{
            // Pain Point 1: behavioral guardrail on a DMO churn profile
            new Semantic_Registry__c(
                Entity_Name__c                  = 'ChurnRiskProfile__dlm',
                Entity_Type__c                  = 'DMO',
                Target_DMO__c                   = 'Individual__dlm',
                Verified_Field_Mappings_JSON__c  = '{"ChurnScore__c":"churnRiskScore","CustomerId__c":"IndividualId"}',
                Business_Logic_Rules__c         =
                    'Churn risk score > 80% qualifies for re-engagement outreach. ' +
                    'EXCEPTION: if the customer has an open CRM case with Status = In Progress or Escalated, ' +
                    'do NOT send automated discount offers — route to human agent instead.',
                Status__c                       = 'Active'
            ),
            // Pain Point 2: write-back pre-execution guardrail on a DLO
            new Semantic_Registry__c(
                Entity_Name__c                  = 'OpportunitySignalDLO__dlm',
                Entity_Type__c                  = 'DLO',
                Target_DMO__c                   = 'SalesOrder__dlm',
                Verified_Field_Mappings_JSON__c  = '{"SignalId__c":"Id","PredictedStage__c":"StageName","SignalAmount__c":"Amount"}',
                Business_Logic_Rules__c         =
                    'Before updating Opportunity Stage to Closed-Won: ' +
                    '(1) Verify CloseDate__c is not null and is not in the future. ' +
                    '(2) Verify Amount__c > 0. ' +
                    '(3) Confirm running user has Edit permission on the Opportunity record. ' +
                    'If any check fails, surface a human approval task — do not retry automatically.',
                Status__c                       = 'Active'
            ),
            // Pain Point 3: Enterprise context definition
            new Semantic_Registry__c(
                Entity_Name__c                  = 'QualifiedLeadProfile__dlm',
                Entity_Type__c                  = 'DMO',
                Context_Tag__c                  = 'Enterprise',
                Target_DMO__c                   = 'Individual__dlm',
                Verified_Field_Mappings_JSON__c  = '{"LeadId__c":"IndividualId","AnnualRevenue__c":"ARR__c"}',
                Business_Logic_Rules__c         =
                    'Enterprise qualified lead: ARR >= 50,000,000 JPY AND employee count >= 500. ' +
                    'Assign to Enterprise AE. MEDDIC qualification required before Stage 2.',
                Status__c                       = 'Active'
            ),
            // Pain Point 3: SMB context definition (same entity, different context)
            new Semantic_Registry__c(
                Entity_Name__c                  = 'QualifiedLeadProfile__dlm',
                Entity_Type__c                  = 'DMO',
                Context_Tag__c                  = 'SMB',
                Target_DMO__c                   = 'Individual__dlm',
                Verified_Field_Mappings_JSON__c  = '{"LeadId__c":"IndividualId","AnnualRevenue__c":"ARR__c"}',
                Business_Logic_Rules__c         =
                    'SMB qualified lead: ARR < 10,000,000 JPY OR employee count < 100. ' +
                    'Assign to SMB pooled queue. Self-serve trial eligibility check first.',
                Status__c                       = 'Active'
            ),
            // Deprecated — must never be returned
            new Semantic_Registry__c(
                Entity_Name__c                  = 'OldDLO__dlm',
                Entity_Type__c                  = 'DLO',
                Target_DMO__c                   = 'LegacyDMO__dlm',
                Verified_Field_Mappings_JSON__c  = '{}',
                Status__c                       = 'Deprecated'
            )
        };
    }

    // --- Pain Point 1: behavioral guardrail ---

    @IsTest
    static void testPainPoint1_churnGuardrailReturned() {
        AgentforceSemanticResolver.ResolveRequest req = new AgentforceSemanticResolver.ResolveRequest();
        req.entityName = 'ChurnRiskProfile__dlm';

        Test.startTest();
        List<AgentforceSemanticResolver.ResolveResult> results =
            AgentforceSemanticResolver.resolve(new List<AgentforceSemanticResolver.ResolveRequest>{ req });
        Test.stopTest();

        Assert.isTrue(results[0].found);
        Assert.areEqual('DMO', results[0].entityType);
        Assert.isTrue(results[0].businessLogicRules.contains('EXCEPTION'));
        Assert.isTrue(results[0].businessLogicRules.contains('human agent'));
    }

    // --- Pain Point 2: write-back pre-execution check ---

    @IsTest
    static void testPainPoint2_writebackGuardrailReturned() {
        AgentforceSemanticResolver.ResolveRequest req = new AgentforceSemanticResolver.ResolveRequest();
        req.entityName = 'OpportunitySignalDLO__dlm';
        req.entityType = 'DLO';

        Test.startTest();
        List<AgentforceSemanticResolver.ResolveResult> results =
            AgentforceSemanticResolver.resolve(new List<AgentforceSemanticResolver.ResolveRequest>{ req });
        Test.stopTest();

        Assert.isTrue(results[0].found);
        Assert.isTrue(results[0].businessLogicRules.contains('Edit permission'));
        Assert.isTrue(results[0].businessLogicRules.contains('human approval task'));
    }

    // --- Pain Point 3: dynamic context switching ---

    @IsTest
    static void testPainPoint3_enterpriseContextReturnsEnterpriseRules() {
        AgentforceSemanticResolver.ResolveRequest req = new AgentforceSemanticResolver.ResolveRequest();
        req.entityName  = 'QualifiedLeadProfile__dlm';
        req.contextTag  = 'Enterprise';

        Test.startTest();
        List<AgentforceSemanticResolver.ResolveResult> results =
            AgentforceSemanticResolver.resolve(new List<AgentforceSemanticResolver.ResolveRequest>{ req });
        Test.stopTest();

        Assert.isTrue(results[0].found);
        Assert.areEqual('Enterprise', results[0].contextTag);
        Assert.isTrue(results[0].businessLogicRules.contains('50,000,000'));
        Assert.isTrue(results[0].businessLogicRules.contains('MEDDIC'));
    }

    @IsTest
    static void testPainPoint3_smbContextReturnsSmbRules() {
        AgentforceSemanticResolver.ResolveRequest req = new AgentforceSemanticResolver.ResolveRequest();
        req.entityName  = 'QualifiedLeadProfile__dlm';
        req.contextTag  = 'SMB';

        Test.startTest();
        List<AgentforceSemanticResolver.ResolveResult> results =
            AgentforceSemanticResolver.resolve(new List<AgentforceSemanticResolver.ResolveRequest>{ req });
        Test.stopTest();

        Assert.isTrue(results[0].found);
        Assert.areEqual('SMB', results[0].contextTag);
        Assert.isTrue(results[0].businessLogicRules.contains('10,000,000'));
        Assert.isTrue(results[0].businessLogicRules.contains('Self-serve'));
    }

    @IsTest
    static void testPainPoint3_unknownContextFallsBackToGlobal() {
        // If no global (untagged) entry exists, unknown context = not found
        AgentforceSemanticResolver.ResolveRequest req = new AgentforceSemanticResolver.ResolveRequest();
        req.entityName = 'QualifiedLeadProfile__dlm';
        req.contextTag = 'Unknown';

        Test.startTest();
        List<AgentforceSemanticResolver.ResolveResult> results =
            AgentforceSemanticResolver.resolve(new List<AgentforceSemanticResolver.ResolveRequest>{ req });
        Test.stopTest();

        // No untagged global fallback exists for this entity, so not found
        Assert.isFalse(results[0].found);
    }

    @IsTest
    static void testDeprecatedEntryNeverReturned() {
        AgentforceSemanticResolver.ResolveRequest req = new AgentforceSemanticResolver.ResolveRequest();
        req.entityName = 'OldDLO__dlm';

        Test.startTest();
        List<AgentforceSemanticResolver.ResolveResult> results =
            AgentforceSemanticResolver.resolve(new List<AgentforceSemanticResolver.ResolveRequest>{ req });
        Test.stopTest();

        Assert.isFalse(results[0].found);
    }

    @IsTest
    static void testBatchResolveMixedContexts() {
        List<AgentforceSemanticResolver.ResolveRequest> reqs = new List<AgentforceSemanticResolver.ResolveRequest>();

        AgentforceSemanticResolver.ResolveRequest r1 = new AgentforceSemanticResolver.ResolveRequest();
        r1.entityName = 'ChurnRiskProfile__dlm';
        reqs.add(r1);

        AgentforceSemanticResolver.ResolveRequest r2 = new AgentforceSemanticResolver.ResolveRequest();
        r2.entityName  = 'QualifiedLeadProfile__dlm';
        r2.contextTag  = 'Enterprise';
        reqs.add(r2);

        AgentforceSemanticResolver.ResolveRequest r3 = new AgentforceSemanticResolver.ResolveRequest();
        r3.entityName  = 'QualifiedLeadProfile__dlm';
        r3.contextTag  = 'SMB';
        reqs.add(r3);

        Test.startTest();
        List<AgentforceSemanticResolver.ResolveResult> results =
            AgentforceSemanticResolver.resolve(reqs);
        Test.stopTest();

        Assert.areEqual(3, results.size());
        Assert.isTrue(results[0].found);
        Assert.isTrue(results[1].businessLogicRules.contains('MEDDIC'));
        Assert.isTrue(results[2].businessLogicRules.contains('Self-serve'));
    }

    @IsTest
    static void testTypeFilterExcludesWrongType() {
        AgentforceSemanticResolver.ResolveRequest req = new AgentforceSemanticResolver.ResolveRequest();
        req.entityName = 'ChurnRiskProfile__dlm';
        req.entityType = 'DLO'; // actually DMO

        Test.startTest();
        List<AgentforceSemanticResolver.ResolveResult> results =
            AgentforceSemanticResolver.resolve(new List<AgentforceSemanticResolver.ResolveRequest>{ req });
        Test.stopTest();

        Assert.isFalse(results[0].found);
    }
}
