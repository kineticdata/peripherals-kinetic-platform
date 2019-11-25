package com.kineticdata.bridgehub.adapter.kinetic.platform;

import com.kineticdata.bridgehub.adapter.BridgeAdapter;
import com.kineticdata.bridgehub.adapter.BridgeError;
import com.kineticdata.bridgehub.adapter.BridgeRequest;
import com.kineticdata.bridgehub.adapter.BridgeUtils;
import com.kineticdata.bridgehub.adapter.Count;
import com.kineticdata.bridgehub.adapter.Record;
import com.kineticdata.bridgehub.adapter.RecordList;
import com.kineticdata.commons.v1.config.ConfigurableProperty;
import com.kineticdata.commons.v1.config.ConfigurablePropertyMap;
import java.io.IOException;
import java.nio.charset.Charset;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import org.apache.commons.codec.binary.Base64;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.NameValuePair;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.utils.URLEncodedUtils;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.message.BasicNameValuePair;
import org.apache.http.util.EntityUtils;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.JSONValue;
import org.slf4j.LoggerFactory;

/**
 * The main class for the Core v2 adapter.  The Bridge required methods search,
 * count and retrieve are defined in this file.
 */
public class KineticCoreAdapter implements BridgeAdapter {
    /*----------------------------------------------------------------------------------------------
     * CONSTRUCTOR
     *--------------------------------------------------------------------------------------------*/
    public KineticCoreAdapter () {
        this.parser = new KineticCoreQualificationParser();
    }
    
    /*----------------------------------------------------------------------------------------------
     * STRUCTURES
     *      KineticCoreMapping( Structure Name, Plural Accessor, Single Accessor,
     *          Implicate Feilds, Pagination Supported Function, Path Function)
     *--------------------------------------------------------------------------------------------*/
    public static Map<String,KineticCoreMapping> MAPPINGS 
        = new HashMap<String,KineticCoreMapping>() {{
        put("Submissions", new KineticCoreMapping("Submissions", "submissions", 
            "submission", Arrays.asList("values","details"),
            Arrays.asList("closedAt","createdAt","submittedAt","updatedAt"),
            KineticCoreAdapter::paginationSupportedForRestrictedModelTimeline,
            KineticCoreAdapter::pathSubmissions));
        put("Forms", new KineticCoreMapping("Forms", "forms", "form", 
            Arrays.asList("details", "attributes"),
            Arrays.asList("createdAt", "name", "slug", "updatedAt", "status",
                "type", "attributes\\[.+\\]"),
            KineticCoreAdapter::paginationSupportedForUnrestrictedModel,
            KineticCoreAdapter::pathForms));
        put("Users", new KineticCoreMapping("Users", "users", "user",
            Arrays.asList("attributes", "profileAttributes"),
            Arrays.asList("createdAt","displayName","email","updatedAt","username"),
            KineticCoreAdapter::paginationSupportedForRestrictedModelOrderBy,
            KineticCoreAdapter::pathUsers));
        put("Teams", new KineticCoreMapping("Teams", "teams", "team", 
            Arrays.asList("attributes","memberships","details"),
            Arrays.asList("created", "localName", "name", "updatedAt"),
            KineticCoreAdapter::paginationSupportedForRestrictedModelOrderBy,
            KineticCoreAdapter::pathTeams));
        put("Kapps", new KineticCoreMapping("Kapps", "kapps", "kapp", 
            Arrays.asList("details", "attributes"),
            Arrays.asList("createdAt", "name", "slug", "updateAt","status", "attributes\\[.+\\]"),
            KineticCoreAdapter::paginationSupportedForUnrestrictedModel,
            KineticCoreAdapter::pathKapps));
        put("Datastore Forms", new KineticCoreMapping("Datastore Forms", "forms", 
             "form", Arrays.asList("details", "attributes"),
            Arrays.asList("createdAt", "name", "slug", "updatedAt", "status", "attributes\\[.+\\]"),
            KineticCoreAdapter::paginationSupportedForUnrestrictedModel,
            KineticCoreAdapter::pathDatastoreForms));
        put("Datastore Submissions", new KineticCoreMapping("Datastore Submissions", 
            "submissions", "submission", Arrays.asList("details", "values"),
            KineticCoreAdapter::paginationSupportedForIndexedModel,
            KineticCoreAdapter::pathDatastoreSubmissions));
        put("Space", new KineticCoreMapping("Space", "", "space", 
            Arrays.asList("details", "attributes"),
            Arrays.asList("createdAt", "name", "slug", "updateAt", "attributes\\[.+\\]"),
            KineticCoreAdapter::paginationSupportedForUnrestrictedModel,
            KineticCoreAdapter::pathSpace));
    }};
    
