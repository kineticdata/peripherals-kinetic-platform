package com.kineticdata.bridgehub.adapter.kinetictasksync;

import com.kineticdata.bridgehub.adapter.BridgeAdapter;
import com.kineticdata.bridgehub.adapter.BridgeError;
import com.kineticdata.bridgehub.adapter.BridgeRequest;
import com.kineticdata.bridgehub.adapter.Count;
import com.kineticdata.bridgehub.adapter.Record;
import com.kineticdata.bridgehub.adapter.RecordList;
import com.kineticdata.commons.v1.config.ConfigurableProperty;
import com.kineticdata.commons.v1.config.ConfigurablePropertyMap;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.UnsupportedEncodingException;
import java.net.URLEncoder;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.logging.Level;
import java.util.logging.Logger;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.util.EntityUtils;
import org.apache.commons.codec.binary.Base64;
import org.apache.commons.lang.StringUtils;
import org.apache.http.client.methods.HttpDelete;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.entity.StringEntity;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.JSONValue;
import org.json.simple.parser.JSONParser;
import org.json.simple.parser.ParseException;
import org.slf4j.LoggerFactory;

public class KineticTaskSyncAdapter implements BridgeAdapter {
    /*----------------------------------------------------------------------------------------------
     * PROPERTIES
     *--------------------------------------------------------------------------------------------*/

    /** Defines the adapter display name */
    public static final String NAME = "Kinetic Task Sync Bridge";

    /** Defines the logger */
    protected static final org.slf4j.Logger logger = 
        LoggerFactory.getLogger(KineticTaskSyncAdapter.class);

    /** Adapter version constant. */
    public static String VERSION = "1.0.0";
    
    private static final int DEFAULT_TIME_OUT = 5; // in sec
    private static final String SYNC_FORM = "kinetic-task-sync-log";
    private static final String STATUS_COMPLETE = "Complete";
    private static final String STATUS_NOT_FOUND = "Not Found";
    private static final String STATUS_FAILED = "Failed";
                    
    private String taskApiUsername;
    private String taskApiPassword;
    private String taskApiWebServer;
    private String coreApiUsername;
    private String coreApiPassword;
    private String coreApiWebServer;
    private String setTimeOut;
    private int timeOut;

    /** Defines the collection of property names for the adapter */
    public static class Properties {
        public static final String TASK_API_USERNAME = "Task API Username";
        public static final String TASK_API_PASSWORD = "Task API Password";
        public static final String TASK_API_WEB_SERVER = "Task API Web Server";
        public static final String CORE_API_USERNAME = "Core API Username";
        public static final String CORE_API_PASSWORD = "Core API Password";
        public static final String CORE_API_WEB_SERVER = "Core API Web Server";
        public static final String SET_TIME_OUT = "Time Out Limit";
    }

    private final ConfigurablePropertyMap properties = new ConfigurablePropertyMap(
        new ConfigurableProperty(Properties.TASK_API_USERNAME).setIsRequired(true),
        new ConfigurableProperty(Properties.TASK_API_PASSWORD).setIsRequired(true)
            .setIsSensitive(true),
        new ConfigurableProperty(Properties.TASK_API_WEB_SERVER).setIsRequired(true),
        new ConfigurableProperty(Properties.CORE_API_USERNAME).setIsRequired(true),
        new ConfigurableProperty(Properties.CORE_API_PASSWORD).setIsRequired(true)
            .setIsSensitive(true),
        new ConfigurableProperty(Properties.CORE_API_WEB_SERVER).setIsRequired(true),
        new ConfigurableProperty(Properties.SET_TIME_OUT)
            .setDescription("Set max time out in second. Default to 5 sec")
    );

    /**
     * Structures that are valid to use in the bridge
     */
    public static final List<String> VALID_STRUCTURES = Arrays.asList(new String[] {
        SYNC_FORM
    });

    /*---------------------------------------------------------------------------------------------
     * SETUP METHODS
     *-------------------------------------------------------------------------------------------*/

