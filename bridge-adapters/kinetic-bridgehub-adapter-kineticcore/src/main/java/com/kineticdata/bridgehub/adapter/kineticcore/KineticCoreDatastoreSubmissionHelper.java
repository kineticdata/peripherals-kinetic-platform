package com.kineticdata.bridgehub.adapter.kineticcore;

import com.kineticdata.bridgehub.adapter.BridgeError;
import com.kineticdata.bridgehub.adapter.BridgeRequest;
import com.kineticdata.bridgehub.adapter.BridgeUtils;
import com.kineticdata.bridgehub.adapter.Count;
import com.kineticdata.bridgehub.adapter.Record;
import com.kineticdata.bridgehub.adapter.RecordList;
import static com.kineticdata.bridgehub.adapter.kineticcore.KineticCoreAdapter.logger;
import java.io.IOException;
import java.net.URLEncoder;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.apache.commons.codec.binary.Base64;
import org.apache.commons.lang.StringUtils;
import org.apache.commons.lang.builder.CompareToBuilder;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.util.EntityUtils;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.JSONValue;

/**
 *
 */
public class KineticCoreDatastoreSubmissionHelper {
    private final String username;
    private final String password;
    private final String spaceUrl;
    private final Pattern fieldPattern;

    public KineticCoreDatastoreSubmissionHelper(String username, String password, String spaceUrl) {
        this.username = username;
        this.password = password;
        this.spaceUrl = spaceUrl;
        this.fieldPattern = Pattern.compile("(\\S+)\\[(.*?)\\]");
    }

    public Count count(BridgeRequest request) throws BridgeError {
       Integer count = countDatastoreSubmissions(request,null);

        return new Count(count);
    }

    public Record retrieve(BridgeRequest request) throws BridgeError {
        String recordId = null;
        if (request.getQuery().matches("(?i)id=.*?(?:$|&)")) {
            Pattern p = Pattern.compile("id=(.*?)(?:$|&)",Pattern.CASE_INSENSITIVE);
            Matcher m = p.matcher(request.getQuery());

            if (m.find()) recordId = m.group(1);
        }

        String url;
        JSONObject record;
        if (recordId == null) {
            JSONObject response = searchDatastoreSubmissions(request);
            JSONArray submissions = (JSONArray)response.get("submissions");

            if (submissions.size() > 1) {
                throw new BridgeError("Multiple results matched an expected single match query");
            } else if (submissions.isEmpty()) {
                record = null;
            } else {
                record = (JSONObject)submissions.get(0);
            }
        } else {
            url = String.format("%s/app/api/v1/datastore/submissions/%s?include=values,details",this.spaceUrl,recordId);

            HttpClient client = HttpClients.createDefault();
            HttpResponse response;
            HttpGet get = new HttpGet(url);
            get = addAuthenticationHeader(get, this.username, this.password);

            String output = "";
            try {
                response = client.execute(get);

                logger.trace("Request response code: " + response.getStatusLine().getStatusCode());
                HttpEntity entity = response.getEntity();
                if (response.getStatusLine().getStatusCode() == 404) {
                    throw new BridgeError(String.format("Not Found: The record with the id '%s' cannot be found.",recordId));
                }
                output = EntityUtils.toString(entity);
            }
            catch (IOException e) {
                logger.error(e.getMessage());
                throw new BridgeError("Unable to make a connection to the Kinetic Core server.",e);
            }

            JSONObject json = (JSONObject)JSONValue.parse(output);
            record = (JSONObject)json.get("submission");
        }

        return createRecordFromDatastoreRecord(request.getFields(), record);
    }

    public RecordList search(BridgeRequest request) throws BridgeError {
        // Initialize the metadata variable that will be returned
        Map<String,String> metadata = new LinkedHashMap<String,String>();
        JSONObject response = searchDatastoreSubmissions(request);
        JSONArray datastoreSubmissions = (JSONArray)response.get("submissions");

        List<Record> records = createRecordsFromDatastoreSubmissions(request.getFields(), datastoreSubmissions);

        // Sort the records if they are all returned in a second page
        if (request.getMetadata("order") == null && response.get("nextPageToken") == null) {
            // name,type,desc assumes name ASC,type ASC,desc ASC
            Map<String,String> defaultOrder = new LinkedHashMap<String,String>();
            for (String field : request.getFields()) {
                defaultOrder.put(field, "ASC");
            }
            records = sortDatastoreSubmissions(defaultOrder, records);
        } else if (response.get("nextPageToken") == null) {
        // Creates a map out of order metadata
          Map<String,String> orderParse = BridgeUtils.parseOrder(request.getMetadata("order"));
          records = sortDatastoreSubmissions(orderParse, records);
        } else {
            metadata.put("warning","Datastore Submissions won't be ordered because there is more than one page of results returned.");
            logger.debug("Warning: Datastore Submissions won't be ordered because there is more than one page of results returned.");
        }

        metadata.put("size", String.valueOf(records.size()));
        metadata.put("nextPageToken",(String)response.get("nextPageToken"));

        // Return the response
        return new RecordList(request.getFields(), records, metadata);
    }

