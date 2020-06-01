package com.kineticdata.bridgehub.adapter.synctask;

import com.kineticdata.bridgehub.adapter.kinetictasksync.KineticTaskSyncAdapter;
import com.kineticdata.bridgehub.adapter.BridgeAdapter;
import com.kineticdata.bridgehub.adapter.BridgeAdapterTestBase;
import com.kineticdata.bridgehub.adapter.BridgeError;
import com.kineticdata.bridgehub.adapter.BridgeRequest;
import com.kineticdata.bridgehub.adapter.Count;
import com.kineticdata.bridgehub.adapter.Record;
import com.kineticdata.bridgehub.adapter.RecordList;
import com.kineticdata.bridgehub.adapter.kinetictasksync.KineticTaskSyncQualificationParser;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.JSONValue;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;
import org.junit.Test;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

/**
 *
 */
public class KineticTaskSyncAdapterTest extends BridgeAdapterTestBase {
    
    static String userRecordsMockData = null;

    @Override
    public String getConfigFilePath() {
        return "src/test/resources/bridge-config.yml";
    }
    
    @Override
    public Class getAdapterClass() {
        return KineticTaskSyncAdapter.class;
    }

    @Test
    public void test_retrieve() throws BridgeError{
        
        BridgeRequest request = new BridgeRequest();
        
        // Create the Bridge Request
        List<String> fields = new ArrayList<String>();
        
        request.setStructure("kinetic-task-sync-log");
        request.setFields(fields);
        request.setQuery("/Kinops/SyncTree/Test?Title=Test&Description=Test?1");
        
        Record record = getAdapter().retrieve(request);
        Map<String,Object> recordMap = record.getRecord();
        
        assertNotNull(recordMap);
    }
    
    @Test
    public void test_bad_tree_name() throws BridgeError{
        
        BridgeRequest request = new BridgeRequest();
        
        // Create the Bridge Request
        List<String> fields = new ArrayList<String>();
        
        request.setStructure("kinetic-task-sync-log");
        request.setFields(fields);
        request.setQuery("/Kinops/SyncTree/Testx?Title=Test&Description=Test?1");
        
        Record record = getAdapter().retrieve(request);
        Map<String,Object> recordMap = record.getRecord();
        
        assertNotNull(recordMap);
    }
    
    @Test
    public void test_retrieve_from_callback() throws BridgeError{
        
        BridgeRequest request = new BridgeRequest();
        
        // Create the Bridge Request
        List<String> fields = new ArrayList<String>();
        
        request.setStructure("kinetic-task-sync-log");
        request.setFields(fields);
        request.setQuery("callbackId=86d3d1ec-9d1f-49a5-880b-18a19be0e36c");
        
        Record record = getAdapter().retrieve(request);
        Map<String,Object> recordMap = record.getRecord();
        
        assertNotNull(recordMap);
    }

    @Test
    public void parse_query() throws BridgeError{
        KineticTaskSyncQualificationParser qualificationParser 
            = new KineticTaskSyncQualificationParser();
        
        BridgeRequest request = new BridgeRequest();
        
        Map parameters = new HashMap();
        parameters.put("payload", "Hello");
        request.setParameters(parameters);
        request.setQuery("/Kinops/SyncTree/Test?payload=<%=parameter[\"payload\"]%>");
        
        Map<String,ArrayList<String>> parsedQuery = qualificationParser
            .parseQuery(qualificationParser
            .parse("/Kinops/SyncTree/Test?payload=<%=parameter[\"payload\"]%>",
                parameters));
        
        assertNotNull(parsedQuery);
    }
    
    /*---------------------------------------------------------------------------------------------
     * HELPER METHODS
     *-------------------------------------------------------------------------------------------*/
    
    /**
      The JSON array will be built from a mock JSON string with the following 5 users
      
        username: test.user
        email: test.user@acme.com
        display name: Test user
        attributes: [First Name = Test, Last Name = User]
        profileAttributes: []
        space admin: false
        enabled: false
        
        username: don.demo@kineticdata.com
        email: don.demo@kineticdata.com
        display name: Don Demo
        attributes: [Group = Fulfillment::IT]
        profileAttributes: [Task Administrator = true]
        space admin: false
        enabled: true
        
        username: prod.user@kineticdata.com
        email: prod.user@kineticdata.com
        display name: Production User
        attributes: []
        profileAttributes: [Task Administrator = true]
        space admin: true
        enabled: true
        
        username: jeff.johnson@gmail.com
        email: jeff.johnson@gmail.com
        display name: Jeff Johnson
        attributes: [First Name = [Jeff, Jeffery], Last Name = Johnson]
        profileAttributes: [Task Administrator = false]
        space admin: true
        enabled: true
        
        username: dev.user@kineticdata.dev
        email: dev.user@kineticdata.dev
        display name: Test user
        attributes: []
        profileAttributes: []
        space admin: true
        enabled: true
    */    
    public JSONArray buildUserRecordArray() {
        if (userRecordsMockData == null) {
            userRecordsMockData = "{\"users\":[{\"attributes\":[{\"values\":[\"Test\"],\"name\":\"First Name\"},{\"values\":[\"User\"],\"name\":\"Last Name\"}],\"profileAttributes\":[],\"displayName\":\"Test User\",\"email\":\"test.user@acme.com\",\"enabled\":false,\"spaceAdmin\":false,\"username\":\"test.user\"},{\"attributes\":[{\"values\":[\"Fulfillment::IT\"],\"name\":\"Group\"}],\"profileAttributes\":[{\"name\":\"Task Administrator\",\"values\":[\"true\"]}],\"displayName\":\"Don Demo\",\"email\":\"don.demo@kineticdata.com\",\"enabled\":true,\"spaceAdmin\":false,\"username\":\"don.demo@kineticdata.com\"},{\"attributes\":[],\"profileAttributes\":[{\"name\":\"Task Administrator\",\"values\":[\"true\"]}],\"displayName\":\"Production User\",\"email\":\"prod.user@kineticdata.com\",\"enabled\":true,\"spaceAdmin\":true,\"username\":\"prod.user@kineticdata.com\"},{\"attributes\":[{\"values\":[\"Jeff\",\"Jeffery\"],\"name\":\"First Name\"},{\"values\":[\"Johnson\"],\"name\":\"Last Name\"}],\"profileAttributes\":[{\"name\":\"Task Administrator\",\"values\":[\"false\"]}],\"displayName\":\"Jeff Johnson\",\"email\":\"jeff.johnson@gmail.com\",\"enabled\":true,\"spaceAdmin\":true,\"username\":\"jeff.johnson@gmail.com\"},{\"attributes\":[],\"profileAttributes\":[],\"displayName\":\"Development User\",\"email\":\"dev.user@kineticdata.dev\",\"enabled\":true,\"spaceAdmin\":true,\"username\":\"dev.user@kineticdata.dev\"}]}";
        }
        JSONObject jsonObject = (JSONObject)JSONValue.parse(userRecordsMockData);
        return (JSONArray)jsonObject.get("users");
    }
}
