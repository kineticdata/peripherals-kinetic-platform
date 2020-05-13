package com.kineticdata.bridgehub.adapter.kinetictask;

import com.kineticdata.bridgehub.adapter.BridgeAdapter;
import com.kineticdata.bridgehub.adapter.BridgeError;
import com.kineticdata.bridgehub.adapter.BridgeRequest;
import com.kineticdata.bridgehub.adapter.Count;
import com.kineticdata.bridgehub.adapter.Record;
import com.kineticdata.bridgehub.adapter.RecordList;
import com.kineticdata.commons.v1.config.ConfigurableProperty;
import com.kineticdata.commons.v1.config.ConfigurablePropertyMap;
import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.apache.commons.lang.StringUtils;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.util.EntityUtils;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.JSONValue;
import org.slf4j.LoggerFactory;

/**
 *
 */
public class KineticTaskAdapter implements BridgeAdapter {
    /*----------------------------------------------------------------------------------------------
     * PROPERTIES
     *--------------------------------------------------------------------------------------------*/

    /** Defines the adapter display name. */
    public static final String NAME = "Kinetic Task Bridge";

    /** Defines the logger */
    protected static final org.slf4j.Logger logger = LoggerFactory.getLogger(KineticTaskAdapter.class);

    /** Adapter version constant. */
    public static String VERSION;
    /** Load the properties version from the version.properties file. */
    static {
        try {
            java.util.Properties properties = new java.util.Properties();
            properties.load(KineticTaskAdapter.class.getResourceAsStream("/"+KineticTaskAdapter.class.getName()+".version"));
            VERSION = properties.getProperty("version");
        } catch (IOException e) {
            logger.warn("Unable to load "+KineticTaskAdapter.class.getName()+" version properties.", e);
            VERSION = "Unknown";
        }
    }

    /** Defines the collection of property names for the adapter. */
    public static class Properties {
        public static final String TASK_URL = "Kinetic Task Url";
    }
    private String taskUrl;

    private final ConfigurablePropertyMap properties = new ConfigurablePropertyMap(
            new ConfigurableProperty(Properties.TASK_URL).setIsRequired(true)
    );

    /**
     * Structures that are valid to use in the bridge
     */
    public static final List<String> VALID_STRUCTURES = Arrays.asList(new String[] {
        "Trees","Runs","Tasks","Task Messages"
    });

    /**
     *  The keys for values that will be pulled out of the query of the Runs structures
     *  (Runs/Tasks/Task Messages) before passing along to the Task Server.
     */
    public static final List<String> RUNS_PATH_COMPONENTS = Arrays.asList(new String[] {
        "source","runId","taskId","messageId"
    });

    /**
     *  The keys for values that will be pulled out of the query of the Trees structure
     *  before passing along to the Task Server (currently nothing should be pulled out so
     *  we have an empty array list).
     */
    public static final List<String> TREES_PATH_COMPONENTS = new ArrayList();

    /*---------------------------------------------------------------------------------------------
     * SETUP METHODS
     *-------------------------------------------------------------------------------------------*/
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

    @Override
    public void initialize() throws BridgeError {
        this.taskUrl = properties.getValue(Properties.TASK_URL);
    }

    /*---------------------------------------------------------------------------------------------
     * IMPLEMENTATION METHODS
     *-------------------------------------------------------------------------------------------*/

