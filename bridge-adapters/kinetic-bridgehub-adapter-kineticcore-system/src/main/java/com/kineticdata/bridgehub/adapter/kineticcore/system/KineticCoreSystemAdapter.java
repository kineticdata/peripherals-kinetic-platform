package com.kineticdata.bridgehub.adapter.kineticcore.system;

import com.kineticdata.bridgehub.adapter.BridgeAdapter;
import com.kineticdata.bridgehub.adapter.BridgeError;
import com.kineticdata.bridgehub.adapter.BridgeRequest;
import com.kineticdata.bridgehub.adapter.Count;
import com.kineticdata.bridgehub.adapter.Record;
import com.kineticdata.bridgehub.adapter.RecordList;
import com.kineticdata.commons.v1.config.ConfigurableProperty;
import com.kineticdata.commons.v1.config.ConfigurablePropertyMap;
import java.io.IOException;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import org.apache.commons.codec.binary.Base64;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.util.EntityUtils;
import org.slf4j.LoggerFactory;

/**
 *
 */
public class KineticCoreSystemAdapter implements BridgeAdapter {
    /*----------------------------------------------------------------------------------------------
     * PROPERTIES
     *--------------------------------------------------------------------------------------------*/

    /** Defines the adapter display name. */
    public static final String NAME = "Kinetic Core System Bridge";

    /** Defines the logger */
    protected static final org.slf4j.Logger logger = LoggerFactory.getLogger(KineticCoreSystemAdapter.class);

    /** Adapter version constant. */
    public static String VERSION;
    /** Load the properties version from the version.properties file. */
    static {
        try {
            java.util.Properties properties = new java.util.Properties();
            properties.load(KineticCoreSystemAdapter.class.getResourceAsStream("/"+KineticCoreSystemAdapter.class.getName()+".version"));
            VERSION = properties.getProperty("version");
        } catch (IOException e) {
            logger.warn("Unable to load "+KineticCoreSystemAdapter.class.getName()+" version properties.", e);
            VERSION = "Unknown";
        }
    }

    /** Defines the collection of property names for the adapter. */
    public static class Properties {
        public static final String USERNAME = "Username";
        public static final String PASSWORD = "Password";
        public static final String SERVER_LOCATION = "Kinetic Core Location";
    }
    private String username;
    private String password;
    private String serverLocation;

    private KineticCoreSystemSpaceHelper spaceHelper;
    private KineticCoreSystemUserHelper userHelper;

    private final ConfigurablePropertyMap properties = new ConfigurablePropertyMap(
            new ConfigurableProperty(Properties.USERNAME).setIsRequired(true),
            new ConfigurableProperty(Properties.PASSWORD).setIsRequired(true).setIsSensitive(true)
                .setDescription("The Username/Password should have access to the Kinetic Request CE Admin Console."),
            new ConfigurableProperty(Properties.SERVER_LOCATION).setIsRequired(true)
                .setDescription("The URL location of the Kinetic Request CE installation without a space specified (ie. https://localhost:8080/kinetic).")
    );

    /**
     * Structures that are valid to use in the bridge
     */
    public static final List<String> VALID_STRUCTURES = Arrays.asList(new String[] {
        "Users","Spaces"
    });

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
        this.username = properties.getValue(Properties.USERNAME);
        this.password = properties.getValue(Properties.PASSWORD);
        this.serverLocation = properties.getValue(Properties.SERVER_LOCATION);

        this.userHelper = new KineticCoreSystemUserHelper(this.username, this.password, this.serverLocation);
        this.spaceHelper = new KineticCoreSystemSpaceHelper(this.username, this.password, this.serverLocation);