    @Override
    public void initialize() throws BridgeError {
        this.taskApiUsername = properties.getValue(Properties.TASK_API_USERNAME);
        this.taskApiPassword = properties.getValue(Properties.TASK_API_PASSWORD);
        this.taskApiWebServer = properties.getValue(Properties.TASK_API_WEB_SERVER);
        this.coreApiUsername = properties.getValue(Properties.CORE_API_USERNAME);
        this.coreApiPassword = properties.getValue(Properties.CORE_API_PASSWORD);
        this.coreApiWebServer = properties.getValue(Properties.CORE_API_WEB_SERVER);
        this.setTimeOut = properties.getValue(Properties.SET_TIME_OUT);
        // check if config space has kinetic-task-sync-log datastore form
        if (!retrieveForm()) {
            createForm();
        }
                
        // Calculate the forced termination time
        Integer timeOut = 0;
        if (this.setTimeOut != null && !this.setTimeOut.isEmpty()) {
            try {
                timeOut = Integer.parseInt(this.setTimeOut);
            } catch (NumberFormatException e) {
                throw new RuntimeException("The timeout was set to a non integer value.");
            }
        }
        
        this.timeOut = timeOut < 0 ? DEFAULT_TIME_OUT : (int)timeOut;
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
        properties.setValues(parameters);
    }

    @Override
    public ConfigurablePropertyMap getProperties() {
        return properties;
    }

    /*---------------------------------------------------------------------------------------------
     * IMPLEMENTATION METHODS
     *-------------------------------------------------------------------------------------------*/

    @Override
    public Count count(BridgeRequest request) throws BridgeError {
        logger.debug("count method attempted with the Kinetic Task Sync adapter."
            + " This functionality is not supported");
        throw new BridgeError("The count method is not supported");
    }

    @Override
    public Record retrieve(BridgeRequest request) throws BridgeError {
        // Parse the query and exchange out any parameters with their parameter 
        // values. ie. change the query username=<%=parameter["Username"]%> to
        // username=test.user where parameter["Username"]=test.user
        KineticTaskSyncQualificationParser parser 
            = new KineticTaskSyncQualificationParser();
        Map<String,ArrayList<String>> query = parser.parseQuery(
            parser.parse(request.getQuery(), request.getParameters()));
           
        // Check if the inputted structure is valid. If it isn't, throw a BridgeError.
        if (!VALID_STRUCTURES.contains(request.getStructure())) {
            throw new BridgeError("Invalid Structure: '" + request.getStructure() 
                + "' is not a valid structure");
        }
        
        // Generate Callback ID Or use Provided callbackId query.
        String callbackId = (query.get("callbackId") == null) 
            ? UUID.randomUUID().toString() : query.get("callbackId").get(0);
        logger.debug("CallBack UUID " + callbackId);

         // Execute the call
        JSONObject record = new JSONObject();
        try {
            // If there is not a callbackId parameter (indicating this is the first call
            // and a run should be started)
            if (query.get("callbackId") == null) {
                // Attempt to POST to Task to start the run
                postTask(query, callbackId);
            }

            // Poll for a result
            JSONObject submission = poll(callbackId);
            // If a result was not found
            if (submission == null) {
                record.put("results", "");
                record.put("status", STATUS_NOT_FOUND);
                record.put("callbackId", callbackId);
                record.put("error", "");
            }
            // If a result was found
            else {
                // Delete the corresponding submission
                deleteRecord((String)submission.get("id"));
                
                record.put("results", (String)((JSONObject)submission.get("values"))
                    .get("Results"));
                record.put("status", STATUS_COMPLETE);
                record.put("callbackId", "");
                record.put("error", "");
            }
        } catch (Exception e) {
            logger.error("Unexpected exception encountered.", e);
            record.put("results", "");
            record.put("status", STATUS_FAILED);
            record.put("callbackId", "");
            record.put("error", e.getMessage());
        }
        
        // Create and return a Record object.
        return new Record(record);
    }

    @Override
    public RecordList search(BridgeRequest request) throws BridgeError {
        logger.debug("search method attempted with the Kinetic Task Sync adapter."
            + " This functionality is not supported");
        throw new BridgeError("The search method is not supported");
    }

    /*----------------------------------------------------------------------------------------------
     * PRIVATE HELPER METHODS
     *--------------------------------------------------------------------------------------------*/
    private JSONObject poll( String callbackId ) throws BridgeError, Exception {
        // Loop Waiting for Datastore Record
        JSONObject results = null;
        Long terminationTime = System.currentTimeMillis() + (this.timeOut * 1000);
        
        while (results == null && System.currentTimeMillis() < terminationTime) {
            // Sleep
            try {
                Thread.sleep(100); // Sleep for 100 milliseconds
            } catch (InterruptedException e) {
                throw new RuntimeException("Interrupted while sleeping.");
            }
            // Check for the result
            results = retrieveSubmission(callbackId);
        }
        
        return results;
    }
    
