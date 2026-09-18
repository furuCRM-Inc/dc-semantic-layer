/**
 * @description Agentforce Action that resolves verified semantic mappings from
 * the Semantic Registry for a given entity name (DLO or DMO). Used by
 * Prompt Builder at inference time to inject approved field mappings and
 * natural-language business guardrails.
 *
 * Context-aware resolution: if contextTag is provided, a matching tagged entry
 * takes priority over an untagged (global) entry for the same entity name.
 * This enables Pain Point 3 — dynamic definition switching (e.g. Enterprise vs SMB).
 */
public with sharing class AgentforceSemanticResolver {

    public class ResolveRequest {
        @InvocableVariable(label='Entity Name (DLO or DMO API Name)' required=true)
        public String entityName;

        @InvocableVariable(label='Entity Type filter (DLO, DMO, or blank for any)')
        public String entityType;

        @InvocableVariable(label='Context Tag (e.g. Enterprise, SMB, JP — optional)')
        public String contextTag;
    }

    public class ResolveResult {
        @InvocableVariable(label='Field Mappings JSON')
        public String fieldMappingsJson;

        @InvocableVariable(label='Target DMO')
        public String targetDmo;

        @InvocableVariable(label='Entity Type')
        public String entityType;

        @InvocableVariable(label='Context Tag')
        public String contextTag;

        @InvocableVariable(label='Business Logic Rules')
        public String businessLogicRules;

        @InvocableVariable(label='Found')
        public Boolean found;
    }

    @InvocableMethod(
        label='Resolve Semantic Mapping'
        description='Returns verified field mappings and business guardrails for a Data Cloud DLO or DMO entity. Supports context-aware resolution (Enterprise, SMB, etc.)'
        category='Data Cloud'
    )
    public static List<ResolveResult> resolve(List<ResolveRequest> requests) {
        List<ResolveResult> results = new List<ResolveResult>();

        Set<String> entityNames = new Set<String>();
        for (ResolveRequest req : requests) {
            if (String.isNotBlank(req.entityName)) entityNames.add(req.entityName);
        }

        // Load all active entries for the requested entities (tagged + untagged)
        List<Semantic_Registry__c> rows = [
            SELECT Entity_Name__c, Entity_Type__c, Context_Tag__c,
                   Target_DMO__c, Verified_Field_Mappings_JSON__c, Business_Logic_Rules__c
            FROM   Semantic_Registry__c
            WHERE  Entity_Name__c IN :entityNames
            AND    Status__c = 'Active'
            WITH SYSTEM_MODE
        ];

        // Index: entityName → { contextTag (or '') → registry row }
        Map<String, Map<String, Semantic_Registry__c>> index = new Map<String, Map<String, Semantic_Registry__c>>();
        for (Semantic_Registry__c reg : rows) {
            String key = reg.Entity_Name__c;
            if (!index.containsKey(key)) index.put(key, new Map<String, Semantic_Registry__c>());
            String tag = String.isBlank(reg.Context_Tag__c) ? '' : reg.Context_Tag__c;
            index.get(key).put(tag, reg);
        }

        for (ResolveRequest req : requests) {
            ResolveResult res = new ResolveResult();
            Map<String, Semantic_Registry__c> byTag = index.get(req.entityName);

            Semantic_Registry__c reg = null;
            if (byTag != null) {
                // 1. Prefer exact context tag match
                if (String.isNotBlank(req.contextTag) && byTag.containsKey(req.contextTag)) {
                    reg = byTag.get(req.contextTag);
                }
                // 2. Fall back to global (untagged) entry
                if (reg == null && byTag.containsKey('')) {
                    reg = byTag.get('');
                }
            }

            if (reg != null && (String.isBlank(req.entityType) || reg.Entity_Type__c == req.entityType)) {
                res.found              = true;
                res.entityType         = reg.Entity_Type__c;
                res.contextTag         = reg.Context_Tag__c;
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
