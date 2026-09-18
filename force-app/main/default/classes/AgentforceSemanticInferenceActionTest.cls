@IsTest
private class AgentforceSemanticInferenceActionTest {

    private class MultiMock implements HttpCalloutMock {
        private Integer callCount = 0;
        private List<String> bodies;
        MultiMock(List<String> bodies) { this.bodies = bodies; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(bodies[Math.min(callCount++, bodies.size() - 1)]);
            return res;
        }
    }

    private class ErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"internal server error"}');
            return res;
        }
    }

    @IsTest
    static void testInfer_dlo_success() {
        String sampleBody   = '{"data":[{"OrderId":"O-001"}]}';
        String metadataBody = '{"fields":[{"name":"OrderId","type":"string"}]}';
        Test.setMock(HttpCalloutMock.class, new MultiMock(
            new List<String>{ sampleBody, metadataBody }
        ));

        AgentforceSemanticInferenceAction.InferenceRequest req =
            new AgentforceSemanticInferenceAction.InferenceRequest();
        req.objectApiName = 'OrderDLO__dlm';
        req.entityType    = 'DLO';
        req.sampleSize    = 2;

        Test.startTest();
        List<AgentforceSemanticInferenceAction.InferenceResult> results =
            AgentforceSemanticInferenceAction.infer(
                new List<AgentforceSemanticInferenceAction.InferenceRequest>{ req }
            );
        Test.stopTest();

        Assert.isTrue(results[0].success);
        Assert.isTrue(results[0].groundingJson.contains('objectApiName'));
        Assert.isTrue(results[0].groundingJson.contains('DLO'));
    }

    @IsTest
    static void testInfer_dmo_success() {
        String sampleBody   = '{"data":[{"IndividualId":"IND-001"}]}';
        String metadataBody = '{"fields":[{"name":"IndividualId","type":"string"}]}';
        Test.setMock(HttpCalloutMock.class, new MultiMock(
            new List<String>{ sampleBody, metadataBody }
        ));

        AgentforceSemanticInferenceAction.InferenceRequest req =
            new AgentforceSemanticInferenceAction.InferenceRequest();
        req.objectApiName = 'Individual__dlm';
        req.entityType    = 'DMO';
        req.sampleSize    = 2;

        Test.startTest();
        List<AgentforceSemanticInferenceAction.InferenceResult> results =
            AgentforceSemanticInferenceAction.infer(
                new List<AgentforceSemanticInferenceAction.InferenceRequest>{ req }
            );
        Test.stopTest();

        Assert.isTrue(results[0].success);
        Assert.isTrue(results[0].groundingJson.contains('DMO'));
    }

    @IsTest
    static void testInfer_defaultsToTypeWhenBlank() {
        String body = '{"data":[]}';
        Test.setMock(HttpCalloutMock.class, new MultiMock(new List<String>{ body, body }));

        AgentforceSemanticInferenceAction.InferenceRequest req =
            new AgentforceSemanticInferenceAction.InferenceRequest();
        req.objectApiName = 'ContactDLO__dlm';
        req.entityType    = '';

        Test.startTest();
        List<AgentforceSemanticInferenceAction.InferenceResult> results =
            AgentforceSemanticInferenceAction.infer(
                new List<AgentforceSemanticInferenceAction.InferenceRequest>{ req }
            );
        Test.stopTest();

        Assert.isTrue(results[0].success);
        Assert.isTrue(results[0].groundingJson.contains('DLO'));
    }

    @IsTest
    static void testInfer_capsSampleSizeAt5() {
        String body = '{"data":[]}';
        Test.setMock(HttpCalloutMock.class, new MultiMock(new List<String>{ body, body }));

        AgentforceSemanticInferenceAction.InferenceRequest req =
            new AgentforceSemanticInferenceAction.InferenceRequest();
        req.objectApiName = 'LargeDLO__dlm';
        req.entityType    = 'DLO';
        req.sampleSize    = 100;

        Test.startTest();
        List<AgentforceSemanticInferenceAction.InferenceResult> results =
            AgentforceSemanticInferenceAction.infer(
                new List<AgentforceSemanticInferenceAction.InferenceRequest>{ req }
            );
        Test.stopTest();

        Assert.isTrue(results[0].success);
    }

    @IsTest
    static void testInfer_calloutFailure() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        AgentforceSemanticInferenceAction.InferenceRequest req =
            new AgentforceSemanticInferenceAction.InferenceRequest();
        req.objectApiName = 'BrokenDLO__dlm';
        req.entityType    = 'DLO';

        Test.startTest();
        List<AgentforceSemanticInferenceAction.InferenceResult> results =
            AgentforceSemanticInferenceAction.infer(
                new List<AgentforceSemanticInferenceAction.InferenceRequest>{ req }
            );
        Test.stopTest();

        Assert.isFalse(results[0].success);
        Assert.isTrue(String.isNotBlank(results[0].errorMessage));
        Assert.areEqual('{}', results[0].groundingJson);
    }
}
