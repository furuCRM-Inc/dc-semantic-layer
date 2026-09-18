@IsTest
private class SemanticStewardControllerTest {

    @TestSetup
    static void makeData() {
        List<Semantic_Proposal__c> proposals = new List<Semantic_Proposal__c>{
            new Semantic_Proposal__c(
                DLO_Name__c          = 'OrderDLO__dlm',
                Suggested_DMO__c     = 'SalesOrder__dlm',
                Confidence_Score__c  = 0.92,
                Proposed_Mappings_JSON__c = '{"OrderId":"SalesOrderId__c"}',
                Status__c            = 'Draft'
            ),
            new Semantic_Proposal__c(
                DLO_Name__c          = 'ContactDLO__dlm',
                Suggested_DMO__c     = 'Individual__dlm',
                Confidence_Score__c  = 0.75,
                Proposed_Mappings_JSON__c = '{"Email":"Email__c"}',
                Status__c            = 'Draft'
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
    static void testApproveProposal_createsRegistry() {
        Semantic_Proposal__c proposal = [
            SELECT Id FROM Semantic_Proposal__c WHERE DLO_Name__c = 'OrderDLO__dlm' LIMIT 1
        ];

        Test.startTest();
        SemanticStewardController.approveProposal(
            proposal.Id,
            '{"OrderId":"VerifiedSalesOrderId__c"}'
        );
        Test.stopTest();

        Semantic_Proposal__c updated = [
            SELECT Status__c FROM Semantic_Proposal__c WHERE Id = :proposal.Id
        ];
        Assert.areEqual('Approved', updated.Status__c);

        List<Semantic_Registry__c> registry = [
            SELECT Entity_Name__c, Status__c, Verified_By__c
            FROM   Semantic_Registry__c
            WHERE  Entity_Name__c = 'OrderDLO__dlm'
        ];
        Assert.areEqual(1, registry.size());
        Assert.areEqual('Active', registry[0].Status__c);
        Assert.isNotNull(registry[0].Verified_By__c);
    }

    @IsTest
    static void testApproveProposal_usesProposesMappingWhenNoOverride() {
        Semantic_Proposal__c proposal = [
            SELECT Id FROM Semantic_Proposal__c WHERE DLO_Name__c = 'ContactDLO__dlm' LIMIT 1
        ];

        Test.startTest();
        SemanticStewardController.approveProposal(proposal.Id, null);
        Test.stopTest();

        Semantic_Registry__c reg = [
            SELECT Verified_Field_Mappings_JSON__c
            FROM   Semantic_Registry__c
            WHERE  Entity_Name__c = 'ContactDLO__dlm'
        ];
        Assert.areEqual('{"Email":"Email__c"}', reg.Verified_Field_Mappings_JSON__c);
    }

    @IsTest
    static void testRejectProposal_setsRejectedStatus() {
        Semantic_Proposal__c proposal = [
            SELECT Id FROM Semantic_Proposal__c WHERE DLO_Name__c = 'OrderDLO__dlm' LIMIT 1
        ];

        Test.startTest();
        SemanticStewardController.rejectProposal(proposal.Id, 'Incorrect DMO mapping');
        Test.stopTest();

        Semantic_Proposal__c updated = [
            SELECT Status__c FROM Semantic_Proposal__c WHERE Id = :proposal.Id
        ];
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
        Assert.areEqual('ContactDLO__dlm', results[0].DLO_Name__c);
    }
}