    /*---------------------------------------------------------------------------------------------
     * HELPER METHODS
     *-------------------------------------------------------------------------------------------*/

    private HttpGet addAuthenticationHeader(HttpGet get, String username, String password) {
        String creds = username + ":" + password;
        byte[] basicAuthBytes = Base64.encodeBase64(creds.getBytes());
        get.setHeader("Authorization", "Basic " + new String(basicAuthBytes));

        return get;
    }

    // A helper method used to call createRecordsFromDatastoreSubmissions but with a
    // single record instead of an array
    private Record createRecordFromDatastoreRecord(List<String> fields, JSONObject datastoreRecord) throws BridgeError {
        Record record;
        if (datastoreRecord != null) {
            JSONArray jsonArray = new JSONArray();
            jsonArray.add(datastoreRecord);
            record = createRecordsFromDatastoreSubmissions(fields,jsonArray).get(0);
        } else {
            record = new Record();
        }
        return record;
    }

    private List<Record> createRecordsFromDatastoreSubmissions(List<String> fields, JSONArray datastoreSubmissions) throws BridgeError {
        // Create 'searchable' field list. If there needs to be a multi-level
        // search (aka, values[Group]) the field's type will be List<String>
        // instead of just String
        List searchableFields = new ArrayList();
        for (String field : fields) {
            Matcher matcher = fieldPattern.matcher(field);
            if (matcher.find()) {
                List<String> multiLevelField = new ArrayList<String>();
                multiLevelField.add(matcher.group(1));
                multiLevelField.add(matcher.group(2));
                searchableFields.add(multiLevelField);
            } else {
                searchableFields.add(field);
            }
        }

        // Go through the records in the JSONArray to create a list of records
        List<Record> records = new ArrayList<Record>();
        for (Object o : datastoreSubmissions) {
            records.add(new Record((Map)o));
        }

        // Get any field values from a JSON object if the field is in the form of field[jsonKey]
        records = BridgeUtils.getNestedFields(fields,records);

        return records;
    }

    private Integer countDatastoreSubmissions(BridgeRequest request, String pageToken) throws BridgeError {
        Integer count = 0;
        String[] indvQueryParts = request.getQuery().split("&");

        // Retrieving the datastore slug that was passed in the query
        String formSlug = null;
        List<String> queryPartsList = new ArrayList<String>();
        for (String indvQueryPart : indvQueryParts) {
            String[] str_array = indvQueryPart.split("=");
            String field = str_array[0].trim();
            String value = "";
            if (str_array.length > 1) value = str_array[1].trim();
            if (field.equals("formSlug")) { formSlug = value; }
            else if (!field.equals("limit")) { // ignore the limit, because count always uses the default limit
                queryPartsList.add(URLEncoder.encode(field) + "=" + URLEncoder.encode(value));
            }
        }
        queryPartsList.add("limit=1000");
        String query = StringUtils.join(queryPartsList,"&");

        if (formSlug == null) {
            throw new BridgeError("Invalid Request: The bridge query needs to include a formSlug.");
        }


        // Make sure that the pageToken isn't null for the first pass.
        String nextToken = pageToken != null ? pageToken : "";
        while (nextToken != null) {
            // the token query is used to reset the query each time so that multiple pageTokens
            // aren't added to the query after multiple passes
            String tokenQuery = query;
            // if nextToken is empty, don't add to query (only relevant on first pass)
            if (!nextToken.isEmpty()) {
                tokenQuery = tokenQuery+"&pageToken="+nextToken;
            }
            JSONObject json = searchDatastoreSubmissions(formSlug, tokenQuery);
            nextToken = (String)json.get("nextPageToken");
            JSONArray submissions = (JSONArray)json.get("submissions");
            count += submissions.size();
        }

        return count;
    }

