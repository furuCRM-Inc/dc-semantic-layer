/**
 * @description Agentforce Action that grounds Prompt Builder with Data Cloud
 * schema and sample data for a given DLO or DMO. Returns a compact JSON
 * payload combining field metadata and up to 5 sample rows.
 */
public with sharing class AgentforceSemanticInferenceAction {

    public class InferenceRequest {
        @InvocableVariable(label='Object API Name' required=true)
        public String objectApiName;

        @InvocableVariable(label='Entity Type (DLO or DMO)' required=true)
        public String entityType;

        @InvocableVariable(label='Sample Size (1-5)')
        public Integer sampleSize;
    }

    public class InferenceResult {
        @InvocableVariable(label='Grounding JSON')
        public String groundingJson;

        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Infer Semantic Mapping'
        description='Samples a Data Cloud DLO or DMO and returns schema + data grounding JSON for Prompt Builder'
        category='Data Cloud'
    )
    public static List<InferenceResult> infer(List<InferenceRequest> requests) {
        List<InferenceResult> results = new List<InferenceResult>();

        for (InferenceRequest req : requests) {
            InferenceResult res = new InferenceResult();
            try {
                String type = String.isBlank(req.entityType) ? DataCloudDiscoveryService.TYPE_DLO : req.entityType;
                Integer size = (req.sampleSize != null && req.sampleSize > 0)
                    ? Math.min(req.sampleSize, 5)
                    : 3;

                String sampleJson   = DataCloudDiscoveryService.sampleObjectData(req.objectApiName, size);
                String metadataJson = DataCloudDiscoveryService.getObjectMetadata(req.objectApiName, type);

                Map<String, Object> grounding = new Map<String, Object>{
                    'objectApiName' => req.objectApiName,
                    'entityType'    => type,
                    'schema'        => JSON.deserializeUntyped(metadataJson),
                    'sample'        => JSON.deserializeUntyped(sampleJson)
                };

                res.groundingJson = JSON.serialize(grounding);
                res.success       = true;
            } catch (Exception ex) {
                res.success       = false;
                res.errorMessage  = ex.getMessage();
                res.groundingJson = '{}';
            }
            results.add(res);
        }
        return results;
    }
}