    /*----------------------------------------------------------------------------------------------
     * PROPERTIES
     *--------------------------------------------------------------------------------------------*/

    /** Defines the adapter display name. */
    public static final String NAME = "Kinetic Core v2 Bridge";

    /** Defines the logger */
    protected static final org.slf4j.Logger logger = 
        LoggerFactory.getLogger(KineticCoreAdapter.class);

    /** Adapter version constant. */
    public static String VERSION;
    /** Load the properties version from the version.properties file. */
    static {
        try {
            java.util.Properties properties = new java.util.Properties();
            properties.load(KineticCoreAdapter.class.getResourceAsStream("/" 
                + KineticCoreAdapter.class.getName()+".version"));
            VERSION = properties.getProperty("version");
        } catch (IOException e) {
            logger.warn("Unable to load "+KineticCoreAdapter.class.getName() 
                + " version properties.", e);
            VERSION = "Unknown";
        }
    }

    /** Defines the collection of property names for the adapter. */
    public static class Properties {
        public static final String USERNAME = "Username";
        public static final String PASSWORD = "Password";
        public static final String SPACE_URL = "Kinetic Core Space Url";
    }
    private String username;
    private String password;
    private String spaceUrl;
    private KineticCoreApiHelper coreApiHelper;
    private KineticCoreQualificationParser parser;
    private static final Pattern NESTED_PATTERN = Pattern.compile("(.*?)\\[(.*?)\\]");

    private final ConfigurablePropertyMap properties = new ConfigurablePropertyMap(
        new ConfigurableProperty(Properties.USERNAME).setIsRequired(true),
        new ConfigurableProperty(Properties.PASSWORD).setIsRequired(true)
            .setIsSensitive(true),
        new ConfigurableProperty(Properties.SPACE_URL).setIsRequired(true)
    );
    
    @Override
    public String getName() {
        return NAME;
    }

    @Override
    public String getVersion() {
       return VERSION;
    }

    @Override
    public ConfigurablePropertyMap getProperties() {
        return properties;
    }

    @Override
    public void setProperties(Map<String,String> parameters) {
        properties.setValues(parameters);
    }

    /*---------------------------------------------------------------------------------------------
     * SETUP METHODS
     *-------------------------------------------------------------------------------------------*/
    @Override
    public void initialize() throws BridgeError {
        this.spaceUrl = properties.getValue(Properties.SPACE_URL);
        this.username = properties.getValue(Properties.USERNAME);
        this.password = properties.getValue(Properties.PASSWORD);
        this.coreApiHelper = new KineticCoreApiHelper(this.username, 
            this.password, this.spaceUrl);

        // Testing the configuration values to make sure that they
        // correctly authenticate with Core
        coreApiHelper.testAuth(spaceUrl + "/app/api/v1/space");
    }

    /*---------------------------------------------------------------------------------------------
     * IMPLEMENTATION METHODS
     *-------------------------------------------------------------------------------------------*/
    @Override
    public Count count(BridgeRequest request) throws BridgeError {
        // update query with parameter values
        request.setQuery(substituteQueryParameters(request));
        // parse Structure
        String[] structureArray = request.getStructure().trim().split("\\s*>\\s*");
        // get Structure model
        KineticCoreMapping mapping = getMapping(structureArray[0]);
        // get a map of parameters from the request
        Map<String, String> parameters = parser.getParameters(request.getQuery());
        
        if (!parameters.containsKey("limit")) {
            parameters.put("limit", "1000");
        }
        
        Map<String, NameValuePair> parameterMap = buildNameValuePairMap(parameters);
        
        String response = coreApiHelper.executeRequest(request, 
            getUrl(mapping.getPathBuilder().apply(structureArray, parameters),
                parameterMap), parser);
        
        Map<String,String> metadata = new LinkedHashMap<String, String>();
        int count = 0;
        // parse response
        try {
            JSONObject json = (JSONObject)JSONValue.parse(response);
            JSONArray pluralResult = new JSONArray();
            
            pluralResult = (JSONArray)json.get(mapping.getPlural());
            // Check if forms or form property was returned.
            if (pluralResult != null) {
                count = pluralResult.size();
            } else if ((JSONObject)json.get(mapping.getSingular()) != null) {
                count = 1;
            } else {
                count = 0;
            }
            
            String nextPageToken = String.valueOf(json.getOrDefault("nextPageToken",
                null));

            metadata.put("pageToken",nextPageToken);
        } catch (Exception e) {
            logger.error("An Exception occured trying to parse JSON: " + e); 
            throw new BridgeError("There was an error Parsing the response");
        }
        
        return new Count(count, metadata);
    }

