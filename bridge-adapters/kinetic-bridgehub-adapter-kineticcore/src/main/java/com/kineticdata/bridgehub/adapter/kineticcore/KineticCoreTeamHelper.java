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
public class KineticCoreTeamHelper {
    private final String username;
    private final String password;
    private final String spaceUrl;
    private final Pattern attributePattern;

    public KineticCoreTeamHelper(String username, String password, String spaceUrl) {
        this.username = username;
        this.password = password;
        this.spaceUrl = spaceUrl;
        this.attributePattern = Pattern.compile("(.*?)\\[(.*?)\\]");
    }

    public static final List<String> DETAIL_FIELDS = Arrays.asList(new String[] {
        "createdAt","createdBy","updatedAt","updatedBy"
    });

    public Count count(BridgeRequest request) throws BridgeError {
        JSONArray teams = searchTeams(request);

        // Create count object
        return new Count(teams.size());
    }

    public Record retrieve(BridgeRequest request) throws BridgeError {
        JSONObject team = null;
        if (request.getQuery().matches("[Ss]lug=.*?(?:$|&)")) {
            Pattern p = Pattern.compile("[Ss]lug=(.*?)(?:$|&)");
            Matcher m = p.matcher(request.getQuery());

            String slug = "";
            if (m.find()) {
                slug = m.group(1);
            }

            String url = String.format("%s/app/api/v1/teams/%s?include=attributes,memberships,details",this.spaceUrl,slug);

            HttpClient client = HttpClients.createDefault();
            HttpResponse response;
            HttpGet get = new HttpGet(url);
            get = addAuthenticationHeader(get, this.username, this.password);

            String output = "";
            try {
                response = client.execute(get);

                logger.trace("Request response code: " + response.getStatusLine().getStatusCode());
                HttpEntity entity = response.getEntity();
                output = EntityUtils.toString(entity);
            }
            catch (IOException e) {
                logger.error(e.getMessage());
                throw new BridgeError("Unable to make a connection to the Kinetic Core server.");
            }

            if (response.getStatusLine().getStatusCode() == 200) {
                JSONObject json = (JSONObject)JSONValue.parse(output);
                team = (JSONObject)json.get("team");
            }
        } else {
            JSONArray teams = searchTeams(request);
            if (teams.size() > 1) {
                throw new BridgeError("Multiple results matched an expected single match query");
            } else if (!teams.isEmpty()) {
                team = (JSONObject)teams.get(0);
            }
        }

        return createRecordFromTeam(request.getFields(), team);
    }

