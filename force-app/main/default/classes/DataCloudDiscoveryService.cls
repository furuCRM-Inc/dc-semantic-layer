/**
 * @description Samples Data Cloud DLO records and retrieves schema metadata
 * via the Data Cloud Query v2 REST API.
 *
 * Named Credential setup (Setup > Named Credentials):
 *   Name     : DataCloud_Named_Credential
 *   Endpoint : https://<your-data-cloud-tenant>.salesforce.com
 *   Auth     : OAuth (Connected App with Data Cloud scope)
 */
public with sharing class DataCloudDiscoveryService {

    private static final String QUERY_ENDPOINT =
        'callout:DataCloud_Named_Credential/services/data/v66.0/ssot/queryv2';
    private static final String METADATA_BASE =
        'callout:DataCloud_Named_Credential/services/data/v66.0/ssot/metadata/';

    /**
     * @description Executes a SQL SELECT against the Data Cloud Query API
     * and returns the raw JSON response body.
     *
     * @param dloApiName  DLO API name (e.g. 'OrderDLO__dlm').
     * @param sampleSize  Maximum rows to retrieve (1–200).
     * @return            Raw JSON response from Data Cloud.
     */
    public static String sampleDLOData(String dloApiName, Integer sampleSize) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(QUERY_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');

        Map<String, Object> body = new Map<String, Object>{
            'sql' => 'SELECT * FROM ' + String.escapeSingleQuotes(dloApiName)
                   + ' LIMIT ' + sampleSize
        };
        req.setBody(JSON.serialize(body));

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            return res.getBody();
        }
        throw new CalloutException(
            'Failed to sample Data Cloud object: ' + res.getBody());
    }

    /**
     * @description Retrieves DLO field schema metadata from the Data Cloud
     * Metadata API.
     *
     * @param dloApiName  DLO API name (e.g. 'OrderDLO__dlm').
     * @return            Raw JSON schema metadata.
     */
    public static String getDLOMetadata(String dloApiName) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(METADATA_BASE + String.escapeSingleQuotes(dloApiName));
        req.setMethod('GET');

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() == 200) {
            return res.getBody();
        }
        throw new CalloutException(
            'Failed to retrieve DLO metadata: ' + res.getBody());
    }
}