    @Override
    public Count count(BridgeRequest request) throws BridgeError {
        if (!VALID_STRUCTURES.contains(request.getStructure()))   throw new BridgeError("Invalid Structure: '" + request.getStructure() + "' is not a valid structure");

        request.setQuery(substituteQueryParameters(request));
        // Add the include statement to the query if the structure is Tasks or Task Messages
        if (request.getStructure().equals("Tasks")) {
            request.setQuery(request.getQuery()+"&include=tasks");
        } else if (request.getStructure().equals("Task Messages")) {
            request.setQuery(request.getQuery()+"&include=tasks.messages");
        }

        Map<String,String> query;
        if (request.getStructure().equals("Trees")) {
            query = separatePathComponentsAndEncodeQuery(request.getQuery(),TREES_PATH_COMPONENTS);
        } else {
            query = separatePathComponentsAndEncodeQuery(request.getQuery(),RUNS_PATH_COMPONENTS);
            String source = query.get("source");
            // Throw an error if any validation issues are found
            if (source == null)  {
                throw new BridgeError("A Task Source needs to be provided in the query in the form of 'source=YOUR_SOURCE'");
            }
            if (!request.getStructure().equals("Runs") && query.get("runId") == null) {
                throw new BridgeError("A Run Id needs to be provided in the query in the form of 'runId=RUN_ID'");
            }
            if (request.getStructure().equals("Task Messages") && query.get("taskId") == null) {
                throw new BridgeError("A Task Id needs to be provided in the query in the form of 'taskId=TASK_ID'");
            }
        }

        HttpClient client = HttpClients.createDefault();
        String url = request.getStructure().equals("Trees") ? buildTreesUrl(this.taskUrl,query.get("query"),1,0) : buildRunsUrl(this.taskUrl,query.get("source"),query.get("runId"),query.get("query"),1,0);
        HttpGet get = new HttpGet(url);

        String output;
        int statusCode;
        try {
            HttpResponse response = client.execute(get);
            HttpEntity entity = response.getEntity();
            output = EntityUtils.toString(entity);
            statusCode = response.getStatusLine().getStatusCode();
        } catch (IOException e) {
            throw new BridgeError("Unable to make a connection to the Kinetic Task instance",e);
        }

        Integer count = 0;
        if (statusCode == 200) {
            JSONObject json = (JSONObject)JSONValue.parse(output);
            // Generate the count for the Trees or Runs structure
            if (request.getStructure().equals("Runs") || request.getStructure().equals("Trees")) {
                count = query.get("runId") != null ? 1 : Integer.valueOf(json.get("count").toString());
            }
            // Generate the count for the Tasks structure
            else if (request.getStructure().equals("Tasks")) {
                JSONObject run = (JSONObject)json.get("run");
                JSONArray tasks = (JSONArray)run.get("tasks");
                count = tasks.size();
            }
            // Generate the count for the Task Messages structure
            else if (request.getStructure().equals("Task Messages")) {
                JSONObject run = (JSONObject)json.get("run");
                JSONArray tasks = (JSONArray)run.get("tasks");
                for (Object taskGeneric : tasks) {
                    JSONObject task = (JSONObject)taskGeneric;
                    if (task.get("id").toString().equals(query.get("taskId"))) {
                        JSONArray messages = (JSONArray)task.get("messages");
                        count = messages.size();
                        break;
                    }
                }
            }
        } else if (statusCode == 403) {
            throw new BridgeError(String.format("403 (Forbidden): Check the API Access rules on the '%s' Task Instance.",this.taskUrl));
        } else if (statusCode == 404) {
            if (request.getStructure().equals("Trees")) {
                throw new BridgeError(String.format("404 (Not Found): Check that '%s' is an existing and running Task Instance",this.taskUrl));
            } else if (request.getStructure().equals("Runs") && query.get("runId") == null) {
                throw new BridgeError(String.format("404 (Not Found): Check that '%s' is a valid source on the '%s' Task Instance.",query.get("source"),this.taskUrl));
            } else {
                throw new BridgeError(String.format("404 (Not Found): Check that '%s' is a valid source and '%s' is an existing run id on the '%s' Task Instance.",query.get("source"),query.get("runId"),this.taskUrl));
            }
        } else {
            logger.error("Kinetic Task Error Response");
            logger.error(output);
            throw new BridgeError(String.format("%s: There was an error encountered when attempting to retrieve data. See the full response from Kinetic Task in the Bridgehub logs.Original Error: %s",statusCode,output));
        }

        return new Count(count);
    }

