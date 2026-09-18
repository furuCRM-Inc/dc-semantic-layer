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
    static void testInfer_success() {
        String sampleBody   = '{"data":[{"OrderId":"O-001"}]}';
        String metadataBody = '{"fields":[{"name":"OrderId","type":"string"}]}';
        Test.setMock(HttpCalloutMock.class, new MultiMock(
            new List<String>{ sampleBody, metadataBody }
        ));

        AgentforceSemanticInferenceAction.InferenceRequest req =
            new AgentforceSemanticInferenceAction.InferenceRequest();
        req.dloApiName  = 'OrderDLO__dlm';
        req.sampleSize  = 2;

        Test.startTest();
        List<AgentforceSemanticInferenceAction.InferenceResult> results =
            AgentforceSemanticInferenceAction.infer(
                new List<AgentforceSemanticInferenceAction.InferenceRequest>{ req }
            );
        Test.stopTest();

        Assert.areEqual(1, results.size());
        Assert.isTrue(results[0].success);
        Assert.isTrue(results[0].groundingJson.contains('dloApiName'));
    }

    @IsTest
    static void testInfer_defaultSampleSize() {
        String body = '{"data":[]}';
        Test.setMock(HttpCalloutMock.class, new MultiMock(new List<String>{ body, body }));

        AgentforceSemanticInferenceAction.InferenceRequest req =
            new AgentforceSemanticInferenceAction.InferenceRequest();
        req.dloApiName = 'ContactDLO__dlm';

        Test.startTest();
        List<AgentforceSemanticInferenceAction.InferenceResult> results =
            AgentforceSemanticInferenceAction.infer(
                new List<AgentforceSemanticInferenceAction.InferenceRequest>{ req }
            );
        Test.stopTest();

        Assert.isTrue(results[0].success);
    }

    @IsTest
    static void testInfer_capsSampleSizeAt5() {
        String body = '{"data":[]}';
        Test.setMock(HttpCalloutMock.class, new MultiMock(new List<String>{ body, body }));

        AgentforceSemanticInferenceAction.InferenceRequest req =
            new AgentforceSemanticInferenceAction.InferenceRequest();
        req.dloApiName = 'LargeDLO__dlm';
        req.sampleSize = 100;

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
        req.dloApiName = 'BrokenDLO__dlm';

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