    @Override
    public Record retrieve(BridgeRequest request) throws BridgeError {
        // update query with parameter values
        request.setQuery(substituteQueryParameters(request));
        // parse Structure
        String[] structureArray = request.getStructure().trim().split("\\s*>\\s*");
        // get Structure model
        KineticCoreMapping mapping = getMapping(structureArray[0]);
        // get a map of parameters from the request
        Map<String, String> parameters = parser.getParameters(request.getQuery());
        parameters = addImplicitIncludes(parameters, mapping.getImplicitIncludes());
        Map<String, NameValuePair> parameterMap = buildNameValuePairMap(parameters);
        
        String response = coreApiHelper.executeRequest(request, 
            getUrl(mapping.getPathBuilder().apply(structureArray, parameters),
                parameterMap), parser);
        
        JSONObject singleResult = new JSONObject();
        // parse response
        try {    
            JSONObject json = (JSONObject)JSONValue.parse(response);
            JSONArray pluralResult = (JSONArray)json.get(mapping.getPlural());
            
            // Check if forms or form property was returned.
            if (pluralResult != null) {
                if (pluralResult.size() > 1) {
                    throw new BridgeError("Retrieve may only return one " 
                        + request.getStructure() + ". Please check query");
                } else if (pluralResult.size() == 1) {
                    singleResult = (JSONObject)pluralResult.get(0);
                }
            } else {
                singleResult = (JSONObject)json.get(mapping.getSingular());
            }
        } catch (Exception e) {
            logger.error("An Exception occured trying to parse JSON: " + e); 
            throw new BridgeError("There was an error Parsing the response");
        }
        
        return createRecord(request.getFields(), singleResult);
    }

