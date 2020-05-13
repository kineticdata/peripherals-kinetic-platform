package com.kineticdata.bridgehub.adapter.kineticcore;

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
public class KineticCoreAdapter implements BridgeAdapter {
    /*----------------------------------------------------------------------------------------------
     * PROPERTIES
     *--------------------------------------------------------------------------------------------*/

    /** Defines the adapter display name. */
    public static final String NAME = "Kinetic Core Bridge";

    /** Defines the logger */
    protected static final org.slf4j.Logger logger = LoggerFactory.getLogger(KineticCoreAdapter.class);

    /** Adapter version constant. */
    public static String VERSION;
    /** Load the properties version from the version.properties file. */
    static {
        try {
            java.util.Properties properties = new java.util.Properties();
            properties.load(KineticCoreAdapter.class.getResourceAsStream("/"+KineticCoreAdapter.class.getName()+".version"));
            VERSION = properties.getProperty("version");
        } catch (IOException e) {
            logger.warn("Unable to load "+KineticCoreAdapter.class.getName()+" version properties.", e);
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
    private KineticCoreSubmissionHelper submissionHelper;
    private KineticCoreUserHelper userHelper;
    private KineticCoreTeamHelper teamHelper;
    private KineticCoreKappHelper kappHelper;
    private KineticCoreFormHelper formHelper;
    private KineticCoreDatastoreFormHelper datastoreFormHelper;
    private KineticCoreDatastoreSubmissionHelper datastoreSubmissionHelper;

    private final ConfigurablePropertyMap properties = new ConfigurablePropertyMap(
            new ConfigurableProperty(Properties.USERNAME).setIsRequired(true),
            new ConfigurableProperty(Properties.PASSWORD).setIsRequired(true).setIsSensitive(true),
            new ConfigurableProperty(Properties.SPACE_URL).setIsRequired(true)
    );

    /**
     * Structures that are valid to use in the bridge
     */
    public static final List<String> VALID_STRUCTURES = Arrays.asList(new String[] {
        "Submissions","Users","Teams","Kapps","Forms","Datastore Forms","Datastore Submissions"
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
        this.spaceUrl = properties.getValue(Properties.SPACE_URL);
        this.username = properties.getValue(Properties.USERNAME);
        this.password = properties.getValue(Properties.PASSWORD);
        this.submissionHelper = new KineticCoreSubmissionHelper(this.username, this.password, this.spaceUrl);
        this.userHelper = new KineticCoreUserHelper(this.username, this.password, this.spaceUrl);
        this.teamHelper = new KineticCoreTeamHelper(this.username, this.password, this.spaceUrl);
        this.kappHelper = new KineticCoreKappHelper(this.username, this.password, this.spaceUrl);
        this.formHelper = new KineticCoreFormHelper(this.username, this.password, this.spaceUrl);
        this.datastoreFormHelper = new KineticCoreDatastoreFormHelper(this.username, this.password, this.spaceUrl);
        this.datastoreSubmissionHelper = new KineticCoreDatastoreSubmissionHelper(this.username, this.password, this.spaceUrl);

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
        if (request.getStructure().equals("Submissions")) {
            count = this.submissionHelper.count(request);
        } else if (request.getStructure().equals("Users")) {
            count = this.userHelper.count(request);
        } else if (request.getStructure().equals("Teams")) {
            count = this.teamHelper.count(request);
        } else if (request.getStructure().equals("Kapps")) {
            count = this.kappHelper.count(request);
        } else if (request.getStructure().equals("Forms")) {
            count = this.formHelper.count(request);
        } else if (request.getStructure().equals("Datastore Forms")) {
            count = this.datastoreFormHelper.count(request);
        } else if (request.getStructure().equals("Datastore Submissions")) {
            count = this.datastoreSubmissionHelper.count(request);
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
        if (request.getStructure().equals("Submissions")) {
            record = this.submissionHelper.retrieve(request);
        } else if (request.getStructure().equals("Users")) {
            record = this.userHelper.retrieve(request);
        } else if (request.getStructure().equals("Teams")) {
            record = this.teamHelper.retrieve(request);
        } else if (request.getStructure().equals("Kapps")) {
            record = this.kappHelper.retrieve(request);
        } else if (request.getStructure().equals("Forms")) {
            record = this.formHelper.retrieve(request);
        } else if (request.getStructure().equals("Datastore Forms")) {
            record = this.datastoreFormHelper.retrieve(request);
        } else if (request.getStructure().equals("Datastore Submissions")) {
            record = this.datastoreSubmissionHelper.retrieve(request);
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
        if (request.getStructure().equals("Submissions")) {
            recordList = this.submissionHelper.search(request);
        } else if (request.getStructure().equals("Users")) {
            recordList = this.userHelper.search(request);
        } else if (request.getStructure().equals("Teams")) {
            recordList = this.teamHelper.search(request);
        } else if (request.getStructure().equals("Kapps")) {
            recordList = this.kappHelper.search(request);
        } else if (request.getStructure().equals("Forms")) {
            recordList = this.formHelper.search(request);
        } else if (request.getStructure().equals("Datastore Forms")) {
            recordList = this.datastoreFormHelper.search(request);
        } else if (request.getStructure().equals("Datastore Submissions")) {
            recordList = this.datastoreSubmissionHelper.search(request);
        } else {
            throw new BridgeError("The structure '"+request.getStructure()+"' does not have a search method defined");
        }

        return recordList;
    }

    /*---------------------------------------------------------------------------------------------
     * HELPER METHODS
     *-------------------------------------------------------------------------------------------*/

    private String substituteQueryParameters(BridgeRequest request) throws BridgeError {
        KineticCoreQualificationParser parser = new KineticCoreQualificationParser();
        return parser.parse(request.getQuery(),request.getParameters());
    }

    private void testAuth() throws BridgeError {
        logger.debug("Testing the authentication credentials");
        HttpGet get = new HttpGet(spaceUrl + "/app/api/v1/space");
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
                throw new BridgeError("Connecting to the Kinetic Core instance located at '"+this.spaceUrl+"' failed.");
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
