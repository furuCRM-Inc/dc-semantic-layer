/**
 * @description Agentforce Action that grounds Prompt Builder with Data Cloud
 * schema and sample data for a given DLO. Returns a compact JSON payload
 * combining field metadata and up to 5 sample rows.
 */
public with sharing class AgentforceSemanticInferenceAction {

    public class InferenceRequest {
        @InvocableVariable(label='DLO API Name' required=true)
        public String dloApiName;

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
        description='Samples a Data Cloud DLO and returns schema + data grounding JSON for Prompt Builder'
        category='Data Cloud'
    )
    public static List<InferenceResult> infer(List<InferenceRequest> requests) {
        List<InferenceResult> results = new List<InferenceResult>();

        for (InferenceRequest req : requests) {
            InferenceResult res = new InferenceResult();
            try {
                Integer size = (req.sampleSize != null && req.sampleSize > 0)
                    ? Math.min(req.sampleSize, 5)
                    : 3;

                String sampleJson   = DataCloudDiscoveryService.sampleDLOData(req.dloApiName, size);
                String metadataJson = DataCloudDiscoveryService.getDLOMetadata(req.dloApiName);

                Map<String, Object> grounding = new Map<String, Object>{
                    'dloApiName' => req.dloApiName,
                    'schema'     => JSON.deserializeUntyped(metadataJson),
                    'sample'     => JSON.deserializeUntyped(sampleJson)
                };

                res.groundingJson = JSON.serialize(grounding);
                res.success       = true;
            } catch (Exception ex) {
                res.success      = false;
                res.errorMessage = ex.getMessage();
                res.groundingJson = '{}';
            }
            results.add(res);
        }
        return results;
    }
}