    public RecordList search(BridgeRequest request) throws BridgeError {
        JSONArray teams = searchTeams(request);

        List<Record> records = createRecordsFromTeams(request.getFields(), teams);

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
          // Check for any fields in the order metadata that aren't included in the field list
          for (String field : orderParse.keySet()) {
              if (!request.getFields().contains(field)) {
                  // If any fields are hit that are in the sort metadata and not the field list,
                  // rebuild the record list while including the sort fields in the included fields
                  Set<String> allFields = new HashSet<String>(request.getFields());
                  allFields.addAll(orderParse.keySet());
                  records = createRecordsFromTeams(new ArrayList<String>(allFields),teams);
                  break;
              }
          }
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

    /**
       * Returns the string value of the object.
       * <p>
       * If the value is not a String, a JSON representation of the object will be returned.
       *
       * @param value
       * @return
       */
    private String toString(Object value) {
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

    // A helper method used to call createRecordsFromTeams but with a
    // single record instead of an array
    private Record createRecordFromTeam(List<String> fields, JSONObject team) throws BridgeError {
        if (team != null) {
            JSONArray jsonArray = new JSONArray();
            jsonArray.add(team);
            return createRecordsFromTeams(fields,jsonArray).get(0);
        } else {
            return new Record(null);
        }
    }

    // Made protected and final for the purposes of testing
    protected final List<Record> createRecordsFromTeams(List<String> fields, JSONArray teams) throws BridgeError {
        // Go through the teams in the JSONArray to create a list of records
        List<Record> records = new ArrayList<Record>();
        for (Object o : teams) {
            JSONObject team = (JSONObject)o;
            Map<String,Object> record = new LinkedHashMap<String,Object>();
            for (String field : fields) {
                Matcher m = this.attributePattern.matcher(field);
                if (m.find()) {
                    record.put(field,toString(getAttributeValues(m.group(1),m.group(2),team)));
                } else {
                    record.put(field,toString(team.get(field)));
                }
            }
            records.add(new Record(record));
        }

        return records;
    }

    // Filter teams was made protected for the purposes of testing
    private JSONArray searchTeams(BridgeRequest request) throws BridgeError {
        // Initializing the Http Objects
        HttpClient client = HttpClients.createDefault();
        HttpResponse response;

        // Based on the passed fields figure out if an ?include needs to be in the Url
        String includeParam = null;
        if (request.getFields() != null) {
            Boolean includeAttributes = false;
            Boolean includeMemberships = false;
            for (String field : request.getFields()) {
                Matcher m = attributePattern.matcher(field);
                String attributeType = null;
                if (m.matches()) {
                    attributeType = m.group(1);
                }
                if (field.equals("attributes") || request.getQuery().contains("attributes")) {
                    includeAttributes = true;
                }
                else if (field.equals("memberships") || request.getQuery().contains("memberships")) {
                    includeMemberships = true;
                }
                else if (attributeType != null) {
                    if (attributeType.equals("attributes")) {
                        includeAttributes = true;
                    }
                }
                if (includeAttributes) break;
            }
            if (includeAttributes) includeParam = "include=attributes";
            if (includeMemberships) includeParam = includeParam == null ? "include=memberships" : includeParam + ",memberships";
            // If request.getFields() has a field in common with the detail fields list, include details
            if (!Collections.disjoint(DETAIL_FIELDS, request.getFields())) includeParam = includeParam == null ? "include=details" : includeParam + ",details";
        }

        String url = this.spaceUrl + "/app/api/v1/teams";
        if (includeParam != null) url += "?"+includeParam;
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
            throw new BridgeError("Unable to make a connection to the Kinetic Core server.");
        }

        logger.trace("Starting to parse the JSON Response");
        JSONObject json = (JSONObject)JSONValue.parse(output);

        if (response.getStatusLine().getStatusCode() != 200) {
            throw new BridgeError("Bridge Error: " + json.toJSONString());
        }

        JSONArray teams = (JSONArray)json.get("teams");

        String query = request.getQuery();
        if (!query.isEmpty()) {
            teams = filterTeams(teams, request.getQuery());
        }

        return teams;
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

    private List getAttributeValues(String type, String name, JSONObject team) throws BridgeError {
        if (!team.containsKey(type)) throw new BridgeError(String.format("The field '%s' cannot be found on the Team object",type));
        JSONArray attributes = (JSONArray)team.get(type);
        for (Object attribute : attributes) {
            HashMap attributeMap = (HashMap)attribute;
            if (((String)attributeMap.get("name")).equals(name)) {
                return (List)attributeMap.get("values");
            }
        }
        return new ArrayList(); // Return an empty list if no values were found
    }

    private List getMembershipsUserField(String fieldName, JSONObject team) throws BridgeError {
        JSONArray memberships = (JSONArray)team.get("memberships");
        List members = new ArrayList();
        for (Object membership : memberships) {
            JSONObject user = (JSONObject)((JSONObject)membership).get("user");
            members.add(user.get(fieldName));
        }
        return members;
    }

    protected final JSONArray filterTeams(JSONArray teams, String query) throws BridgeError {
        String[] queryParts = query.split("&");

        Map<String[],Object[]> queryMatchers = new HashMap<String[],Object[]>();
        // Variables used for OR query (pattern and fields)
        String pattern = null;
        String[] fields = null;
        // List of the teams to be excluded from the result set
        List<String> excludedTeams = new ArrayList<String>();
        // Iterate through the query parts and create all the possible matchers to check against
        // the team results
        for (String part : queryParts) {
            String[] split = part.split("=");
            String field = split[0].trim();
            String value = split.length > 1 ? split[1].trim() : "";

            Object[] matchers;
            if (field.equals("pattern")) {
                pattern = value;
            } else if (field.equals("fields")) {
                fields = value.split(",");
            } else if (field.equals("exclude")) {
                excludedTeams.add(value.toLowerCase());
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

        // Before sorting through with query matcher qualifications, go through and exclude
        // any teams (and their descendants) that are in the excluded team array
        JSONArray matchedTeams = new JSONArray();
        for (Object o : teams) {
            JSONObject team = (JSONObject)o;

            boolean teamExcluded = false;
            String teamName = (String)team.get("name");
            for (String excludedTeam : excludedTeams) {
                if (teamName.toLowerCase().equals(excludedTeam) || teamName.toLowerCase().startsWith(excludedTeam+"::")) {
                    teamExcluded = true;
                }
            }
            if (!teamExcluded) matchedTeams.add(o);
        }

        // Start with the list of teams that weren't excluded and then delete from the list
        // when they don't match a qualification. Will be left with a list of values that match
        // all qualifications.
        for (Map.Entry<String[],Object[]> entry : queryMatchers.entrySet()) {
            JSONArray matchedTeamsEntry = new JSONArray();
            for (String field : entry.getKey()) {
                // If passed in field is an attribute, save its attributeName
                String attributeType = null;
                String attributeName = null;
                Matcher m = this.attributePattern.matcher(field);
                if (m.find()) {
                    attributeType = m.group(1);
                    attributeName = m.group(2);
                }

                for (Object o : matchedTeams) {
                    // Check if the object matches the field qualification if it hasn't already been
                    // successfully matched
                    if (!matchedTeamsEntry.contains(o)) {
                        JSONObject team = (JSONObject)o;
                        // Get the value for the field
//                        List fieldValues = attributeName != null ? getAttributeValues(attributeType,attributeName,team) : Arrays.asList(new Object[] { team.get(field) });
                        List fieldValues = null;
                        if (attributeName != null) {
                            if (attributeType.equals("memberships")) {
                                fieldValues = getMembershipsUserField(attributeName, team);
                            } else {
                                fieldValues = getAttributeValues(attributeType,attributeName,team);
                            }
                        } else {
                            fieldValues = Arrays.asList(new Object[] { team.get(field) });
                        }

                        // if field values is empty, check for an empty value
                        if (fieldValues.isEmpty()) {
                            for (Object value : entry.getValue()) {
                                if (value.equals("")) matchedTeamsEntry.add(o);
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
                                        matchedTeamsEntry.add(o);
                                    }
                                }
                            }
                        }
                    }
                }
            }
            matchedTeams = (JSONArray)matchedTeamsEntry;
        }

        return matchedTeams;
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
