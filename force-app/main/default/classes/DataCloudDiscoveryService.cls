/**
 * @description Samples Data Cloud objects (DLO and DMO) and retrieves schema
 * metadata via the Data Cloud Query v2 and Metadata REST APIs.
 *
 * Named Credential setup (Setup > Named Credentials):
 *   Name     : DataCloud_Named_Credential
 *   Endpoint : https://<your-data-cloud-tenant>.salesforce.com
 *   Auth     : OAuth (Connected App with Data Cloud scope)
 */
public with sharing class DataCloudDiscoveryService {

    public static final String TYPE_DLO = 'DLO';
    public static final String TYPE_DMO = 'DMO';

    private static final String QUERY_ENDPOINT =
        'callout:DataCloud_Named_Credential/services/data/v66.0/ssot/queryv2';
    private static final String METADATA_DLO_BASE =
        'callout:DataCloud_Named_Credential/services/data/v66.0/ssot/metadata/';
    private static final String METADATA_DMO_BASE =
        'callout:DataCloud_Named_Credential/services/data/v66.0/ssot/datamodel/';

    /**
     * @description Executes a SQL SELECT against the Data Cloud Query API.
     * Works for both DLO and DMO API names — the query endpoint is unified.
     *
     * @param objectApiName  DLO or DMO API name (e.g. 'OrderDLO__dlm', 'SalesOrder__dlm').
     * @param sampleSize     Maximum rows to retrieve (1–200).
     * @return               Raw JSON response from Data Cloud.
     */
    public static String sampleObjectData(String objectApiName, Integer sampleSize) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(QUERY_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');

        Map<String, Object> body = new Map<String, Object>{
            'sql' => 'SELECT * FROM ' + String.escapeSingleQuotes(objectApiName)
                   + ' LIMIT ' + sampleSize
        };
        req.setBody(JSON.serialize(body));

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            return res.getBody();
        }
        throw new CalloutException('Failed to sample Data Cloud object: ' + res.getBody());
    }

    /**
     * @description Retrieves schema metadata for a DLO or DMO.
     * DLOs use the /ssot/metadata/ endpoint; DMOs use /ssot/datamodel/.
     *
     * @param objectApiName  DLO or DMO API name.
     * @param entityType     'DLO' or 'DMO' — use TYPE_DLO / TYPE_DMO constants.
     * @return               Raw JSON schema metadata.
     */
    public static String getObjectMetadata(String objectApiName, String entityType) {
        String base = (entityType == TYPE_DMO) ? METADATA_DMO_BASE : METADATA_DLO_BASE;

        HttpRequest req = new HttpRequest();
        req.setEndpoint(base + String.escapeSingleQuotes(objectApiName));
        req.setMethod('GET');

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() == 200) {
            return res.getBody();
        }
        throw new CalloutException('Failed to retrieve metadata: ' + res.getBody());
    }

    // --- backwards-compatible aliases ---

    public static String sampleDLOData(String dloApiName, Integer sampleSize) {
        return sampleObjectData(dloApiName, sampleSize);
    }

    public static String getDLOMetadata(String dloApiName) {
        return getObjectMetadata(dloApiName, TYPE_DLO);
    }
}