    /* 
     * Sort and Pagination criteria:
     *  Two sort options availabe are server side and adapter side. The source 
     *  defines valid server side sorting options. If the results can't be sorted
     *  server side, then adapter side sorting maybe and option. Valid adater 
     *  side sorting requires that the whole dataset be in memory. In may cases
     *  this is under 1000 records.
     *
     *  Two pagination options avaliable are server side and adapter side. The
     *  source defines valid server side pagination options. If the entire result
     *  set can fit into memory then adapter sorting can be done.
     */
    @Override
    public RecordList search(BridgeRequest request) throws BridgeError {
        // update query with parameter values
        request.setQuery(substituteQueryParameters(request));
        // parse Structure
        String[] structureArray = request.getStructure().trim().split("\\s*>\\s*");
        // get Structure model
        KineticCoreMapping mapping = getMapping(structureArray[0]);
        // get a map of parameters from the request
        Map<String, String> parameters = parser.getParameters(request.getQuery());
        parameters = addImplicitIncludes(parameters, mapping.getImplicitIncludes());
        
        // memorize the requested limit (it may be overwritten when adapter side
        // sorting is leveraged and we want to apply this value to returned 
        // results)
        String limit = parameters.get("limit");
        if (limit == null) {
            limit = parameters.get("pageSize");
        }
        // intialize pagination and sorting variables
        boolean paginationSupported = false;
        LinkedHashMap<String,String> sortOrderItems = null; 
        // adapter side sorting requires an order be set by request
        if (request.getMetadata("order") != null) {
            
            sortOrderItems = getSortOrderItems(
                BridgeUtils.parseOrder(request.getMetadata("order")));
            
            List<String> paginationFields;
            if (structureArray[0].equals("Datastore Submissions")) { 
                paginationFields = 
                    Arrays.asList(parameters.get("index").split("\\s*,\\s*"));
            } else { 
                paginationFields = mapping.getPaginationFields();
            }
            paginationSupported = mapping.getPaginationPredicate().apply(
                paginationFields, parameters, sortOrderItems);
            
            // If pagination not supported by core, we retrieve upto 1000 results
            // (even if this is greater than specified limit) so that the adapter
            // can do sorting and pagination.
            if (!paginationSupported) {
                parameters.put("limit", "1000");
            }
        }
    
        Map<String, NameValuePair> parameterMap = buildNameValuePairMap(parameters);
        
        String response = coreApiHelper.executeRequest(request, 
            getUrl(mapping.getPathBuilder().apply(structureArray, parameters),
                parameterMap), parser);

        List<Record> records = new ArrayList<Record>();
        Map<String, String> metadata = request.getMetadata() != null ?
                request.getMetadata() : new HashMap<>();
        // parse response
        try {
            JSONObject json = (JSONObject)JSONValue.parse(response);
            JSONArray pluralResult = (JSONArray)json.get(mapping.getPlural());
       
            records = (pluralResult == null)
                ? Collections.emptyList()
                : createRecords(request.getFields(), pluralResult);

            String nextPageToken = (String)(json.getOrDefault("nextPageToken", null));
            metadata.put("nextPageToken", nextPageToken);
        } catch (Exception e) {
            logger.error("An Exception occured trying to parse JSON: " + e); 
            throw new BridgeError("There was an error Parsing the response");
        }
        
        
        // If server side sorting isn't supported and order is required then
        // sort adapter side.
        if (!paginationSupported && request.getMetadata("order") != null) {
            // If all the records have been retrived sort adapter side.
            if ( metadata.get("nextPageToken") == null) {
                
                int index = 0;
                int offset = records.size();
                if (limit != null) {
                    // support for adapter side pagianation
                    Integer currentPage = 0;
                    if( metadata.get("pageNumber") != null) {
                        try {
                            currentPage =
                                Integer.parseInt(metadata.get("pageNumber"));
                        } catch (NumberFormatException e) {
                            logger.error("An unexpected NumberFormatException "
                                + "occurred parsing the pageNumber metadata: " 
                                + e); 
                            throw new BridgeError("pageNumber metadata must be"
                                + " an Integer");
                        }
                    }
                    
                    metadata.put("pageSize", limit);
                    // increment page count.
                    metadata.put("pageNumber",
                        Integer.toString(currentPage + 1));
                    
                    try {
                        offset = Integer.parseInt(limit);
                    } catch  (NumberFormatException e) {
                        logger.error("An unexpected NumberFormatException "
                            + "occurred parsing the pageSize metadata: " + e); 
                        throw new BridgeError("limit metadata must be an"
                            + " Integer");
                    }
                    index = (currentPage * offset);
                    offset = index + offset;
                }
                
                KineticCoreComparator comparator =
                    new KineticCoreComparator(sortOrderItems);
                Collections.sort(records, comparator);
                records = records.subList(index, records.size() < offset ? 
                    records.size() : offset);

            } else {
                metadata.put("warning", "Results won't be ordered because there "
                    + "was more than one page of results returned.");                

                logger.debug("Warning: Results won't be ordered because there "
                    + "was more than one page of results returned.");
            }
        }
        
        return new RecordList(request.getFields(), records, metadata);
    }

    /*---------------------------------------------------------------------------------------------
     * HELPER METHODS
     *-------------------------------------------------------------------------------------------*/
    /**
     * Convert parameters from a String to a NameValuePair for use with building
     * the URL parameters
     * 
     * @param Map<String, String> parameters
     * @return Map<String, NameValuePair>
     */
    protected Map<String, NameValuePair> buildNameValuePairMap(
        Map<String, String> parameters) {
        
        Map<String, NameValuePair> parameterMap = new HashMap<>();

        parameters.forEach((key, value) -> {
            parameterMap.put(key, new BasicNameValuePair(key, value));
        });
        
        return parameterMap;
    }
         
    /**
     * Add implicit includes to the parameters Map.  Implicit includes are values
     * that get passed along with every request specific to a Structure.
     * 
     * @param Map<String, String> parameters
     * @param Set<String> implicitIncludes
     * @return Map<String, String>
     */
    protected Map<String, String> addImplicitIncludes(Map<String, String> parameters,
        Set<String> implicitIncludes) {
        
        if (parameters.containsKey("include")) {
            Set<String> includeSet = new LinkedHashSet<>();
            includeSet.addAll(Arrays.asList(parameters.get("include")
                .split("\\s*,\\s*")));

            includeSet.addAll(implicitIncludes);
        } else {
            parameters.put("include", 
                implicitIncludes.stream().collect(Collectors.joining(",")));
        }
        
        return parameters;
    }
    