    @Override
    public Record retrieve(BridgeRequest request) throws BridgeError {
        if (!VALID_STRUCTURES.contains(request.getStructure()))   throw new BridgeError("Invalid Structure: '" + request.getStructure() + "' is not a valid structure");

        request.setQuery(substituteQueryParameters(request));
        // Add the include statement to the query if the structure is Tasks or Task Messages
        if (request.getStructure().equals("Tasks")) {
            request.setQuery(request.getQuery()+"&include=tasks");
        } else if (request.getStructure().equals("Task Messages")) {
            request.setQuery(request.getQuery()+"&include=tasks.messages");
        }

        Map<String,String> query;
        if (request.getStructure().equals("Trees")) {
            query = separatePathComponentsAndEncodeQuery(request.getQuery(),TREES_PATH_COMPONENTS);
        } else {
            // Throw an error if any validation issues are found
            query = separatePathComponentsAndEncodeQuery(request.getQuery(),RUNS_PATH_COMPONENTS);
            if (query.get("source") == null)  {
                throw new BridgeError("A Task Source needs to be provided in the query in the form of 'source=YOUR_SOURCE'");
            }
            if (query.get("runId") == null) {
                throw new BridgeError("A Run Id needs to be provided in the query in the form of 'runId=RUN_ID'");
            }
            if (!request.getStructure().equals("Runs") && query.get("taskId") == null) {
                throw new BridgeError("A Task Id needs to be provided in the query in the form of 'taskId=TASK_ID'");
            }
            if (request.getStructure().equals("Task Messages") && query.get("messageId") == null) {
                throw new BridgeError("A Message Id needsto be provided in the query in the form of 'messageId=MESSAGE_ID'");
            }
        }

        HttpClient client = HttpClients.createDefault();
        String url = request.getStructure().equals("Trees") ? buildTreesUrl(this.taskUrl,query.get("query"),2,0) : buildRunsUrl(this.taskUrl,query.get("source"),query.get("runId"),query.get("query"),null,null);
        HttpGet get = new HttpGet(url);

        String output;
        int statusCode;
        try {
            HttpResponse response = client.execute(get);
            HttpEntity entity = response.getEntity();
            output = EntityUtils.toString(entity);
            statusCode = response.getStatusLine().getStatusCode();
        } catch (IOException e) {
            throw new BridgeError("Unable to make a connection to the Kinetic Task instance",e);
        }

        Map<String,Object> result = new LinkedHashMap<String,Object>();
        if (statusCode == 200) {
            JSONObject json = (JSONObject)JSONValue.parse(output);
            // Generate the record for the Runs structure
            if (request.getStructure().equals("Trees")) {
                JSONArray trees = (JSONArray)json.get("trees");
                if (trees.size() > 0) {
                    JSONObject tree = (JSONObject)trees.get(0);
                    if (request.getFields() == null || request.getFields().isEmpty()) {
                        result = tree;
                    } else {
                        for (String field : request.getFields()) {
                            result.put(field,tree.get(field));
                        }
                    }
                } else if (trees.size() > 1) {
                    // Throw an error if more than one result was returned
                    throw new BridgeError("Multiple results matched an expected single match query");
                }
            // Generate the record for the Runs structure
            } else if (request.getStructure().equals("Runs")) {
                JSONObject run = (JSONObject)json.get("run");
                if (request.getFields() == null || request.getFields().isEmpty()) {
                    result = run;
                } else {
                    for (String field : request.getFields()) {
                        result.put(field,run.get(field));
                    }
                }
            }
            // Generate the record for the Tasks structure
            else if (request.getStructure().equals("Tasks")) {
                JSONObject run = (JSONObject)json.get("run");
                JSONArray tasks = (JSONArray)run.get("tasks");
                for (Object taskGeneric : tasks) {
                    JSONObject task = (JSONObject)taskGeneric;
                    if (task.get("id").toString().equals(query.get("taskId"))) {
                        if (request.getFields() == null || request.getFields().isEmpty()) {
                            result = task;
                        } else {
                            for (String field : request.getFields()) {
                                result.put(field,task.get(field));
                            }
                        }
                        break;
                    }
                }
            }
            // Generate the record for the Task Messages structure
            else if (request.getStructure().equals("Task Messages")) {
                JSONObject run = (JSONObject)json.get("run");
                JSONArray tasks = (JSONArray)run.get("tasks");
                for (Object taskGeneric : tasks) {
                    JSONObject task = (JSONObject)taskGeneric;
                    if (task.get("id").toString().equals(query.get("taskId"))) {
                        JSONArray messages = (JSONArray)task.get("messages");
                        for (Object messageGeneric : messages) {
                            JSONObject message = (JSONObject)messageGeneric;
                            if (query.get("messageId").equals(message.get("id").toString())) {
                                if (request.getFields() == null || request.getFields().isEmpty()) {
                                    result = message;
                                } else {
                                    for (String field : request.getFields()) {
                                        result.put(field,message.get(field));
                                    }
                                }
                                break;
                            }
                        }
                        break;
                    }
                }
            }
        } else if (statusCode == 403) {
            throw new BridgeError(String.format("403 (Forbidden): Check the API Access rules on the '%s' Task Instance.",this.taskUrl));
        } else if (statusCode == 404) {
            if (request.getStructure().equals("Trees")) {
                throw new BridgeError(String.format("404 (Not Found): Check that '%s' is an existing and running Task Instance",this.taskUrl));
            } else if (request.getStructure().equals("Runs") && query.get("runId") == null) {
                throw new BridgeError(String.format("404 (Not Found): Check that '%s' is a valid source on the '%s' Task Instance.",query.get("source"),this.taskUrl));
            } else {
                throw new BridgeError(String.format("404 (Not Found): Check that '%s' is a valid source and '%s' is an existing run id on the '%s' Task Instance.",query.get("source"),query.get("runId"),this.taskUrl));
            }
        } else {
            logger.error("Kinetic Task Error Response");
            logger.error(output);
            throw new BridgeError(String.format("%s: There was an error encountered when attempting to retrieve data. See the full response from Kinetic Task in the Bridgehub logs. Original Error: %s",statusCode,output));
        }

        if (result.isEmpty()) {
            result = null;
        } else {
            for (String key : result.keySet()) {
                result.put(key, toString(result.get(key)));
            }
        }

        return new Record(result);
    }

