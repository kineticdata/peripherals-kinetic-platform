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
import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
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
public class KineticCoreDatastoreFormHelper {
    private final String username;
    private final String password;
    private final String spaceUrl;
    private final Pattern attributePattern;

    public KineticCoreDatastoreFormHelper(String username, String password, String spaceUrl) {
        this.username = username;
        this.password = password;
        this.spaceUrl = spaceUrl;
        this.attributePattern = Pattern.compile("(.*?)\\[(.*?)\\]");
    }

    public static final List<String> DETAIL_FIELDS = Arrays.asList(new String[] {
        "createdAt","createdBy","notes","recordLabelExpression","updatedAt","updatedBy"
    });

    public Count count(BridgeRequest request) throws BridgeError {
        JSONArray datastores = searchDatastores(request);

        // Create count object
        return new Count(datastores.size());
    }

    public Record retrieve(BridgeRequest request) throws BridgeError {
        String slug = null;
        if (request.getQuery().matches("slug=.*?(?:$|&)")) {
            Pattern p = Pattern.compile("slug=(.*?)(?:$|&)");
            Matcher m = p.matcher(request.getQuery());
            if (m.find()) slug = m.group(1);
        }

        if (slug == null) throw new BridgeError(String.format("Invalid Query: Could not find a slug in the following "+
            "query '%s'. Query must be include slug={datastore slug} to retrieve a single datastore.",request.getQuery()));

        JSONObject datastore;
        String url = String.format("%s/app/api/v1/datastore/forms/%s?include=details,attributes",this.spaceUrl,slug);

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
                throw new BridgeError("Not Found: A datastore with the slug '"+slug+"' cannot be found.");
            }
            output = EntityUtils.toString(entity);
        }
        catch (IOException e) {
            logger.error(e.getMessage());
            throw new BridgeError("Unable to make a connection to the Kinetic Core server.",e);
        }

        JSONObject json = (JSONObject)JSONValue.parse(output);
        datastore = (JSONObject)json.get("form");

        return createRecordFromDatastore(request.getFields(), datastore);
    }

    public RecordList search(BridgeRequest request) throws BridgeError {
        JSONArray datastores = searchDatastores(request);

        List<Record> records = createRecordsFromDatastores(request.getFields(), datastores);

        // Sort the records because they are always returned on one page
        if (request.getMetadata("order") == null) {
            // name,type,desc assumes name ASC,type ASC,desc ASC
            Map<String,String> defaultOrder = new LinkedHashMap<String,String>();
            for (String field : request.getFields()) {
                defaultOrder.put(field, "ASC");
            }
            records = sortRecords(defaultOrder, records);
        } else {
        // Creates a map out of order metadata
          Map<String,String> orderParse = BridgeUtils.parseOrder(request.getMetadata("order"));
          records = sortRecords(orderParse, records);
        }

        // Add pagination to the returned record list
        int pageToken = request.getMetadata("pageToken") == null || request.getMetadata("pageToken").isEmpty() ?
                0 : Integer.parseInt(new String(Base64.decodeBase64(request.getMetadata("pageToken"))));

        int limit = request.getMetadata("limit") == null || request.getMetadata("limit").isEmpty() ?
                records.size()-pageToken : Integer.parseInt(request.getMetadata("limit"));

        String nextPageToken = null;
        if (pageToken+limit < records.size()) nextPageToken = Base64.encodeBase64String(String.valueOf(pageToken+limit).getBytes());

        records = records.subList(pageToken, pageToken+limit > records.size() ? records.size() : pageToken+limit);

        Map<String,String> metadata = new LinkedHashMap<String,String>();
        metadata.put("size",String.valueOf(limit));
        metadata.put("pageToken",nextPageToken);

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

    // A helper method used to call createRecordsFromDatastores but with a
    // single record instead of an array
    private Record createRecordFromDatastore(List<String> fields, JSONObject datastore) throws BridgeError {
        JSONArray jsonArray = new JSONArray();
        jsonArray.add(datastore);
        return createRecordsFromDatastores(fields,jsonArray).get(0);
    }

    // Made protected and final for the purposes of testing
    protected final List<Record> createRecordsFromDatastores(List<String> fields, JSONArray datastores) throws BridgeError {
        // Go through the users in the JSONArray to create a list of records
        List<Record> records = new ArrayList<Record>();
        for (Object o : datastores) {
            JSONObject datastore = (JSONObject)o;
            Map<String,Object> record = new LinkedHashMap<String,Object>();
            for (String field : fields) {
                Matcher m = this.attributePattern.matcher(field);
                if (m.find()) {
                    record.put(field,getAttributeValues(m.group(1),m.group(2),datastore));
                } else {
                    record.put(field,datastore.get(field));
                }
            }
            records.add(new Record(record));
        }

        return records;
    }

    // Filter datastores was made protected for the purposes of testing
    private JSONArray searchDatastores(BridgeRequest request) throws BridgeError {
        // Initializing the Http Objects
        HttpClient client = HttpClients.createDefault();
        HttpResponse response;

        // Based on the passed fields figure out if an ?include needs to be in the Url
        List<String> includes = new ArrayList<String>();

        if (request.getQuery().contains("attributes")) includes.add("attributes");
        for (String detailField : DETAIL_FIELDS) {
            if (request.getQuery().contains(detailField)) {
                includes.add("details");
                break;
            }
        }

        if (request.getFields() != null) {
            for (String field : request.getFields()) {
                Matcher m = attributePattern.matcher(field);
                String attributeType = null;
                if (m.matches()) attributeType = m.group(1);
                if (field.equals("attributes") || (attributeType != null && attributeType.equals("attributes"))) {
                    if (!includes.contains("attributes")) includes.add("attributes");
                }
            }
            // If request.getFields() has a field in common with the detail fields list, include details
            if (!Collections.disjoint(DETAIL_FIELDS, request.getFields())) includes.add("details");
        }

        String url = this.spaceUrl+"/app/api/v1/datastore/forms";
        if (!includes.isEmpty()) url += "?include="+StringUtils.join(includes,",");
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

        if (response.getStatusLine().getStatusCode() != 200) {
            throw new BridgeError("Bridge Error: " + json.toJSONString());
        }

        JSONArray datastores = (JSONArray)json.get("forms");
        String query = request.getQuery();
        if (!query.isEmpty()) {
            datastores = filterDatastores(datastores, request.getQuery());
        }

        return datastores;
    }

    private Pattern getPatternFromValue(String value) {
        // Escape regex characters from value
        String[] parts = value.split("(?<!\\\\)%");
        for (int i = 0; i<parts.length; i++) {
            if (!parts[i].isEmpty()) parts[i] = Pattern.quote(parts[i].replaceAll("\\\\%","%"));
        }
        String regex = StringUtils.join(parts,".*?");
        if (!value.isEmpty() && value.substring(value.length() - 1).equals("%")) regex += ".*?";
        return Pattern.compile("^"+regex+"$",Pattern.CASE_INSENSITIVE);
    }

    private List getAttributeValues(String type, String name, JSONObject datastore) throws BridgeError {
        if (!datastore.containsKey(type)) throw new BridgeError(String.format("The field '%s' cannot be found on the Datastore object",type));
        JSONArray attributes = (JSONArray)datastore.get(type);
        for (Object attribute : attributes) {
            HashMap attributeMap = (HashMap)attribute;
            if (((String)attributeMap.get("name")).equals(name)) {
                return (List)attributeMap.get("values");
            }
        }
        return new ArrayList(); // Return an empty list if no values were found
    }

    protected final JSONArray filterDatastores(JSONArray datastores, String query) throws BridgeError {
        String[] queryParts = query.split("&");

        Map<String[],Object[]> queryMatchers = new HashMap<String[],Object[]>();
        // Variables used for OR query (pattern and fields)
        String pattern = null;
        String[] fields = null;
        // Iterate through the query parts and create all the possible matchers to check against
        // the user results
        for (String part : queryParts) {
            String[] split = part.split("=");
            String field = split[0].trim();
            String value = split.length > 1 ? split[1].trim() : "";

            Object[] matchers;
            if (field.equals("pattern")) {
                pattern = value;
            } else if (field.equals("fields")) {
                fields = value.split(",");
            } else {
                // If the field isn't 'pattern' or 'fields', add the field and appropriate values
                // to the query matcher
                if (value.equals("true") || value.equals("false")) {
                    matchers = new Object[] { getPatternFromValue(value), Boolean.valueOf(value) };
                } else if (value.equals("null")) {
                    matchers = new Object[] { null, getPatternFromValue(value) };
                } else if (value.isEmpty()) {
                    matchers = new Object[] { "" };
                } else {
                    matchers = new Object[] { getPatternFromValue(value) };
                }
                queryMatchers.put(new String[] { field }, matchers);
            }
        }

        // If both query and pattern are not equal to null, add the list of fields and the
        // pattern (compiled into a regex Pattern object) to the queryMatchers map
        if (pattern != null && fields != null) {
            queryMatchers.put(fields,new Object[] { Pattern.compile(".*"+Pattern.quote(pattern)+".*",Pattern.CASE_INSENSITIVE) });
        }
        // If both pattern & fields are not equals to null AND both pattern & fields are not
        // both null, that means that one is null and the other is not which is not an
        // allowed query.
        else if (pattern != null || fields != null) {
            throw new BridgeError("The 'pattern' and 'fields' parameter must be provided together.  When the 'pattern' parameter "+
                    "is provided the 'fields' parameter is required and when the 'fields' parameter is provided the 'pattern' parameter is required.");
        }

        // Start with a full list of users and then delete from the list when they don't match
        // a qualification. Will be left with a list of values that match all qualifications.
        JSONArray matchedDatastores = datastores;
        for (Map.Entry<String[],Object[]> entry : queryMatchers.entrySet()) {
            JSONArray matchedDatastoresEntry = new JSONArray();
            for (String field : entry.getKey()) {
                // If passed in field is an attribute, save its attributeName
                String attributeType = null;
                String attributeName = null;
                Matcher m = this.attributePattern.matcher(field);
                if (m.find()) {
                    attributeType = m.group(1);
                    attributeName = m.group(2);
                }

                for (Object o : matchedDatastores) {
                    JSONObject datastore = (JSONObject)o;
                    // Check if the object matches the field qualification if it hasn't already been
                    // successfully matched
                    if (!matchedDatastoresEntry.contains(o)) {
                        // Get the value for the field
                        List fieldValues = attributeName != null ? getAttributeValues(attributeType,attributeName,datastore) : Arrays.asList(new Object[] { datastore.get(field) });

                        // if field values is empty, check for an empty value
                        if (fieldValues.isEmpty()) {
                            for (Object value : entry.getValue()) {
                                if (value.equals("")) matchedDatastoresEntry.add(o);
                            }
                        } else {
                            for (Object fieldValue : fieldValues) {
                                for (Object value : entry.getValue()) {
                                    if (fieldValue == value || // Objects equal
                                       fieldValue != null && value != null && (
                                           value.getClass() == Pattern.class && ((Pattern)value).matcher(fieldValue.toString()).matches() || // fieldValue != null && Pattern matches
                                           value.equals(fieldValue) // fieldValue != null && values equal
                                       )
                                    ) {
                                        matchedDatastoresEntry.add(o);
                                    }
                                }
                            }
                        }
                    }
                }
            }
            matchedDatastores = (JSONArray)matchedDatastoresEntry;
        }

        return matchedDatastores;
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
                    Object o2 = r2.getValue(field);
                    // If the object is a type that cannot be sorted, continue to the next field
                    if (o1 instanceof List) { continue; }
                    if (o2 instanceof List) { continue; }
                    // If the object is a string, lowercase the string so that capitalization doesn't factor into the comparison
                    if (o1 != null && o1.getClass() == String.class) {o1 = o1.toString().toLowerCase();}
                    if (o2 != null && o2.getClass() == String.class) {o2 = o2.toString().toLowerCase();}

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