    private JSONObject searchDatastoreSubmissions(BridgeRequest request) throws BridgeError {
        String[] indvQueryParts = request.getQuery().split("&(?=[^&]*?=)");

        // Retrieving the form slug that was passed in the query
        String formSlug = null;
        String limit = null;
        List<String> queryPartsList = new ArrayList<String>();
        for (String indvQueryPart : indvQueryParts) {
            String[] str_array = indvQueryPart.split("=");
            String field = str_array[0].trim();
            String value = "";
            if (str_array.length > 1) value = StringUtils.join(Arrays.copyOfRange(str_array, 1, str_array.length),"=");
            if (field.equals("formSlug")) { formSlug = value; }
            else if (field.equals("limit")) { limit = value; }
            else {
                queryPartsList.add(URLEncoder.encode(field) + "=" + URLEncoder.encode(value.trim()));
            }
        }
        // Add the include statement to get extra values and details
        queryPartsList.add("include=values,details");

        // Add a limit to the query by either using the value that was passed, or defaulting limit=200
        String pageSize = request.getMetadata("pageSize");
        if (pageSize != null) {
            queryPartsList.add("limit="+pageSize);
        } else if (limit != null && !limit.isEmpty()) {
            queryPartsList.add("limit="+limit);
        } else {
            queryPartsList.add("limit=1000");
        }

        // If metadata[nextPageToken] is included in the request, add it to the query
        if (request.getMetadata("pageToken") != null) {
            queryPartsList.add("pageToken="+request.getMetadata("pageToken"));
        }

        // Join the query list into a query string
        String query = StringUtils.join(queryPartsList,"&");

        if (formSlug == null) {
            throw new BridgeError("Invalid Request: The bridge query needs to include a formSlug.");
        }

        return searchDatastoreSubmissions(formSlug, query);
    }

    private JSONObject searchDatastoreSubmissions(String datastore, String query) throws BridgeError {
        // Initializing the Http Objects
        HttpClient client = HttpClients.createDefault();
        HttpResponse response;

        // Build the datastore submissions api url. Url is different based on whether the form slug has been included.
        String url = String.format("%s/app/api/v1/datastore/forms/%s/submissions?%s",this.spaceUrl,datastore,query);
        HttpGet get = new HttpGet(url);
        get = addAuthenticationHeader(get, this.username, this.password);

        String output = "";
        try {
            response = client.execute(get);

            HttpEntity entity = response.getEntity();
            output = EntityUtils.toString(entity);
            logger.trace("Request response code: " + response.getStatusLine().getStatusCode());
        }
        catch (IOException e) {
            logger.error(e.getMessage());
            throw new BridgeError("Unable to make a connection to the Kinetic Core server.",e);
        }

        logger.trace("Starting to parse the JSON Response");
        JSONObject json = (JSONObject)JSONValue.parse(output);

        if (response.getStatusLine().getStatusCode() == 404) {
            throw new BridgeError("Invalid formSlug: " + json.get("error").toString());
        } else if (response.getStatusLine().getStatusCode() != 200) {
            String errorMessage = json.containsKey("error") ? json.get("error").toString() : json.toJSONString();
            throw new BridgeError("Bridge Error: " + errorMessage);
        }

        JSONArray messages = (JSONArray)json.get("messages");

        if (!messages.isEmpty()) {
            logger.trace("Message from the Datastore Submissions API for the follwing query: "+query+"\n"+StringUtils.join(messages,"; "));
        }

        return json;
    }

    /**
    * Returns the string value of the object.
    * <p>
    * If the value is not a String, a JSON representation of the object will be returned.
    *
    * @param value
    * @return
    */
    private static String toString(Object value) {
        String result = null;
        if (value != null) {
            if (String.class.isInstance(value)) {
                result = (String)value;
            } else {
                result = JSONValue.toJSONString(value);
            }
        }
        return result;
    }

    protected List<Record> sortDatastoreSubmissions(final Map<String,String> fieldParser, List<Record> submissions) throws BridgeError {
        Collections.sort(submissions, new Comparator<Record>() {
            @Override
            public int compare(Record r1, Record r2){
                CompareToBuilder comparator = new CompareToBuilder();

                for (Map.Entry<String,String> entry : fieldParser.entrySet()) {
                    String field = entry.getKey();
                    String order = entry.getValue();

                    Object o1 = r1.getValue(field);
                    if (o1 != null) { o1 = KineticCoreDatastoreSubmissionHelper.toString(o1).toLowerCase(); }

                    Object o2 = r2.getValue(field);
                    if (o2 != null) { o2 = KineticCoreDatastoreSubmissionHelper.toString(o2).toLowerCase(); }

                    if (order.equals("DESC")) {
                        comparator.append(o2,o1);
                    } else {
                        comparator.append(o1,o2);
                    }
                }

                return comparator.toComparison();
            }
        });
        return submissions;
    }
}