    @Override
    public RecordList search(BridgeRequest request) throws BridgeError {
        if (!VALID_STRUCTURES.contains(request.getStructure()))   throw new BridgeError("Invalid Structure: '" + request.getStructure() + "' is not a valid structure");

        request.setQuery(substituteQueryParameters(request));
        // Add the include statement to the query if the structure is Tasks or Task Messages
        if (request.getStructure().equals("Tasks")) {
            request.setQuery(request.getQuery()+"&include=tasks");
        } else if (request.getStructure().equals("Task Messages")) {
            request.setQuery(request.getQuery()+"&include=tasks.messages");
        }

        Map<String,String> query;
        if (request.getStructure().equals("Trees")) {
            query = separatePathComponentsAndEncodeQuery(request.getQuery(),TREES_PATH_COMPONENTS);
        } else {
            // Throw an error if any validation issues are found
            query = separatePathComponentsAndEncodeQuery(request.getQuery(),RUNS_PATH_COMPONENTS);
            if (query.get("source") == null)  {
                throw new BridgeError("A Task Source needs to be provided in the query in the form of 'source=YOUR_SOURCE'");
            }
            if (!request.getStructure().equals("Runs") && query.get("runId") == null) {
                throw new BridgeError("A Run Id needs to be provided in the query in the form of 'runId=RUN_ID'");
            }
            if (request.getStructure().equals("Task Messages") && query.get("taskId") == null) {
                throw new BridgeError("A Task Id needs to be provided in the query in the form of 'taskId=TASK_ID'");
            }
        }

        HttpClient client = HttpClients.createDefault();
        String url = request.getStructure().equals("Trees") ? buildTreesUrl(this.taskUrl,query.get("query"),null,null) : buildRunsUrl(this.taskUrl,query.get("source"),query.get("runId"),query.get("query"),null,null);
        HttpGet get = new HttpGet(url);

        String output;
        int statusCode;
        try {
            HttpResponse response = client.execute(get);
            HttpEntity entity = response.getEntity();
            output = EntityUtils.toString(entity);
            statusCode = response.getStatusLine().getStatusCode();
        } catch (IOException e) {
            throw new BridgeError("Unable to make a connection to the Kinetic Task instance",e);
        }

        List<Record> records = new ArrayList<Record>();
        if (statusCode == 200) {
            JSONObject json = (JSONObject)JSONValue.parse(output);
            // Generate the record list for the Trees structure
            if (request.getStructure().equals("Trees")) {
                JSONArray trees = (JSONArray)json.get("trees");
                for (Object treeGeneric : trees) {
                    JSONObject tree = (JSONObject)treeGeneric;
                    if (request.getFields() == null || request.getFields().isEmpty()) request.setFields(new ArrayList(tree.keySet()));
                    records.add(new Record(tree));
                }
            // Generate the record list for the Runs structure
            } else if (request.getStructure().equals("Runs")) {
                JSONArray runs = (JSONArray)json.get("runs");
                for (Object runGeneric : runs) {
                    JSONObject run = (JSONObject)runGeneric;
                    if (request.getFields() == null || request.getFields().isEmpty()) request.setFields(new ArrayList(run.keySet()));
                    if (query.get("runId") == null || (query.get("runId") != null && query.get("runId").equals(run.get("id").toString()))) {
                        records.add(new Record(run));
                    }
                }
            }
            // Generate the record list for the Tasks structure
            else if (request.getStructure().equals("Tasks")) {
                JSONObject run = (JSONObject)json.get("run");
                JSONArray tasks = (JSONArray)run.get("tasks");
                for (Object taskGeneric : tasks) {
                    JSONObject task = (JSONObject)taskGeneric;
                    if (request.getFields() == null || request.getFields().isEmpty()) request.setFields(new ArrayList(task.keySet()));
                    if (query.get("taskId") == null || (query.get("taskId") != null && query.get("taskId").equals(task.get("id").toString()))) {
                        records.add(new Record(task));
                    }
                }
            }
            // Generate the record list for the Task Messages structure
            else if (request.getStructure().equals("Task Messages")) {
                JSONObject run = (JSONObject)json.get("run");
                JSONArray tasks = (JSONArray)run.get("tasks");
                for (Object taskGeneric : tasks) {
                    JSONObject task = (JSONObject)taskGeneric;
                    if (task.get("id").toString().equals(query.get("taskId"))) {
                        JSONArray messages = (JSONArray)task.get("messages");
                        for (Object messageGeneric : messages) {
                            JSONObject message = (JSONObject)messageGeneric;
                            if (request.getFields() == null || request.getFields().isEmpty()) request.setFields(new ArrayList(message.keySet()));
                            if (query.get("messageId") == null || (query.get("messageId") != null && query.get("messageId").equals(message.get("id").toString()))) {
                                records.add(new Record(message));
                            }
                        }
                    }
                }
            }
        } else if (statusCode == 403) {
            throw new BridgeError(String.format("403 (Forbidden): Check the API Access rules on the '%s' Task Instance.",this.taskUrl));
        } else if (statusCode == 404) {
            if (request.getStructure().equals("Trees")) {
                throw new BridgeError(String.format("404 (Not Found): Check that '%s' is an existing and running Task Instance",this.taskUrl));
            } else if (request.getStructure().equals("Runs") && query.get("runId") == null) {
                throw new BridgeError(String.format("404 (Not Found): Check that '%s' is a valid source on the '%s' Task Instance.",query.get("source"),this.taskUrl));
            } else {
                throw new BridgeError(String.format("404 (Not Found): Check that '%s' is a valid source and '%s' is an existing run id on the '%s' Task Instance.",query.get("source"),query.get("runId"),this.taskUrl));
            }
        } else {
            logger.error("Kinetic Task Error Response");
            logger.error(output);
            throw new BridgeError(String.format("%s: There was an error encountered when attempting to retrieve data. See the full response from Kinetic Task in the Bridgehub logs. Original Error: %s",statusCode,output));
        }

        // Convert records to <String,String> for the bridge
        for (Record record : records) {
            Map<String,Object> map = record.getRecord();
            for (String key : map.keySet()) {
                map.put(key, toString(map.get(key)));
            }
            record.setRecord(map);
        }

        return new RecordList(request.getFields(),records);
    }