    private boolean retrieveForm() throws BridgeError {
        boolean formFound = false;
        
        // Build form lookup url.
        String url = this.coreApiWebServer + "/app/api/v1/datastore/forms/"
            + SYNC_FORM;
        
        // Initialize the HTTP Client, Response, and Get objects.
        HttpClient client = HttpClients.createDefault();
        HttpResponse response;
        HttpGet httpGet = new HttpGet(url);
        httpGet.setHeader("Accept", "application/json");
        httpGet.setHeader("Content-type", "application/json");
        
        // Append the authentication to the call. This example uses Basic 
        // Authentication but other  types can be added as HTTP GET or POST 
        // headers as well.
        httpGet = addBasicAuthenticationHeader(httpGet, this.coreApiUsername,
            this.coreApiPassword);

        // Make the call to the REST source to retrieve data and convert the 
        // response from an HttpEntity object into a Java string so more 
        // response parsing can be done.
        String output = "";
        try {
            response = client.execute(httpGet);
            HttpEntity entity = response.getEntity();
            output = EntityUtils.toString(entity);
            logger.trace("Request response code: "
                + response.getStatusLine().getStatusCode());
        } catch (IOException e) {
            logger.error(e.getMessage());
            throw new BridgeError("Unable to make a connection to the REST Service");
        }
        logger.trace("DataStore Lookup - Raw Output: "+output);
        
        int statusCode = response.getStatusLine().getStatusCode();
        if (statusCode == 200) {
            formFound = true;
        } else {
            logger.error("Received an HTTP " + statusCode + " response "
                + "when retrieving " + SYNC_FORM + "form: " + output);
        }
        
        return formFound;
    }
    
    private void createForm() throws BridgeError {
        
        InputStream formContentStream = KineticTaskSyncAdapter.class
            .getResourceAsStream("/META-INF/adapters/kinetic-task-sync-log.json");
        
        logger.debug("The input stream is: ", formContentStream);
        
        JSONObject formDefinition;
        try {
            JSONParser jsonParser = new JSONParser();
            formDefinition = (JSONObject)jsonParser.parse(
                new InputStreamReader(formContentStream, "UTF-8"));
        } catch (Exception e) {
            logger.error(e.getMessage());
            throw new BridgeError("There was a problem reading the form definition"
                + "In the Kinetic Task Sync adapter");            
        }
        
        // Build up the url that you will use to retrieve the source data. Use
        // the query variable instead of request.getQuery() to get a query 
        // without parameter placeholders.
        String url = this.coreApiWebServer + "/app/api/v1/datastore/forms";

        // Initialize the HTTP Client, Response, and Get objects.
        HttpClient client = HttpClients.createDefault();
        HttpResponse response;
        HttpPost httpPost = new HttpPost(url);

        StringEntity payload;
        try {
            payload = new StringEntity(formDefinition.toJSONString());
            httpPost.setEntity(payload);
            httpPost.setHeader("Accept", "application/json");
            httpPost.setHeader("Content-type", "application/json");
        } catch (UnsupportedEncodingException e) {
            logger.error(e.toString());
            throw new BridgeError("Unsupported Encoding In data payload.");
        }

        // Append the authentication to the call. This example uses Basic 
        // Authentication but other types can be added as HTTP GET or POST 
        // headers as well.
        httpPost = addBasicAuthenticationHeader(httpPost, this.coreApiUsername,
            this.coreApiPassword);

        // Make the call to the REST source to retrieve data and convert the 
        // response from an HttpEntity object into a Java string so more response
        // parsing can be done.
        String output = "";
        try {
            response = client.execute(httpPost);
            HttpEntity entity = response.getEntity();
            output = EntityUtils.toString(entity);
            logger.trace("Request response code: "+response.getStatusLine()
                .getStatusCode());
        } catch (IOException e) {
            logger.error(e.getMessage());
            throw new BridgeError("Unable to make a connection to the REST"
                + " Service");
        }
        logger.trace("Tree Start Return - Raw Output: "+output);
        
        int statusCode = response.getStatusLine().getStatusCode();
        if (statusCode != 200) {
            throw new BridgeError("Received an HTTP " + statusCode + " response "
                + "when trying to create the " + SYNC_FORM + "form: " + output); 
        }
                
        // Parse the Response String into a JSON Object
        JSONObject json = (JSONObject)JSONValue.parse(output);
    }
    
