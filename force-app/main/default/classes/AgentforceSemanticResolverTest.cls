@IsTest
private class AgentforceSemanticResolverTest {

    @TestSetup
    static void makeData() {
        insert new List<Semantic_Registry__c>{
            new Semantic_Registry__c(
                Entity_Name__c                  = 'OrderDLO__dlm',
                Entity_Type__c                  = 'DLO',
                Target_DMO__c                   = 'SalesOrder__dlm',
                Verified_Field_Mappings_JSON__c  = '{"OrderId":"SalesOrderId__c","Amount":"TotalAmount__c"}',
                Business_Logic_Rules__c         = 'Amount must be > 0',
                Status__c                       = 'Active'
            ),
            new Semantic_Registry__c(
                Entity_Name__c                  = 'Individual__dlm',
                Entity_Type__c                  = 'DMO',
                Target_DMO__c                   = 'Individual__dlm',
                Verified_Field_Mappings_JSON__c  = '{"IndividualId":"Id"}',
                Business_Logic_Rules__c         = 'Primary key is IndividualId',
                Status__c                       = 'Active'
            ),
            new Semantic_Registry__c(
                Entity_Name__c                  = 'OldDLO__dlm',
                Entity_Type__c                  = 'DLO',
                Target_DMO__c                   = 'LegacyDMO__dlm',
                Verified_Field_Mappings_JSON__c  = '{}',
                Status__c                       = 'Deprecated'
            )
        };
    }

    @IsTest
    static void testResolve_dlo_found() {
        AgentforceSemanticResolver.ResolveRequest req = new AgentforceSemanticResolver.ResolveRequest();
        req.entityName = 'OrderDLO__dlm';

        Test.startTest();
        List<AgentforceSemanticResolver.ResolveResult> results =
            AgentforceSemanticResolver.resolve(new List<AgentforceSemanticResolver.ResolveRequest>{ req });
        Test.stopTest();

        Assert.isTrue(results[0].found);
        Assert.areEqual('DLO', results[0].entityType);
        Assert.areEqual('SalesOrder__dlm', results[0].targetDmo);
        Assert.isTrue(results[0].fieldMappingsJson.contains('SalesOrderId__c'));
        Assert.areEqual('Amount must be > 0', results[0].businessLogicRules);
    }

    @IsTest
    static void testResolve_dmo_found() {
        AgentforceSemanticResolver.ResolveRequest req = new AgentforceSemanticResolver.ResolveRequest();
        req.entityName = 'Individual__dlm';

        Test.startTest();
        List<AgentforceSemanticResolver.ResolveResult> results =
            AgentforceSemanticResolver.resolve(new List<AgentforceSemanticResolver.ResolveRequest>{ req });
        Test.stopTest();

        Assert.isTrue(results[0].found);
        Assert.areEqual('DMO', results[0].entityType);
    }

    @IsTest
    static void testResolve_typeFilterExcludes() {
        AgentforceSemanticResolver.ResolveRequest req = new AgentforceSemanticResolver.ResolveRequest();
        req.entityName = 'OrderDLO__dlm';
        req.entityType = 'DMO';

        Test.startTest();
        List<AgentforceSemanticResolver.ResolveResult> results =
            AgentforceSemanticResolver.resolve(new List<AgentforceSemanticResolver.ResolveRequest>{ req });
        Test.stopTest();

        Assert.isFalse(results[0].found);
    }

    @IsTest
    static void testResolve_deprecatedNotFound() {
        AgentforceSemanticResolver.ResolveRequest req = new AgentforceSemanticResolver.ResolveRequest();
        req.entityName = 'OldDLO__dlm';

        Test.startTest();
        List<AgentforceSemanticResolver.ResolveResult> results =
            AgentforceSemanticResolver.resolve(new List<AgentforceSemanticResolver.ResolveRequest>{ req });
        Test.stopTest();

        Assert.isFalse(results[0].found);
        Assert.areEqual('{}', results[0].fieldMappingsJson);
    }

    @IsTest
    static void testResolve_unknownNotFound() {
        AgentforceSemanticResolver.ResolveRequest req = new AgentforceSemanticResolver.ResolveRequest();
        req.entityName = 'DoesNotExist__dlm';

        Test.startTest();
        List<AgentforceSemanticResolver.ResolveResult> results =
            AgentforceSemanticResolver.resolve(new List<AgentforceSemanticResolver.ResolveRequest>{ req });
        Test.stopTest();

        Assert.isFalse(results[0].found);
    }

    @IsTest
    static void testResolve_batchMixed() {
        List<AgentforceSemanticResolver.ResolveRequest> reqs = new List<AgentforceSemanticResolver.ResolveRequest>();

        AgentforceSemanticResolver.ResolveRequest r1 = new AgentforceSemanticResolver.ResolveRequest();
        r1.entityName = 'OrderDLO__dlm';
        reqs.add(r1);

        AgentforceSemanticResolver.ResolveRequest r2 = new AgentforceSemanticResolver.ResolveRequest();
        r2.entityName = 'Individual__dlm';
        reqs.add(r2);

        AgentforceSemanticResolver.ResolveRequest r3 = new AgentforceSemanticResolver.ResolveRequest();
        r3.entityName = 'Missing__dlm';
        reqs.add(r3);

        Test.startTest();
        List<AgentforceSemanticResolver.ResolveResult> results =
            AgentforceSemanticResolver.resolve(reqs);
        Test.stopTest();

        Assert.areEqual(3, results.size());
        Assert.isTrue(results[0].found);
        Assert.isTrue(results[1].found);
        Assert.isFalse(results[2].found);
    }
}
