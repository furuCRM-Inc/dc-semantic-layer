/**
 * @description LWC controller for the Semantic Steward Workspace.
 * Provides Human-in-the-Loop review of AI-generated semantic proposals.
 */
public with sharing class SemanticStewardController {

    @AuraEnabled(cacheable=true)
    public static List<Semantic_Proposal__c> getDraftProposals() {
        return [
            SELECT Id, Name, DLO_Name__c, Suggested_DMO__c, Confidence_Score__c,
                   Proposed_Mappings_JSON__c, Sample_Data_Payload__c, Status__c,
                   CreatedDate
            FROM   Semantic_Proposal__c
            WHERE  Status__c = 'Draft'
            ORDER BY CreatedDate DESC
            LIMIT  200
        ];
    }

    @AuraEnabled
    public static void approveProposal(Id proposalId, String verifiedMappingsJson) {
        Semantic_Proposal__c proposal = [
            SELECT Id, DLO_Name__c, Suggested_DMO__c, Proposed_Mappings_JSON__c,
                   Confidence_Score__c
            FROM   Semantic_Proposal__c
            WHERE  Id = :proposalId
            WITH   SECURITY_ENFORCED
        ];

        proposal.Status__c = 'Approved';
        update proposal;

        String finalMappings = String.isNotBlank(verifiedMappingsJson)
            ? verifiedMappingsJson
            : proposal.Proposed_Mappings_JSON__c;

        Semantic_Registry__c entry = new Semantic_Registry__c(
            Entity_Name__c               = proposal.DLO_Name__c,
            Target_DMO__c                = proposal.Suggested_DMO__c,
            Verified_Field_Mappings_JSON__c = finalMappings,
            Status__c                    = 'Active',
            Verified_By__c               = UserInfo.getUserId()
        );
        insert entry;
    }

    @AuraEnabled
    public static void rejectProposal(Id proposalId, String rejectionReason) {
        Semantic_Proposal__c proposal = new Semantic_Proposal__c(
            Id        = proposalId,
            Status__c = 'Rejected'
        );
        update proposal;
    }
}