    private boolean deleteRecord(String submissionId) throws BridgeError, Exception {
        boolean deleted = false;
    
        String url = this.coreApiWebServer + "/app/api/v1/datastore/submissions/"
        + submissionId;

        // Initialize the HTTP Client, Response, and Get objects.
        HttpClient client = HttpClients.createDefault();
        HttpResponse response = null;
        HttpDelete httpDelete = new HttpDelete(url);

        // Append the authentication to the call. This example uses Basic 
        // Authentication but other  types can be added as HTTP GET or POST 
        // headers as well.
        httpDelete = addBasicAuthenticationHeader(httpDelete, this.coreApiUsername,
            this.coreApiPassword);

        // Make the call to the REST source to retrieve data and convert the 
        // response from an HttpEntity object into a Java string so more 
        // response parsing can be done.
        String output = "";
        try {
            response = client.execute(httpDelete);
            HttpEntity entity = response.getEntity();
            output = EntityUtils.toString(entity);
            logger.trace("Request response code: "
                + response.getStatusLine().getStatusCode());
        } catch (IOException e) {
            logger.error("Unable to cleanup datastore record with submission id "
                + "of \"{}\"", submissionId, e);
        }
        logger.trace("DataStore Delete - Raw Output: "+output);

        int statusCode = response.getStatusLine().getStatusCode();
        if (statusCode != 200) {
            deleted = true;
        } else {
            logger.error("Received an HTTP " + statusCode + " response when "
                + "attempting to delete datastore record with submission id "
                + "of \"{}\": \"{}\"", submissionId, output);
        }
        
        return deleted;
    }
    
    private JSONObject retrieveSubmission(String callbackId) throws BridgeError,
        Exception {
        
        // Build up the url that you will use to retrieve the source data.
        String url = escapeQuery(this.coreApiWebServer 
            + "/app/api/v1/datastore/forms/"+ SYNC_FORM +"/submissions"
            + "?include=details,values&direction=ASC&limit=25"
            + "&index=values[Callback Id]&q=values[Callback Id]=\"" 
            + callbackId +"\"");
                
        // Initialize the HTTP Client, Response, and Get objects.
        HttpClient client = HttpClients.createDefault();
        HttpResponse response;
        HttpGet httpGet = new HttpGet(url);
        httpGet.setHeader("Accept", "application/json");
        httpGet.setHeader("Content-type", "application/json");
        
        // Append the authentication to the call. This example uses Basic 
        // Authentication but other  types can be added as HTTP GET or POST 
        // headers as well.
        httpGet = addBasicAuthenticationHeader(httpGet, this.coreApiUsername,
            this.coreApiPassword);

        // Make the call to the REST source to retrieve data and convert the 
        // response from an HttpEntity object into a Java string so more 
        // response parsing can be done.
        String output = "";
        try {
            response = client.execute(httpGet);
            HttpEntity entity = response.getEntity();
            output = EntityUtils.toString(entity);
            logger.trace("Request response code: "
                + response.getStatusLine().getStatusCode());
        } catch (IOException e) {
            logger.error(e.getMessage());
            throw new BridgeError("Unable to make a connection to the REST Service");
        }
        logger.trace("DataStore Lookup - Raw Output: "+output);
        
        int statusCode = response.getStatusLine().getStatusCode();
        if (statusCode != 200) {
            throw new Exception("Received an HTTP " + statusCode + " response "
                + "when trying to retrieve record with callback Id " 
                + callbackId + " : " + output); 
        }
                
        // Parse the Response String into a JSON Object
        JSONObject json = (JSONObject)JSONValue.parse(output);
        
        // Empty array will guard the submission.size calls.
        JSONArray submissions = json.get("submissions") == null ? new JSONArray() 
            : (JSONArray)json.get("submissions");
        
        JSONObject submission = submissions.size() > 0 
            ? (JSONObject)submissions.get(0) : null;
       
        return submission;
    }
    
