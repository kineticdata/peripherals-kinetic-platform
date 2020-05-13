package com.kineticdata.bridgehub.adapter.kineticcore;

import com.kineticdata.bridgehub.adapter.BridgeError;
import com.kineticdata.bridgehub.adapter.BridgeRequest;
import com.kineticdata.bridgehub.adapter.BridgeUtils;
import com.kineticdata.bridgehub.adapter.Count;
import com.kineticdata.bridgehub.adapter.Record;
import com.kineticdata.bridgehub.adapter.RecordList;
import static com.kineticdata.bridgehub.adapter.kineticcore.KineticCoreAdapter.logger;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
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
public class KineticCoreSubmissionHelper {
    private final String username;
    private final String password;
    private final String spaceUrl;
    private final KineticCoreQualificationParser qualificationParser;

    public KineticCoreSubmissionHelper(String username, String password, String spaceUrl) {
        this.username = username;
        this.password = password;
        this.spaceUrl = spaceUrl;
        this.qualificationParser = new KineticCoreQualificationParser();
    }

    public Count count(BridgeRequest request) throws BridgeError {
        // Initialize the count variable
        Integer count = 0;
        
        // Parse the query
        Map<String,String> parsedQuery = this.qualificationParser.parseSubmissionQuery(request);
        Map<String,String> metadata = new HashMap<String,String>();
        metadata.put("limit","1000");
        
        JSONObject response = requestSubmissions(parsedQuery,metadata);
        count += ((JSONArray)response.get("submissions")).size();
        while (response.get("nextPageToken") != null) {
            metadata.put("pageToken",response.get("nextPageToken").toString());
            response = requestSubmissions(parsedQuery,metadata);
            count += ((JSONArray)response.get("submissions")).size();
        }

        return new Count(count);
    }

    public Record retrieve(BridgeRequest request) throws BridgeError {
        String submissionId = null;
        Pattern p = Pattern.compile("id=([^&]+)",Pattern.CASE_INSENSITIVE);
        Matcher m = p.matcher(request.getQuery());
        if (m.matches()) {
            submissionId = m.group(1);
        }

        String url;
        JSONObject submission;
        if (submissionId == null) {
            // Parse the query
            Map<String,String> parsedQuery = this.qualificationParser.parseSubmissionQuery(request);
            JSONObject response = requestSubmissions(parsedQuery);
            JSONArray submissions = (JSONArray)response.get("submissions");

            if (submissions.size() > 1) {
                throw new BridgeError("Multiple results matched an expected single match query");
            } else if (submissions.isEmpty()) {
                submission = null;
            } else {
                submission = (JSONObject)submissions.get(0);
            }
        } else {
            url = String.format("%s/app/api/v1/submissions/%s?include=values,details",this.spaceUrl,submissionId);

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
                    throw new BridgeError(String.format("Not Found: The submission with the id '%s' cannot be found.",submissionId));
                }
                output = EntityUtils.toString(entity);
            }
            catch (IOException e) {
                logger.error(e.getMessage());
                throw new BridgeError("Unable to make a connection to the Kinetic Core server.");
            }

