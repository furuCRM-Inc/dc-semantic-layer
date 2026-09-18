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
    static void testSampleObjectData_dlo_success() {
        String mockBody = '{"data":[{"id":"1"}]}';
        Test.setMock(HttpCalloutMock.class, new SuccessMock(200, mockBody));

        Test.startTest();
        String result = DataCloudDiscoveryService.sampleObjectData('OrderDLO__dlm', 3);
        Test.stopTest();

        Assert.areEqual(mockBody, result);
    }

    @IsTest
    static void testSampleObjectData_dmo_success() {
        String mockBody = '{"data":[{"IndividualId":"I-001"}]}';
        Test.setMock(HttpCalloutMock.class, new SuccessMock(200, mockBody));

        Test.startTest();
        String result = DataCloudDiscoveryService.sampleObjectData('Individual__dlm', 3);
        Test.stopTest();

        Assert.areEqual(mockBody, result);
    }

    @IsTest
    static void testSampleObjectData_201accepted() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock(201, '{"data":[]}'));

        Test.startTest();
        String result = DataCloudDiscoveryService.sampleObjectData('TestDLO__dlm', 1);
        Test.stopTest();

        Assert.areEqual('{"data":[]}', result);
    }

    @IsTest
    static void testSampleObjectData_errorThrows() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock(400, '{"error":"bad request"}'));

        Test.startTest();
        try {
            DataCloudDiscoveryService.sampleObjectData('BadDLO__dlm', 5);
            Assert.fail('Expected CalloutException');
        } catch (CalloutException ex) {
            Assert.isTrue(ex.getMessage().contains('Failed to sample'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetObjectMetadata_dlo_success() {
        String mockBody = '{"fields":[{"name":"Id","type":"string"}]}';
        Test.setMock(HttpCalloutMock.class, new SuccessMock(200, mockBody));

        Test.startTest();
        String result = DataCloudDiscoveryService.getObjectMetadata('OrderDLO__dlm', DataCloudDiscoveryService.TYPE_DLO);
        Test.stopTest();

        Assert.areEqual(mockBody, result);
    }

    @IsTest
    static void testGetObjectMetadata_dmo_success() {
        String mockBody = '{"fields":[{"name":"IndividualId","type":"string"}]}';
        Test.setMock(HttpCalloutMock.class, new SuccessMock(200, mockBody));

        Test.startTest();
        String result = DataCloudDiscoveryService.getObjectMetadata('Individual__dlm', DataCloudDiscoveryService.TYPE_DMO);
        Test.stopTest();

        Assert.areEqual(mockBody, result);
    }

    @IsTest
    static void testGetObjectMetadata_errorThrows() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock(404, '{"error":"not found"}'));

        Test.startTest();
        try {
            DataCloudDiscoveryService.getObjectMetadata('NonExistent__dlm', DataCloudDiscoveryService.TYPE_DLO);
            Assert.fail('Expected CalloutException');
        } catch (CalloutException ex) {
            Assert.isTrue(ex.getMessage().contains('Failed to retrieve metadata'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testBackwardsCompatibleAliases() {
        String mockBody = '{"data":[]}';
        Test.setMock(HttpCalloutMock.class, new SuccessMock(200, mockBody));

        Test.startTest();
        String r1 = DataCloudDiscoveryService.sampleDLOData('OrderDLO__dlm', 1);
        String r2 = DataCloudDiscoveryService.getDLOMetadata('OrderDLO__dlm');
        Test.stopTest();

        Assert.areEqual(mockBody, r1);
        Assert.areEqual(mockBody, r2);
    }
}