    /**
     * Check that the sort order items is a true LinkedHashMap.  Sort order items
     * require that the order be maintained.
     * 
     * @param Map<String, String> uncastSortOrderItems
     * @return LinkedHashMap<String, String>
     * @throws IllegalArgumentException 
     */
    private LinkedHashMap<String, String> 
        getSortOrderItems (Map<String, String> uncastSortOrderItems)
        throws IllegalArgumentException{
        
        /* results of parseOrder does not allow for a structure that 
         * guarantees order.  Casting is required to preserver order.
         */
        if (!(uncastSortOrderItems instanceof LinkedHashMap)) {
            throw new IllegalArgumentException("MESSAGE");
        }
        
        return (LinkedHashMap)uncastSortOrderItems;
    }
     
    /**
     * This method checks that the structure on the request matches on in the 
     * Mapping internal class.  Mappings map directly to the adapters supported 
     * Structures.  
     * 
     * @param String structure
     * @return Mapping
     * @throws BridgeError 
     */
    protected KineticCoreMapping getMapping (String structure) throws BridgeError{
        KineticCoreMapping mapping = MAPPINGS.get(structure);
        if (mapping == null) {
            throw new BridgeError("Invalid Structure: '" 
                + structure + "' is not a valid structure");
        }
        return mapping;
    }
    
    /**
     * This method loops the provided JSON array and creates a record from each
     * element in the array.
     * 
     * @param List<String> fields
     * @param JSONArray @param array
     * @return List<Record>
     * @throws BridgeError 
     */
    protected List<Record> createRecords(List<String> fields, JSONArray array) 
        throws BridgeError {
        
        // For each of the API result item
        return (List<Record>) array.stream()
            .map(item -> createRecord(fields, (JSONObject) item))
            .collect(Collectors.toList());
    }
    
    /**
     * Creates a Record from the provided JSON Object.  This method has an internal
     * call to convert complex values to strings.
     * 
     * @param List<String> fields
     * @param JSONObject item
     * @return Record
     */
    private Record createRecord(List<String> fields, JSONObject item) {
        Map<String,Object> record = new HashMap<String,Object>();
        
        // Return null record if item is empty.
        if (!item.isEmpty()) {
            fields.forEach(field -> {
                Matcher matcher = NESTED_PATTERN.matcher(field);

                if (matcher.matches()) {
                    String collectionProperty = matcher.group(1);
                    String collectionKey = matcher.group(2);

                    Object collection = item.get(collectionProperty); // "attributes"
                    String value;
                    if (collection instanceof JSONArray) {
                        value = extract((JSONArray)collection, collectionKey);
                    } else if (collection instanceof JSONObject) {
                        value = extract((JSONObject)collection, collectionKey);
                    } else {
                        throw new RuntimeException("Unexpected nested property type"
                            + " for \"" + field + "\".");
                    }
                    record.put(field, value);
                } else {
                    record.put(field, extract(item, field));
                }
            });
            
            return new Record(record);
        } else {
            return new Record();
        }
    }
    
    /**
     * Convert provided property of object to a String.
     * 
     * @param JSONArray object
     * @param String key
     * @return String
     */
    private String extract(JSONArray object, String key) {
        Object matchingItem = object.stream()
            .filter(jsonObject -> jsonObject instanceof JSONObject)
            .filter(jsonObject -> ((JSONObject)jsonObject).containsKey("name") 
                && ((JSONObject)jsonObject).containsKey("values")
            )
            .filter(jsonObject -> 
                key.equals(((JSONObject)jsonObject).get("name"))
            )
            .findFirst()
            .orElse(null);
        return extract((JSONObject)matchingItem, "values");
    }

    /**
     * Convert provided property of object to a String.
     * 
     * @param JSONArray object
     * @param String key
     * @return String
     */
    private String extract(JSONObject object, String field) {
        Object value = (object == null) ? null : object.get(field);

        String result;
        if (value == null) {
            result = null;
        } else if (value instanceof JSONObject) {
            result = ((JSONObject)value).toJSONString();
        } else if (value instanceof JSONArray) {
            result = ((JSONArray)value).toJSONString();
        } else {
            result = value.toString();
        }
        return result;
    }
    