    /*---------------------------------------------------------------------------------------------
     * HELPER METHODS
     *-------------------------------------------------------------------------------------------*/

    private String substituteQueryParameters(BridgeRequest request) throws BridgeError {
        KineticTaskQualificationParser parser = new KineticTaskQualificationParser();
        return parser.parse(request.getQuery(),request.getParameters());
    }

    /* Removes any path components from the url and adds them to the map
       separately from the URL Encoded query. Any string passed in the path
       components list will be removed from the encoded query returned from
       the method (if found).
    */
    private Map<String,String> separatePathComponentsAndEncodeQuery(String query,List<String> pathComponents) {
        Map<String,String> separatedQuery = new HashMap<String,String>();

        String[] indvQueryParts = query.split("&(?=[^&]*?=)");
        List<String> queryPartsList = new ArrayList<String>();
        for (String indvQueryPart : indvQueryParts) {
            String[] str_array = indvQueryPart.split("=");
            String field = str_array[0].trim();
            String value = "";
            if (str_array.length > 1) value = StringUtils.join(Arrays.copyOfRange(str_array, 1, str_array.length),"=").trim();
            if (pathComponents.contains(field)) {
                separatedQuery.put(field,value);
            } else if (field.equals("limit") || field.equals("offset")) {
                // Don't add limit and offset to the query because they will be handled
                // using pagination metadata and we don't want one to overwrite the other
                continue;
            } else if (StringUtils.isNotBlank(field)) {
                queryPartsList.add(URLEncoder.encode(field)+"=" +URLEncoder.encode(value));
            }
        }
        separatedQuery.put("query",StringUtils.join(queryPartsList,"&"));
        return separatedQuery;
    }