    private JSONObject postTask( Map<String, ArrayList<String>> query,
        String callbackId) throws BridgeError, Exception {

        // Build up the url that you will use to retrieve the source data. Use
        // the query variable instead of request.getQuery() to get a query 
        // without parameter placeholders.
        String url;
        try {
             url = this.taskApiWebServer + "/app/api/v1/run-tree"
                + query.get("treeName").get(0);
            query.remove("treeName");
        } catch (Exception e) {
            throw new Exception("The query structure should be "
                + "Source/To/Tree?query or provide a callbackId", e);  
        }
        
        JSONObject queryJson = convertToJson(query);
        queryJson.put("callbackId", callbackId);

        // Initialize the HTTP Client, Response, and Get objects.
        HttpClient client = HttpClients.createDefault();
        HttpResponse response;
        HttpPost httpPost = new HttpPost(url);

        StringEntity payload;
        try {
            payload = new StringEntity(queryJson.toJSONString());
            logger.trace("Task payload: " + payload.toString());
            httpPost.setEntity(payload);
            httpPost.setHeader("Accept", "application/json");
            httpPost.setHeader("Content-type", "application/json");
        } catch (UnsupportedEncodingException e) {
            logger.error(e.toString());
            throw new BridgeError("Unsupported Encoding In data payload.");
        }

        // Append the authentication to the call. This example uses Basic 
        // Authentication but other types can be added as HTTP GET or POST 
        // headers as well.
        httpPost = addBasicAuthenticationHeader(httpPost, this.taskApiUsername,
            this.taskApiPassword);

        // Make the call to the REST source to retrieve data and convert the 
        // response from an HttpEntity object into a Java string so more response
        // parsing can be done.
        String output = "";
        try {
            response = client.execute(httpPost);
            HttpEntity entity = response.getEntity();
            output = EntityUtils.toString(entity);
            logger.trace("Request response code: "+response.getStatusLine()
                .getStatusCode());
        } catch (IOException e) {
            logger.error(e.getMessage());
            throw new BridgeError("Unable to make a connection to the REST"
                + " Service");
        }
        logger.trace("Tree Start Return - Raw Output: "+output);

        int statusCode = response.getStatusLine().getStatusCode();
        if (statusCode != 200) {
            throw new Exception("Received an HTTP " + statusCode + " response "
                + "when trying to retrieve record with callback Id " 
                + callbackId + " : " + output); 
        }
                
        // Parse the Response String into a JSON Object
        JSONObject json = (JSONObject)JSONValue.parse(output);
        
        return json;
    }
    
    private JSONObject convertToJson(Map<String,ArrayList<String>> map) {
        JSONObject json = new JSONObject();
        
        map.forEach((key, value) -> {
            JSONArray jsonArr = new JSONArray();
            value.forEach(val -> jsonArr.add(val));
            json.put(key, jsonArr);
        });
        
        return json; 
    }
    
    private void testAuthenticationValues(String restEndpoint, String username, String password) throws BridgeError {
        logger.debug("Testing the authentication credentials");
        HttpGet get = new HttpGet(String.format("%s/path/to/authentication/check",restEndpoint));
        get = addBasicAuthenticationHeader(get, username, password);

        HttpClient client = HttpClients.createDefault();
        HttpResponse response;
        try {
            response = client.execute(get);
            HttpEntity entity = response.getEntity();
            EntityUtils.consume(entity);
            if (response.getStatusLine().getStatusCode() == 401) {
                throw new BridgeError("Unauthorized: The inputted Username/Password combination is not valid.");
            }
        }
        catch (IOException e) {
            logger.error(e.getMessage());
            throw new BridgeError("Unable to make a connection to properly to the Rest Service.");
        }
    }

    private HttpGet addBasicAuthenticationHeader(HttpGet http, String username,
        String password) {
        
        String creds = username + ":" + password;
        byte[] basicAuthBytes = Base64.encodeBase64(creds.getBytes());
        http.setHeader("Authorization", "Basic " + new String(basicAuthBytes));

        return http;
    }
    
    private HttpPost addBasicAuthenticationHeader(HttpPost http, String username,
        String password) {
        
        String creds = username + ":" + password;
        byte[] basicAuthBytes = Base64.encodeBase64(creds.getBytes());
        http.setHeader("Authorization", "Basic " + new String(basicAuthBytes));

        return http;
    }

    private HttpDelete addBasicAuthenticationHeader(HttpDelete http, String username,
        String password) {
        
        String creds = username + ":" + password;
        byte[] basicAuthBytes = Base64.encodeBase64(creds.getBytes());
        http.setHeader("Authorization", "Basic " + new String(basicAuthBytes));

        return http;
    }

    // Escape query helper method that is used to escape queries that have spaces
    // and other characters that need escaping to form a complete URL
    private String escapeQuery(String query) {
        String[] qSplit = query.split("&");
        for (int i=0;i<qSplit.length;i++) {
            String qPart = qSplit[i];
            String[] keyValuePair = qPart.split("=");
            String key = keyValuePair[0].trim().replaceAll(" ","+");
            String value = keyValuePair.length > 1 ? StringUtils
                .join(Arrays.copyOfRange(keyValuePair, 1, keyValuePair.length), "=") 
                : "";
            qSplit[i] = key+"="+URLEncoder.encode(value);
        }
        return StringUtils.join(qSplit,"&");
    }
}