    /**
     * Build URL to be used when making request to the source system.
     * 
     * @param String path
     * @param Map<String, NameValuePair> parameters
     * @return String
     */
    protected String getUrl (String path, Map<String, NameValuePair> parameters) {
        
        return String.format("%s/app/api/v1%s?%s", spaceUrl, path, 
            URLEncodedUtils.format(parameters.values(), Charset.forName("UTF-8")));
    }
    
    // Check that only one sort order item exists
    // Check that the sore order item is in the paginated fields list
    // Users, Teams
    // paginationFields = [displayName,email]
    // parameters = {"limit","1000"}
    // sortOrderItmes = {"displayName","ACS"}
    protected static boolean paginationSupportedForRestrictedModelOrderBy(
        List<String> paginationFields, Map<String, String> parameters,
        LinkedHashMap<String, String> sortOrderItems) {
        
        return paginationSupportedForRestrictedModel(paginationFields, parameters, "orderBy",
            sortOrderItems);
    }
    
    // Check that only one sort order item exists
    // Check that the sore order item is in the paginated fields list
    // Kapp Submissions
    // paginationFields = [createdAt,updatedAt]
    // parameters = {"limit","1000"}
    // sortOrderItmes = {"displayName","ACS"}
    protected static boolean paginationSupportedForRestrictedModelTimeline(
        List<String> paginationFields, Map<String, String> parameters,
        LinkedHashMap<String, String> sortOrderItems) {
        
        return paginationSupportedForRestrictedModel(paginationFields, parameters, "timeline",
            sortOrderItems);
    }
    
    protected static boolean paginationSupportedForRestrictedModel(
        List<String> paginationFields, 
        Map<String, String> parameters,
        String parameterName, 
        LinkedHashMap<String, String> sortOrderItems
    ) {
        boolean supported;

        // Ensure that no more than one item.
        if (sortOrderItems.size() > 1) {
            logger.debug("The endpoint does not support sorting by multiple fields.");
            supported = false;
        }
        // If there is exactly one item
        else {
            // Obtain a reference to the first sort order item
            Map.Entry<String,String> firstItem = sortOrderItems.entrySet().stream()
                .findFirst()
                .orElseThrow(() -> new IllegalStateException("Unexpected state."));
            String sortBy = firstItem.getKey();
            String direction = firstItem.getValue();
            // If the pagination fields contains the sort by field
            if (paginationFields.contains(sortBy)) {
                parameters.put(parameterName, sortBy);
                parameters.put("direction", direction);
                supported = true;
            }
            // If the pagination fields does not contain the sort by field
            else {
                logger.debug("The endpoint does not support %s as an %s "
                    + "field.", sortBy, parameterName);
                supported = false;
            }
        }
        
        return supported;
    }
    
    // Check that all sort directions match for sort order items.
    // Check that all sort order items are also pagination fields.
    // Kapps, Kapp Forms, DataStore Forms, Space
    // paginationFields = [createdAt,updatedAt]
    // parameters = {"limit","1000"}
    // sortOrderItmes = {"createdAt","ACS"}
    protected static boolean paginationSupportedForUnrestrictedModel(
        List<String> paginationFields, Map<String, String> parameters,
        LinkedHashMap<String, String> sortOrderItems) {
        
        // Determine whether pagaintion is supported
        boolean unsupported = 
            // Ensuring all directions are the same
            sortOrderItems.values().stream()
                .map(String::toLowerCase)
                .distinct()
                .count() > 1
            // Ensuring all sort items are valid paginatable fields
            || !sortOrderItems.keySet().stream()
                .allMatch(key -> paginationFields.stream()
                    .anyMatch(field -> key.matches(field)));
        
        if (unsupported) {
            logger.debug("Server side sorting only supports a single key "
                    + "direction for kapps, kapp forms and datastore forms.");
        } else if (sortOrderItems.size() > 0) {
            parameters.put("orderBy", 
                String.join(",", sortOrderItems.keySet()));
            parameters.put("direction", 
                sortOrderItems.values().stream().findFirst().get());
        }
        
        return !unsupported;
    }
    
