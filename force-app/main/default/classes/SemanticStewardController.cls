/**
 * @description LWC controller for the Semantic Steward Workspace.
 * Provides Human-in-the-Loop review of AI-generated semantic proposals
 * for both DLO and DMO entities.
 */
public with sharing class SemanticStewardController {

    @AuraEnabled(cacheable=true)
    public static List<Semantic_Proposal__c> getDraftProposals() {
        return [
            SELECT Id, Name, DLO_Name__c, Entity_Type__c, Suggested_DMO__c,
                   Confidence_Score__c, Proposed_Mappings_JSON__c,
                   Sample_Data_Payload__c, Status__c, CreatedDate
            FROM   Semantic_Proposal__c
            WHERE  Status__c = 'Draft'
            ORDER BY CreatedDate DESC
            LIMIT  200
        ];
    }

    /**
     * @description Approves a proposal and writes it to the Semantic Registry.
     *
     * @param proposalId          Proposal to approve.
     * @param verifiedMappingsJson  Optional JSON override for field mappings.
     * @param naturalLanguageNotes  Optional free-text notes from the steward
     *                              (e.g. "exclude cancelled orders, map OrderId
     *                              to customer order number"). Stored as
     *                              Business_Logic_Rules__c and surfaced to
     *                              Agentforce at resolve time.
     */
    @AuraEnabled
    public static void approveProposal(Id proposalId, String verifiedMappingsJson, String naturalLanguageNotes) {
        Semantic_Proposal__c proposal = [
            SELECT Id, DLO_Name__c, Entity_Type__c, Suggested_DMO__c, Proposed_Mappings_JSON__c
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
            Entity_Name__c                  = proposal.DLO_Name__c,
            Entity_Type__c                  = proposal.Entity_Type__c,
            Target_DMO__c                   = proposal.Suggested_DMO__c,
            Verified_Field_Mappings_JSON__c  = finalMappings,
            Business_Logic_Rules__c         = naturalLanguageNotes,
            Status__c                       = 'Active',
            Verified_By__c                  = UserInfo.getUserId()
        );
        insert entry;
    }

    @AuraEnabled
    public static void rejectProposal(Id proposalId, String rejectionReason) {
        update new Semantic_Proposal__c(
            Id        = proposalId,
            Status__c = 'Rejected'
        );
    }
}