        // Testing the configuration values to make sure that they
        // correctly authenticate with Core
        testAuth();
    }

    /*---------------------------------------------------------------------------------------------
     * IMPLEMENTATION METHODS
     *-------------------------------------------------------------------------------------------*/

    @Override
    public Count count(BridgeRequest request) throws BridgeError {
        request.setQuery(substituteQueryParameters(request));

        if (!VALID_STRUCTURES.contains(request.getStructure())) {
            throw new BridgeError("Invalid Structure: '" + request.getStructure() + "' is not a valid structure");
        }

        Count count;
        if (request.getStructure().equals("Spaces")) {
            count = this.spaceHelper.count(request);
        } else if (request.getStructure().equals("Users")) {
            count = this.userHelper.count(request);
        } else {
            throw new BridgeError("The structure '"+request.getStructure()+"' does not have a count method defined");
        }

        return count;
    }

    @Override
    public Record retrieve(BridgeRequest request) throws BridgeError {
        request.setQuery(substituteQueryParameters(request));

        if (!VALID_STRUCTURES.contains(request.getStructure())) {
            throw new BridgeError("Invalid Structure: '" + request.getStructure() + "' is not a valid structure");
        }

        if (request.getFields() == null || request.getFields().isEmpty()) {
            throw new BridgeError("Invalid Request: No fields were included in the request.");
        }

        Record record;
        if (request.getStructure().equals("Spaces")) {
            record = this.spaceHelper.retrieve(request);
        } else if (request.getStructure().equals("Users")) {
            record = this.userHelper.retrieve(request);
        } else {
            throw new BridgeError("The structure '"+request.getStructure()+"' does not have a retrieve method defined");
        }

        return record;
    }

    @Override
    public RecordList search(BridgeRequest request) throws BridgeError {
        request.setQuery(substituteQueryParameters(request));

        if (!VALID_STRUCTURES.contains(request.getStructure())) {
            throw new BridgeError("Invalid Structure: '" + request.getStructure() + "' is not a valid structure");
        }

         if (request.getFields() == null || request.getFields().isEmpty()) {
            throw new BridgeError("Invalid Request: No fields were included in the request.");
        }

        RecordList recordList;
        if (request.getStructure().equals("Spaces")) {
            recordList = this.spaceHelper.search(request);
        } else if (request.getStructure().equals("Users")) {
            recordList = this.userHelper.search(request);
        } else {
            throw new BridgeError("The structure '"+request.getStructure()+"' does not have a search method defined");
        }

        return recordList;
    }

    /*---------------------------------------------------------------------------------------------
     * HELPER METHODS
     *-------------------------------------------------------------------------------------------*/

    private String substituteQueryParameters(BridgeRequest request) throws BridgeError {
        KineticCoreSystemQualificationParser parser = new KineticCoreSystemQualificationParser();
        return parser.parse(request.getQuery(),request.getParameters());
    }

    private void testAuth() throws BridgeError {
        logger.debug("Testing the authentication credentials");
        HttpGet get = new HttpGet(serverLocation + "/app/api/v1/spaces");
        get = addAuthenticationHeader(get, this.username, this.password);

        HttpClient client = HttpClients.createDefault();
        HttpResponse response;
        try {
            response = client.execute(get);
            HttpEntity entity = response.getEntity();
            EntityUtils.consume(entity);
            if (response.getStatusLine().getStatusCode() == 401) {
                throw new BridgeError("Unauthorized: The inputted Username/Password combination is not valid.");
            } else if (response.getStatusLine().getStatusCode() != 200) {
                throw new BridgeError("Connecting to the Kinetic Core instance located at '"+this.serverLocation+"' failed.");
            }
        }
        catch (IOException e) {
            logger.error(e.getMessage());
            throw new BridgeError("Unable to make a connection to properly to Kinetic Core.");
        }
    }

    private HttpGet addAuthenticationHeader(HttpGet get, String username, String password) {
        String creds = username + ":" + password;
        byte[] basicAuthBytes = Base64.encodeBase64(creds.getBytes());
        get.setHeader("Authorization", "Basic " + new String(basicAuthBytes));

        return get;
    }
}
