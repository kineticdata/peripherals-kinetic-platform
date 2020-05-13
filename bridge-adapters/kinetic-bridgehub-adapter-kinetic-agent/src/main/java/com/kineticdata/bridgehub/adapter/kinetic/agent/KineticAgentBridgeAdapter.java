package com.kineticdata.bridgehub.adapter.kinetic.agent;

import com.kineticdata.bridgehub.adapter.BridgeAdapter;
import com.kineticdata.bridgehub.adapter.BridgeError;
import com.kineticdata.bridgehub.adapter.BridgeRequest;
import com.kineticdata.bridgehub.adapter.Count;
import com.kineticdata.bridgehub.adapter.Record;
import com.kineticdata.bridgehub.adapter.RecordList;
import com.kineticdata.commons.v1.config.ConfigurableProperty;
import com.kineticdata.commons.v1.config.ConfigurablePropertyMap;
import java.io.IOException;
import java.nio.charset.Charset;
import org.apache.http.HttpEntity;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.apache.commons.codec.binary.Base64;
import org.apache.http.Consts;
import org.apache.http.HttpHeaders;
import org.apache.http.HttpResponse;
import org.apache.http.NameValuePair;
import org.apache.http.client.HttpClient;
import org.apache.http.client.entity.UrlEncodedFormEntity;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.message.BasicNameValuePair;
import org.apache.http.util.EntityUtils;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.JSONValue;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class KineticAgentBridgeAdapter implements BridgeAdapter {
    /*----------------------------------------------------------------------------------------------
     * PROPERTIES
     *--------------------------------------------------------------------------------------------*/

    /** Defines the adapter display name */
    public static final String NAME = "Kinetic Agent Bridge";

    /** Defines the logger */
    protected static final Logger logger = LoggerFactory.getLogger(KineticAgentBridgeAdapter.class);
    
    /** Adapter version constant. */
    public static String VERSION = "";
    /** Load the properties version from the version.properties file. */
    static {
        try {
            java.util.Properties properties = new java.util.Properties();
            properties.load(KineticAgentBridgeAdapter.class.getResourceAsStream("/"+KineticAgentBridgeAdapter.class.getName()+".version"));
            VERSION = properties.getProperty("version");
        } catch (IOException e) {
            logger.warn("Unable to load "+KineticAgentBridgeAdapter.class.getName()+" version properties.", e);
            VERSION = "Unknown";
        }
    }

    /** Defines the collection of property names for the adapter */
    public static class Properties {
        public static final String PROPERTY_AGENT_URL = "Agent Url";
        public static final String PROPERTY_USERNAME = "Username";
        public static final String PROPERTY_PASSWORD = "Password";
        public static final String PROPERTY_SPACE = "Space";
        public static final String PROPERTY_SLUG = "Slug";

    }

    private final ConfigurablePropertyMap properties = new ConfigurablePropertyMap(
        new ConfigurableProperty(Properties.PROPERTY_USERNAME).setIsRequired(true),
        new ConfigurableProperty(Properties.PROPERTY_PASSWORD).setIsRequired(true).setIsSensitive(true),
        new ConfigurableProperty(Properties.PROPERTY_AGENT_URL).setIsRequired(true)
            .setDescription("The scheme://hostname:port of the Agent Server"),
        new ConfigurableProperty(Properties.PROPERTY_SPACE).setIsRequired(true)
            .setDescription("The configured space slug"),
        new ConfigurableProperty(Properties.PROPERTY_SLUG).setIsRequired(true)
            .setDescription("The configured adapter slug")
    );

    // Local variables to store the property values in
    private String agentUrl;
    private String username;
    private String password;
    private String space;
    private String slug;

    /*---------------------------------------------------------------------------------------------
     * SETUP METHODS
     *-------------------------------------------------------------------------------------------*/

    @Override
    public void initialize() throws BridgeError {
        // Initializing the variables with the property values that were passed
        // when creating the bridge so that they are easier to use
        agentUrl = properties.getValue(Properties.PROPERTY_AGENT_URL);
        username = properties.getValue(Properties.PROPERTY_USERNAME);
        password = properties.getValue(Properties.PROPERTY_PASSWORD);
        space = properties.getValue(Properties.PROPERTY_SPACE);
        slug = properties.getValue(Properties.PROPERTY_SLUG);
    }

    @Override
    public String getName() {
        return NAME;
    }

    @Override
    public String getVersion() {
       return VERSION;
    }

    @Override
    public void setProperties(Map<String,String> parameters) {
        // This should always be the same unless there are special circumstances
        // for changing it
        properties.setValues(parameters);
    }

    @Override
    public ConfigurablePropertyMap getProperties() {
        // This should always be the same unless there are special circumstances
        // for changing it
        return properties;
    }

    /*---------------------------------------------------------------------------------------------
     * IMPLEMENTATION METHODS
     *-------------------------------------------------------------------------------------------*/

    @Override
    public Count count(BridgeRequest request) throws BridgeError {
        // Log the access
        logger.trace("Counting records");
        logger.trace("  Structure: " + request.getStructure());
        logger.trace("  Query: " + request.getQuery());

        String output = callKineticAgent(request, "count");
        logger.trace("Count Output: "+output);
        
        Long count = null; 
        try {
            // Parse the response string into a JSONObject
            JSONObject object = (JSONObject)JSONValue.parse(output);
        
            JSONObject data = (JSONObject)object.get("data");
            
            // Get domain specific data.
            count = (Long)data.get("count");
        } catch (Exception e) {
            throw new BridgeError("An unexpected error has occured: " + e.getMessage(), e);
        }
        
        // Create and return a count object that contains the count
        return new Count(count);
    }

    @Override
    public Record retrieve(BridgeRequest request) throws BridgeError {        
        // Log the access
        logger.trace("Retrieving Kinetic Request CE Record");
        logger.trace("  Structure: " + request.getStructure());
        logger.trace("  Query: " + request.getQuery());
        logger.trace("  Fields: " + request.getFieldString());
        
        String output = callKineticAgent(request, "retrieve");
        
        JSONObject record; 
        try {
            // Parse the response string into a JSONObject
            JSONObject object = (JSONObject)JSONValue.parse(output);
        
            JSONObject data = (JSONObject)object.get("data");
            record = (JSONObject)data.get("record");
        } catch (Exception e) {
            throw new BridgeError("An unexpected error has occured: "+e.getMessage(), e);
        }

        // Return the created Record object
        return new Record(record);
    }

    @Override
    public RecordList search(BridgeRequest request) throws BridgeError {        
        // Log the access
        logger.trace("Searching Records");
        logger.trace("  Structure: " + request.getStructure());
        logger.trace("  Query: " + request.getQuery());
        logger.trace("  Fields: " + request.getFieldString());
        
        String output = callKineticAgent(request, "search");
        
        JSONObject metadata;
        JSONArray fields, records; 
        try {
            // Parse the response string into a JSONObject
            JSONObject object = (JSONObject)JSONValue.parse(output);
        
            JSONObject data = (JSONObject)object.get("data");
            metadata = (JSONObject)data.get("metadata");
            fields = (JSONArray)data.get("fields");
            records = (JSONArray)data.get("records");
        } catch (Exception e) {
            throw new BridgeError("An unexpected error has occured: "+e.getMessage(), e);
        }
        
        // Convert JSON to requirements for RecordList class.
        List fieldsList = new ArrayList<>();
        if (fields != null) {
            for (int i=0; i<fields.size(); i++){ 
                fieldsList.add(fields.get(i));
            } 
        } 
        List<Record> recordList = new ArrayList<>();
        records.forEach(jsonRecord -> {
            Map recordMap = new HashMap<>();
            JSONArray recordArray = (JSONArray)jsonRecord;
            for (int i = 0; i < recordArray.size(); i++) {
                recordMap.put(fields.get(i), recordArray.get(i));
            }
            recordList.add(new Record(recordMap));
        });
        Map<String, String> metadataMap = new HashMap<>();
        Set<String> keys = metadata.keySet();
        for(String key : keys) {
            metadataMap.put(key, String.valueOf(metadata.get(key)));
        }

        return new RecordList(fieldsList, recordList,  metadataMap);
    }

    /*----------------------------------------------------------------------------------------------
     * HELPER METHODS
     *--------------------------------------------------------------------------------------------*/
    
    private String callKineticAgent(BridgeRequest request, String operation) throws BridgeError {
        String url = agentUrl + "/" + space + "/app/api/v1/bridges/" + slug + "/" + operation;
        
        logger.debug("Calling agent at: " + url);
        
        // Declare the output string
        String output;
        // Initialize the HTTP Client, Response, and Get objects
        try (
            CloseableHttpClient client = HttpClients.createDefault()
        ) {
            HttpResponse response;
            HttpPost httpPost = new HttpPost(url);

            // Create entity with username and pass for use in the Post.
            String auth = username + ":" + password;
            byte[] encodedAuth = Base64.encodeBase64(auth.getBytes(Charset.forName("US-ASCII")));
            String authHeader = "Basic " + new String(encodedAuth); 
            httpPost.setHeader(HttpHeaders.AUTHORIZATION, authHeader);;
            httpPost.setHeader("Content-Type", "application/x-www-form-urlencoded");

            Map<String, String> parameters = request.getParameters();
            Map<String, String> metaData = request.getMetadata();

            List<NameValuePair> form = new ArrayList<>();
            form.add(new BasicNameValuePair("structure", request.getStructure()));
            form.add(new BasicNameValuePair("query", request.getQuery()));
            form.add(new BasicNameValuePair("fields", request.getFieldString()));
            if (parameters != null) {
                parameters.keySet().stream().forEach(key -> {
                    form.add(new BasicNameValuePair("parameter["+key+"]",
                        parameters.get(key)));
                });
            }
            if (metaData != null) {
                metaData.keySet().stream().forEach(key -> {
                    form.add(new BasicNameValuePair("metadata["+key+"]", 
                         metaData.get(key)));
                });
            }

            UrlEncodedFormEntity preEntity = new UrlEncodedFormEntity(form, Consts.UTF_8);
            httpPost.setEntity(preEntity);

            // Make the call to the REST source to retrieve data and convert the 
            // response from an HttpEntity object into a Java string so more response
            // parsing can be done.
            response = client.execute(httpPost);
            HttpEntity entity = response.getEntity();
            output = EntityUtils.toString(entity);
        } catch (IOException e) {
            throw new BridgeError("Unable to make a connection to the REST Service", e);
        }
        
        return output;
    }
}
