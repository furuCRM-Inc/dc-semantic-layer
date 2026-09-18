@IsTest
private class DataCloudDiscoveryServiceTest {

    private class SuccessMock implements HttpCalloutMock {
        private Integer statusCode;
        private String  body;
        SuccessMock(Integer code, String body) {
            this.statusCode = code;
            this.body       = body;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }

    @IsTest
    static void testSampleDLOData_success() {
        String mockBody = '{"data":[{"id":"1"}]}';
        Test.setMock(HttpCalloutMock.class, new SuccessMock(200, mockBody));

        Test.startTest();
        String result = DataCloudDiscoveryService.sampleDLOData('OrderDLO__dlm', 3);
        Test.stopTest();

        Assert.areEqual(mockBody, result);
    }

    @IsTest
    static void testSampleDLOData_201accepted() {
        String mockBody = '{"data":[]}';
        Test.setMock(HttpCalloutMock.class, new SuccessMock(201, mockBody));

        Test.startTest();
        String result = DataCloudDiscoveryService.sampleDLOData('TestDLO__dlm', 1);
        Test.stopTest();

        Assert.areEqual(mockBody, result);
    }

    @IsTest
    static void testSampleDLOData_errorThrows() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock(400, '{"error":"bad request"}'));

        Test.startTest();
        try {
            DataCloudDiscoveryService.sampleDLOData('BadDLO__dlm', 5);
            Assert.fail('Expected CalloutException');
        } catch (CalloutException ex) {
            Assert.isTrue(ex.getMessage().contains('Failed to sample'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetDLOMetadata_success() {
        String mockBody = '{"fields":[{"name":"Id","type":"string"}]}';
        Test.setMock(HttpCalloutMock.class, new SuccessMock(200, mockBody));

        Test.startTest();
        String result = DataCloudDiscoveryService.getDLOMetadata('OrderDLO__dlm');
        Test.stopTest();

        Assert.areEqual(mockBody, result);
    }

    @IsTest
    static void testGetDLOMetadata_errorThrows() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock(404, '{"error":"not found"}'));

        Test.startTest();
        try {
            DataCloudDiscoveryService.getDLOMetadata('NonExistent__dlm');
            Assert.fail('Expected CalloutException');
        } catch (CalloutException ex) {
            Assert.isTrue(ex.getMessage().contains('Failed to retrieve DLO metadata'));
        }
        Test.stopTest();
    }
}