            JSONObject json = (JSONObject)JSONValue.parse(output);
            submission = (JSONObject)json.get("submission");
        }

        return createRecordFromSubmission(request.getFields(), submission);
    }

    public RecordList search(BridgeRequest request) throws BridgeError {
        Map<String,String> metadata = new HashMap<String,String>();
        
        // Default the limit to 1000 unless limit
        if (request.getMetadata() == null || !request.getMetadata().containsKey("limit")) {
            Map<String,String> inputMeta = request.getMetadata() == null ? new HashMap<String,String>() : request.getMetadata();
            inputMeta.put("limit", "1000");
            request.setMetadata(inputMeta);
        }

        // Parse the query
        Map<String,String> parsedQuery = this.qualificationParser.parseSubmissionQuery(request);
        JSONObject response = requestSubmissions(parsedQuery,request.getMetadata());
        JSONArray submissions = (JSONArray)response.get("submissions");

        List<String> fields = new ArrayList<String>(request.getFields());
        if (parsedQuery.containsKey("parent") || parsedQuery.containsKey("ancestor")) {
            fields.add("kappSlug");
            fields.add("formSlug");
        }
        List<Record> records = createRecordsFromSubmissions(fields, submissions);

        // Sort the records if they are all returned in a second page
        if (request.getMetadata("order") == null && response.get("nextPageToken") == null) {
            // name,type,desc assumes name ASC,type ASC,desc ASC
            Map<String,String> defaultOrder = new LinkedHashMap<String,String>();
            for (String field : fields) {
                defaultOrder.put(field, "ASC");
            }
            records = sortRecords(defaultOrder, records);
        } else if (response.get("nextPageToken") == null) {
          // Creates a map out of order metadata
          Map<String,String> orderParse = BridgeUtils.parseOrder(request.getMetadata("order"));
          // Check for any fields in the order metadata that aren't included in the field list
          for (String field : orderParse.keySet()) {
              if (!fields.contains(field)) {
                  // If any fields are hit that are in the sort metadata and not the field list,
                  // rebuild the record list while including the sort fields in the included fields
                  Set<String> allFields = new HashSet<String>(fields);
                  allFields.addAll(orderParse.keySet());
                  records = createRecordsFromSubmissions(new ArrayList<String>(allFields),submissions);
                  break;
              }
          }
          records = sortRecords(orderParse, records);
        } else {
            metadata.put("warning","Records won't be ordered because there is more than one page of results returned.");
            logger.debug("Warning: Records won't be ordered because there is more than one page of results returned.");
        }

        metadata.put("size", String.valueOf(submissions.size()));
        metadata.put("nextPageToken",(String)response.get("nextPageToken"));

        // Return the response
        return new RecordList(request.getFields(), records, metadata);
    }
    
    /*---------------------------------------------------------------------------------------------
     * QUERY HELPER METHODS
     *-------------------------------------------------------------------------------------------*/
    
    private JSONObject requestSubmissions(Map<String,String> query) throws BridgeError {
        return requestSubmissions(query,null);
    }

    private JSONObject requestSubmissions(Map<String,String> query, Map<String,String> metadata) throws BridgeError {
        // Build the URL
        String url;
        if (query.containsKey("parent") || query.containsKey("ancestor")) {
            url = query.containsKey("parent") 
                ? String.format("%s/app/api/v1/submissions/%s?include=children.details,children.values,children.form,children.form.kapp",this.spaceUrl,query.get("parent"))
                : String.format("%s/app/api/v1/submissions/%s?include=descendants.details,descendants.values,descendants.form,descendants.form.kapp",this.spaceUrl,query.get("ancestor"));
        } else {
            url = query.containsKey("formSlug")
                ? String.format("%s/app/api/v1/kapps/%s/forms/%s/submissions?include=details,values",this.spaceUrl,query.get("kappSlug"),query.get("formSlug"))
                : String.format("%s/app/api/v1/kapps/%s/submissions?include=details,values",this.spaceUrl,query.get("kappSlug"));
            if (!query.get("encodedQuery").isEmpty()) url += "&"+query.get("encodedQuery");
        }
        
        if (metadata != null) {
            for (Map.Entry<String,String> param : metadata.entrySet()) {
                if (!param.getKey().equals("order")) url = url+"&"+param.getKey()+"="+param.getValue();
            }
        }

        // Initializing the Http Objects
        HttpClient client = HttpClients.createDefault();
        HttpResponse response;
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
            throw new BridgeError("Resource Not Found: " + json.get("error").toString());
        } else if (response.getStatusLine().getStatusCode() != 200) {
            String errorMessage = json.containsKey("error") ? json.get("error").toString() : json.toJSONString();
            throw new BridgeError("Bridge Error: " + errorMessage);
        }

        // Check if any messages were returned with the response (and log them if there were any)
        JSONArray messages = (JSONArray)json.get("messages");
        if (messages != null && !messages.isEmpty()) {
            logger.trace("Message from the Submissions API for the follwing query: "+query+"\n"+StringUtils.join(messages,"; "));
        }

        // Parse the results
        JSONObject results;
        if (query.containsKey("parent") || query.containsKey("ancestor")) {
            JSONObject submission = (JSONObject)json.get("submission");
            JSONArray children = (JSONArray)(query.containsKey("parent") ? submission.get("children") : submission.get("descendants"));
            // Add kappSlug and formSlug to each submission object
            if (query.containsKey("kappSlug") || query.containsKey("formSlug")) {
                for (int i=0; i<children.size(); i++) {
                    JSONObject child = (JSONObject)children.get(i);
                    JSONObject form = (JSONObject)child.get("form");
                    if (query.containsKey("kappSlug")) {
                        String kappSlug = form != null && form.containsKey("kapp") ? (String)((JSONObject)form.get("kapp")).get("slug") : null;
                        child.put("kappSlug",kappSlug);
                    }
                    if (query.containsKey("formSlug")) {
                        String formSlug = form != null ? (String)form.get("slug") : null;
                        child.put("formSlug",formSlug);
                    }
                    // Replace the previous child object with the child object containing the kappSlug/formSlug
                    children.remove(i);
                    children.add(i,child);
                }
                // Add the kappSlug and formSlug to the main query if they were included originally
                if (query.containsKey("kappSlug")) query.put("query",query.get("query")+"kappSlug="+query.get("kappSlug")+"&");
                if (query.containsKey("formSlug")) query.put("query",query.get("query")+"formSlug="+query.get("formSlug")+"&");
            }

            // Create a sample JSONObject submissions return object that matches the normal return
            // from the submissions object
            results = new JSONObject();
            results.put("nextPageToken",null);
            results.put("submissions",FilterUtils.filterSubmissions(children,query.get("query")));
        } else {
            results = json;
        }
        return results;
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

    // A helper method used to call createRecordsFromSubmissions but with a
    // single record instead of an array
    private Record createRecordFromSubmission(List<String> fields, JSONObject submission) throws BridgeError {
        Record record;
        if (submission != null) {
            JSONArray jsonArray = new JSONArray();
            jsonArray.add(submission);
            record = createRecordsFromSubmissions(fields,jsonArray).get(0);
        } else {
            record = new Record();
        }
        return record;
    }

    private List<Record> createRecordsFromSubmissions(List<String> fields, JSONArray submissions) throws BridgeError {
        // Go through the submissions in the JSONArray to create a list of records
        List<Record> records = new ArrayList<Record>();
        for (Object o : submissions) {
            records.add(new Record((Map)o));
        }

        // Get any field values from a JSON object if the field is in the form of field[jsonKey]
        records = BridgeUtils.getNestedFields(fields,records);

        return records;
    }

    protected List<Record> sortRecords(final Map<String,String> fieldParser, List<Record> records) throws BridgeError {
        Collections.sort(records, new Comparator<Record>() {
            @Override
            public int compare(Record r1, Record r2){
                CompareToBuilder comparator = new CompareToBuilder();

                for (Map.Entry<String,String> entry : fieldParser.entrySet()) {
                    String field = entry.getKey();
                    String order = entry.getValue();

                    Object o1 = r1.getValue(field);
                    if (o1 != null) { o1 = KineticCoreSubmissionHelper.toString(o1).toLowerCase(); }

                    Object o2 = r2.getValue(field);
                    if (o2 != null) { o2 = KineticCoreSubmissionHelper.toString(o2).toLowerCase(); }

                    if (order.equals("DESC")) {
                        comparator.append(o2,o1);
                    } else {
                        comparator.append(o1,o2);
                    }
                }

                return comparator.toComparison();
            }
        });
        return records;
    }
}