    /*
    Takes a base Kinetic Task url (localhost:8080/kinetic-task), a source, run id, and a previously
    escaped query string and builds a url from it based on the inputted information
    */
    private String buildRunsUrl(String taskUrl,String source,String runId,String escapedQuery,Integer limit,Integer offset) throws BridgeError {
        String escapedSource;
        try {
            escapedSource = new URI(null,null,source,null).toString();
        } catch (Exception e) { throw new BridgeError("There was a problem escaping the source '"+source+"'",e); }

        StringBuilder url = new StringBuilder();
        // Create the url path
        url.append(taskUrl);
        url.append("/app/api/v1/sources/");
        url.append(escapedSource);
        url.append("/runs");
        if (StringUtils.isNotBlank(runId)) url.append("/").append(runId);
        // Append on any query parts (including pagination)
        url.append("?");
        if (StringUtils.isNotBlank(escapedQuery)) url.append(escapedQuery);
        if (limit != null && limit != 0) url.append("&limit=").append(String.valueOf(limit));
        if (offset != null && offset != 0) url.append("&offset=").append(String.valueOf(offset));

        return url.toString();
    }

    /*
    Takes a base Kinetic Task url (localhost:8080/kinetic-task) a previously
    escaped query string and builds a url from it based on the inputted information
    */
    private String buildTreesUrl(String taskUrl,String escapedQuery,Integer limit,Integer offset) throws BridgeError {
        StringBuilder url = new StringBuilder();
        // Create the url path
        url.append(taskUrl);
        url.append("/app/api/v1/trees");
        // Append on any query parts (including pagination)
        url.append("?");
        if (StringUtils.isNotBlank(escapedQuery)) url.append(escapedQuery);
        if (limit != null && limit != 0) url.append("&limit=").append(String.valueOf(limit));
        if (offset != null && offset != 0) url.append("&offset=").append(String.valueOf(offset));

        return url.toString();
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
}
