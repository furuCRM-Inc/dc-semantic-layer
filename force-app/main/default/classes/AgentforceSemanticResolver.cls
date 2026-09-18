/**
 * @description Agentforce Action that resolves verified semantic mappings from
 * the Semantic Registry for a given entity name or DMO target. Used by
 * Prompt Builder at inference time to inject approved field mappings.
 */
public with sharing class AgentforceSemanticResolver {

    public class ResolveRequest {
        @InvocableVariable(label='Entity Name (DLO API Name)' required=true)
        public String entityName;
    }

    public class ResolveResult {
        @InvocableVariable(label='Field Mappings JSON')
        public String fieldMappingsJson;

        @InvocableVariable(label='Target DMO')
        public String targetDmo;

        @InvocableVariable(label='Business Logic Rules')
        public String businessLogicRules;

        @InvocableVariable(label='Found')
        public Boolean found;
    }

    @InvocableMethod(
        label='Resolve Semantic Mapping'
        description='Returns verified field mappings and business rules for a Data Cloud entity'
        category='Data Cloud'
    )
    public static List<ResolveResult> resolve(List<ResolveRequest> requests) {
        List<ResolveResult> results = new List<ResolveResult>();

        Set<String> entityNames = new Set<String>();
        for (ResolveRequest req : requests) {
            if (String.isNotBlank(req.entityName)) {
                entityNames.add(req.entityName);
            }
        }

        Map<String, Semantic_Registry__c> registryByEntity = new Map<String, Semantic_Registry__c>();
        for (Semantic_Registry__c reg : [
            SELECT Entity_Name__c, Target_DMO__c, Verified_Field_Mappings_JSON__c,
                   Business_Logic_Rules__c
            FROM   Semantic_Registry__c
            WHERE  Entity_Name__c IN :entityNames
            AND    Status__c = 'Active'
            WITH   SECURITY_ENFORCED
        ]) {
            registryByEntity.put(reg.Entity_Name__c, reg);
        }

        for (ResolveRequest req : requests) {
            ResolveResult res = new ResolveResult();
            Semantic_Registry__c reg = registryByEntity.get(req.entityName);
            if (reg != null) {
                res.found              = true;
                res.targetDmo          = reg.Target_DMO__c;
                res.fieldMappingsJson  = reg.Verified_Field_Mappings_JSON__c;
                res.businessLogicRules = reg.Business_Logic_Rules__c;
            } else {
                res.found             = false;
                res.fieldMappingsJson = '{}';
            }
            results.add(res);
        }
        return results;
    }
}