    // TODO: confirm that direction in order metadata matches qualification mapping.
    // Check that sort direction is consistent for all sort order items
    // Check that the indexs and the sortOrderItems match in value and order
    protected static boolean paginationSupportedForIndexedModel( 
        List<String> indexSegments, Map<String, String> _noOp1, 
        LinkedHashMap<String, String> sortOrderItems) {
        
        // Determine whether pagaintion is supported
        boolean unsupported = 
            // Ensuring all directions are the same
            sortOrderItems.values().stream()
                .map(String::toLowerCase)
                .distinct()
                .count() > 1
            // Ensuring all sort items are valid paginatable fields
            || !indexSupportsSortOrder(indexSegments, sortOrderItems);
        
        if (unsupported) {
            logger.debug("Server side sorting only supports a single key "
                    + "direction for datastore submissions.");
        }
        
        return !unsupported;
    }
    
    protected static boolean indexSupportsSortOrder(
        List<String> indexSegments,
        LinkedHashMap<String, String> sortOrderItems
    ) {
        boolean result = true;
        List<String> sortOrderKeys = new ArrayList<>(sortOrderItems.keySet());
        for (int i=0; i<sortOrderKeys.size(); i++) {
            if (
                i >= indexSegments.size() 
                || !Objects.equals(sortOrderKeys.get(i), indexSegments.get(i))
            ) {
                result = false;
                break;
            }
        }
        return result;
    }
    
    protected static String pathSpace(String [] structureArray,
        Map<String, String> _noOp) {
        
        return "/space";
    }
    
    protected static String pathUsers(String [] structureArray,
        Map<String, String> _noOp) {
        
        return "/users";
    }
    
    protected static String pathTeams(String [] structureArray,
        Map<String, String> _noOp) {
        
        return "/teams";
    }
    
    protected static String pathKapps(String [] structureArray,
        Map<String, String> _noOp) {
        
        return "/kapps";
    }
    
    protected static String pathDatastoreSubmissions (String [] structureArray,
        Map<String, String> parameters) throws BridgeError{
        
        String path;
        if (structureArray.length > 1) {
            if(parameters.containsKey("id")) {
                logger.debug("The Datastore Submissions structure doesn't"
                    + " support the id parameter provided with a form slug");
            }
            path = "/datastore/forms/" + structureArray[1] +"/submissions";
        } else if (structureArray.length == 1 && parameters.containsKey("id")) {
            path = "/datastore/submissions/" + parameters.get("id");
        } else {
           throw new BridgeError("The Datastore Submissions structure must have"
                + " a > :Form_Slug or the id parameter in the qualification "
                + "mapping");
        }
        return path;
    }
    
    protected static String pathDatastoreForms(String [] structureArray,
        Map<String, String> _noOp) {
        
        return "/datastore/forms";
    }
    
    protected static String pathSubmissions (String [] structureArray,
        Map<String, String> parameters) throws BridgeError{
        
        String path;
        if (structureArray.length >= 2) {
            if(parameters.containsKey("id")) {
                logger.debug("The Submissions structure doesn't support the id "
                    + "parameter provided with a form slug");
            }
            path = structureArray.length == 2 ? 
                String.format("/kapps/%s/submissions/", structureArray[1]) :
                String.format("/kapps/%s/forms/%s/submissions/",
                    structureArray[1], structureArray[2]) ;
            
        } else if (structureArray.length == 1 && parameters.containsKey("id")) {
            path = "/submissions/" + parameters.get("id");
        } else {
           throw new BridgeError("The Submissions structure must have > :Kapp_Slug"
                + " or > :Kapp_Slug > :Form_Slug or the id parameter in the "
                + "qualification mapping");
        }
        return path;
    }
    
    protected static String pathForms(String [] structureArray,
        Map<String, String> _noOp) throws BridgeError {
        
        if (structureArray.length > 1) {
            return String.format("/kapps/%s/forms", structureArray[1]);
        } else {
            throw new BridgeError("The Forms structure must have > :Kapp_Slug"
                    + " in the qualification mapping");
        }
    }
    
    private String substituteQueryParameters(BridgeRequest request) throws BridgeError {
        // Parse the query and exchange out any parameters with their parameter 
        // values. ie. change the query username=<%=parameter["Username"]%> to
        // username=test.user where parameter["Username"]=test.user
        return parser.parse(request.getQuery(),request.getParameters());
    }
}
