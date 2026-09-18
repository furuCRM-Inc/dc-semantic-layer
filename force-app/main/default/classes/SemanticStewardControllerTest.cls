@IsTest
private class SemanticStewardControllerTest {

    @TestSetup
    static void makeData() {
        List<Semantic_Proposal__c> proposals = new List<Semantic_Proposal__c>{
            new Semantic_Proposal__c(
                DLO_Name__c               = 'OrderDLO__dlm',
                Entity_Type__c            = 'DLO',
                Suggested_DMO__c          = 'SalesOrder__dlm',
                Confidence_Score__c       = 0.92,
                Proposed_Mappings_JSON__c = '{"OrderId":"SalesOrderId__c"}',
                Status__c                 = 'Draft'
            ),
            new Semantic_Proposal__c(
                DLO_Name__c               = 'Individual__dlm',
                Entity_Type__c            = 'DMO',
                Suggested_DMO__c          = 'Individual__dlm',
                Confidence_Score__c       = 0.88,
                Proposed_Mappings_JSON__c = '{"Email":"Email__c"}',
                Status__c                 = 'Draft'
            )
        };
        insert proposals;
    }

    @IsTest
    static void testGetDraftProposals_returnsDrafts() {
        Test.startTest();
        List<Semantic_Proposal__c> results = SemanticStewardController.getDraftProposals();
        Test.stopTest();

        Assert.areEqual(2, results.size());
    }

    @IsTest
    static void testApproveProposal_dlo_createsRegistry() {
        Semantic_Proposal__c proposal = [
            SELECT Id FROM Semantic_Proposal__c WHERE DLO_Name__c = 'OrderDLO__dlm' LIMIT 1
        ];

        Test.startTest();
        SemanticStewardController.approveProposal(
            proposal.Id,
            '{"OrderId":"VerifiedSalesOrderId__c"}',
            'Exclude cancelled orders. Amount is in JPY.'
        );
        Test.stopTest();

        Semantic_Proposal__c updated = [SELECT Status__c FROM Semantic_Proposal__c WHERE Id = :proposal.Id];
        Assert.areEqual('Approved', updated.Status__c);

        Semantic_Registry__c reg = [
            SELECT Entity_Name__c, Entity_Type__c, Status__c, Verified_By__c, Business_Logic_Rules__c
            FROM   Semantic_Registry__c
            WHERE  Entity_Name__c = 'OrderDLO__dlm'
        ];
        Assert.areEqual('Active', reg.Status__c);
        Assert.areEqual('DLO', reg.Entity_Type__c);
        Assert.isNotNull(reg.Verified_By__c);
        Assert.areEqual('Exclude cancelled orders. Amount is in JPY.', reg.Business_Logic_Rules__c);
    }

    @IsTest
    static void testApproveProposal_dmo_createsRegistry() {
        Semantic_Proposal__c proposal = [
            SELECT Id FROM Semantic_Proposal__c WHERE DLO_Name__c = 'Individual__dlm' LIMIT 1
        ];

        Test.startTest();
        SemanticStewardController.approveProposal(proposal.Id, null, null);
        Test.stopTest();

        Semantic_Registry__c reg = [
            SELECT Entity_Type__c FROM Semantic_Registry__c WHERE Entity_Name__c = 'Individual__dlm'
        ];
        Assert.areEqual('DMO', reg.Entity_Type__c);
    }

    @IsTest
    static void testApproveProposal_usesProposesMappingWhenNoOverride() {
        Semantic_Proposal__c proposal = [
            SELECT Id FROM Semantic_Proposal__c WHERE DLO_Name__c = 'OrderDLO__dlm' LIMIT 1
        ];

        Test.startTest();
        SemanticStewardController.approveProposal(proposal.Id, null, null);
        Test.stopTest();

        Semantic_Registry__c reg = [
            SELECT Verified_Field_Mappings_JSON__c FROM Semantic_Registry__c WHERE Entity_Name__c = 'OrderDLO__dlm'
        ];
        Assert.areEqual('{"OrderId":"SalesOrderId__c"}', reg.Verified_Field_Mappings_JSON__c);
    }

    @IsTest
    static void testRejectProposal_setsRejectedStatus() {
        Semantic_Proposal__c proposal = [
            SELECT Id FROM Semantic_Proposal__c WHERE DLO_Name__c = 'OrderDLO__dlm' LIMIT 1
        ];

        Test.startTest();
        SemanticStewardController.rejectProposal(proposal.Id, 'Incorrect DMO mapping');
        Test.stopTest();

        Semantic_Proposal__c updated = [SELECT Status__c FROM Semantic_Proposal__c WHERE Id = :proposal.Id];
        Assert.areEqual('Rejected', updated.Status__c);
    }

    @IsTest
    static void testGetDraftProposals_excludesApproved() {
        Semantic_Proposal__c proposal = [
            SELECT Id FROM Semantic_Proposal__c WHERE DLO_Name__c = 'OrderDLO__dlm' LIMIT 1
        ];
        proposal.Status__c = 'Approved';
        update proposal;

        Test.startTest();
        List<Semantic_Proposal__c> results = SemanticStewardController.getDraftProposals();
        Test.stopTest();

        Assert.areEqual(1, results.size());
        Assert.areEqual('Individual__dlm', results[0].DLO_Name__c);
    }
}
