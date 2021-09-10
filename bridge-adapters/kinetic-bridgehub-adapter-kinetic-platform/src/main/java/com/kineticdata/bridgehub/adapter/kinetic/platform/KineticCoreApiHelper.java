package com.kineticdata.bridgehub.adapter.kinetic.platform;

import com.kineticdata.bridgehub.adapter.BridgeError;
import com.kineticdata.bridgehub.adapter.BridgeRequest;
import java.io.IOException;
import org.apache.commons.codec.binary.Base64;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.util.EntityUtils;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.JSONValue;
import org.slf4j.LoggerFactory;

/**
 * This class is a Rest service helper.
 */
public class KineticCoreApiHelper {
    private final String username;
    private final String password;

    public KineticCoreApiHelper (String username, String password, String space) {
        this.username = username;
        this.password = password;
    }
    
    /** Defines the LOGGER */
    protected static final org.slf4j.Logger LOGGER = 
        LoggerFactory.getLogger(KineticCoreAdapter.class);
    
    public JSONObject executeRequest (BridgeRequest request,
        String url, KineticCoreQualificationParser parser) throws BridgeError{
        
        JSONObject output;        
        // System time used to measure the request/response time
        long start = System.currentTimeMillis();
        
        try (
            CloseableHttpClient client = HttpClients.createDefault()
        ) {
            HttpResponse response;
            HttpGet get = new HttpGet(url);
            
            get = addAuthenticationHeader(get, this.username, this.password);
            response = client.execute(get);
            LOGGER.debug("Recieved response from \"{}\" in {}ms.",
                url,
                System.currentTimeMillis()-start);

            int responseCode = response.getStatusLine().getStatusCode();
            LOGGER.trace("Request response code: " + responseCode);
            
            HttpEntity entity = response.getEntity();
            
            // Confirm that response is a JSON object
            output = parseResponse(EntityUtils.toString(entity));
            
            if (responseCode >= 400) {
                handleFailedReqeust(responseCode);
            } 
        }
        catch (IOException e) {
            throw new BridgeError(
                "Unable to make a connection to the Kinetic Core server.", e);
        }
        
        return output;
    }
    
    protected void testAuth(String url) throws BridgeError {
        LOGGER.debug("Testing the authentication credentials");
        HttpGet get = new HttpGet(url);
        get = addAuthenticationHeader(get, this.username, this.password);

        HttpClient client = HttpClients.createDefault();
        HttpResponse response;
        try {
            response = client.execute(get);
            HttpEntity entity = response.getEntity();
            EntityUtils.consume(entity);
            if (response.getStatusLine().getStatusCode() == 401) {
                throw new BridgeError("Unauthorized: The inputted "
                    + "Username/Password combination is not valid.");
            } else if (response.getStatusLine().getStatusCode() != 200) {
                throw new BridgeError("Connecting to the Kinetic Core instance "
                    + "located at '"+ url +"' failed.");
            }
        }
        catch (IOException e) {
            throw new BridgeError("Unable to make a connection to properly to "
                + "Kinetic Core.", e);
        }
    }
    
    /*--------------------------------------------------------------------------
     * HELPER METHODS
     *------------------------------------------------------------------------*/   
    private HttpGet addAuthenticationHeader(HttpGet get, String username,
        String password) {
        
        String creds = username + ":" + password;
        byte[] basicAuthBytes = Base64.encodeBase64(creds.getBytes());
        get.setHeader("Authorization", "Basic " + new String(basicAuthBytes));

        return get;
    }
    
    
    private void handleFailedReqeust (int responseCode) throws BridgeError {
        switch (responseCode) {
            case 404:
                throw new BridgeError("404: Page not found");
            case 400:
                throw new BridgeError("400: Bad Reqeust");
            case 405:
                throw new BridgeError("405: Method Not Allowed");
            case 500:
                throw new BridgeError("500 Internal Server Error");
            default:
                throw new BridgeError("Unexpected response from server");
        }
    }
        
    private JSONObject parseResponse(String output) throws BridgeError{
                
        JSONObject jsonResponse = new JSONObject();
        try {
            // Parse the response string into a JSONObject
            jsonResponse = (JSONObject)JSONValue.parse(output);
        } catch (ClassCastException e){
            JSONArray error = (JSONArray)JSONValue.parse(output);
            throw new BridgeError("Error caught in retrieve: "
                + ((JSONObject)error.get(0)).get("messageText"));
        } catch (Exception e) {
            throw new BridgeError("An unexpected error has occured " + e);
        }
        
        if(jsonResponse.get("error") != null) {
            throw new BridgeError(String.format("The server responded with an "
                + "error: %s", jsonResponse.toJSONString()));
        }
        
        return jsonResponse;
    }
}
