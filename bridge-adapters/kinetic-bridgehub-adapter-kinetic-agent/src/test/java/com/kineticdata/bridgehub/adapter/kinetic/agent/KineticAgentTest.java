package com.kineticdata.bridgehub.adapter.kinetic.agent;

import com.kineticdata.bridgehub.adapter.BridgeAdapter;
import com.kineticdata.bridgehub.adapter.BridgeAdapterTestBase;
import com.kineticdata.bridgehub.adapter.BridgeError;
import com.kineticdata.bridgehub.adapter.BridgeRequest;
import com.kineticdata.bridgehub.adapter.Count;
import com.kineticdata.bridgehub.adapter.Record;
import com.kineticdata.bridgehub.adapter.RecordList;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.Test;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

public class KineticAgentTest extends BridgeAdapterTestBase{
        
    @Override
    public Class getAdapterClass() {
        return KineticAgentBridgeAdapter.class;
    }
    
    @Override
    public String getConfigFilePath() {
        return "src/test/resources/bridge-config.yml";
    }
    
    @Test
    public void _count() throws Exception{
        BridgeError error = null;
        
        Map<String,String> configValues = new LinkedHashMap<String,String>();
        configValues.put("Username","");
        configValues.put("Password", "");
        configValues.put("Space","");
        configValues.put("Slug", "");
        configValues.put("Agent URL","");
        
        BridgeAdapter adapter = new KineticAgentBridgeAdapter();
        adapter.setProperties(configValues);
        try {
            adapter.initialize();
        } catch (BridgeError e) {
            error = e;
        }
        
        assertNull(error);
        
        // Create the Bridge Request
        List<String> fields = new ArrayList<String>();
        fields.add("username");
        
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Users");
        request.setFields(fields);
        request.setQuery("");
        
        Count count = null;
        try {
            count = adapter.count(request);
        } catch (BridgeError e) {
            error = e;
        }
        
        assertNull(error);
        assertTrue(count.getValue() > 0);
    }
    
    @Test
    public void _retrieve() throws Exception{
        BridgeError error = null;
        
        Map<String,String> configValues = new LinkedHashMap<String,String>();
        configValues.put("Username","");
        configValues.put("Password", "");
        configValues.put("Space","");
        configValues.put("Slug", "");
        configValues.put("Agent Url","");
        
        BridgeAdapter adapter = new KineticAgentBridgeAdapter();
        adapter.setProperties(configValues);
        try {
            adapter.initialize();
        } catch (BridgeError e) {
            error = e;
        }
        
        assertNull(error);
        
        // Create the Bridge Request
        List<String> fields = new ArrayList<String>();
        fields.add("username");
        fields.add("displayName");
        fields.add("email");
        
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Users");
        request.setFields(fields);
        request.setQuery("username=<%=parameter[\"User Name\"]%>");
        
        Map parameters = new HashMap();
        parameters.put("User Name", "chad.rehm@kineticdata.com");
        request.setParameters(parameters);
        
        Record record = null;
        try {
            record = adapter.retrieve(request);
        } catch (BridgeError e) {
            error = e;
        }
        
        assertNull(error);
        assertTrue(record.getRecord().size() > 0);
    }
    
    @Test
    public void _search() throws Exception{
        BridgeError error = null;
        
        Map<String,String> configValues = new LinkedHashMap<String,String>();
        configValues.put("Username","");
        configValues.put("Password", "");
        configValues.put("Space","");
        configValues.put("Slug", "");
        configValues.put("Agent Url","");
        
        BridgeAdapter adapter = new KineticAgentBridgeAdapter();
        adapter.setProperties(configValues);
        try {
            adapter.initialize();
        } catch (BridgeError e) {
            error = e;
        }
        
        assertNull(error);
        
        // Create the Bridge Request
        List<String> fields = new ArrayList<String>();
        fields.add("username");
        fields.add("displayName");
        fields.add("email");
        
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Users");
        request.setFields(fields);
        request.setQuery("");
        
        RecordList records = null;
        try {
            records = adapter.search(request);
        } catch (BridgeError e) {
            error = e;
        }
        
        assertNull(error);
        assertTrue(records.getRecords().size() > 0);
    }
    
    @Test
    public void _search_sort_metadata() throws Exception{
        BridgeError error = null;
        
        Map<String,String> configValues = new HashMap<String,String>();
        configValues.put("Username","");
        configValues.put("Password", "");
        configValues.put("Agent URL","");
        
        BridgeAdapter adapter = new KineticAgentBridgeAdapter();
        adapter.setProperties(configValues);
        try {
            adapter.initialize();
        } catch (BridgeError e) {
            error = e;
        }
        
        assertNull(error);
        
        // Create the Bridge Request
        List<String> fields = new ArrayList<String>();
        fields.add("Bar");
        fields.add("Foo");
        
        BridgeRequest request = new BridgeRequest();
        request.setStructure("");
        request.setFields(fields);
        request.setQuery("");
        
        Map <String, String> metadata = new HashMap<>();
        metadata.put("order", "<%=field[\"Foo\"]%>:DESC");       
        request.setMetadata(metadata);
        
        RecordList records = null;
        try {
            records = adapter.search(request);
        } catch (BridgeError e) {
            error = e;
        }
        
        assertNull(error);
        assertTrue(records.getRecords().size() > 0);
    }
    
    @Test
    public void _search_sort_metadata_2() throws Exception{
        BridgeError error = null;
        
        Map<String,String> configValues = new HashMap<String,String>();
        configValues.put("Username","");
        configValues.put("Password", "");
        configValues.put("Agent URL","");
        
        BridgeAdapter adapter = new KineticAgentBridgeAdapter();
        adapter.setProperties(configValues);
        try {
            adapter.initialize();
        } catch (BridgeError e) {
            error = e;
        }
        
        assertNull(error);
        
        // Create the Bridge Request
        List<String> fields = new ArrayList<String>();
        fields.add("Bar");
        fields.add("Foo");
        
        BridgeRequest request = new BridgeRequest();
        request.setStructure("");
        request.setFields(fields);
        request.setQuery("");
        
        Map <String, String> metadata = new HashMap<>();
        metadata.put("order", "<%=field[\"Foo\"]%>:DESC"
            + ",<%=field[\"Bar\"]%>:DESC");       
        request.setMetadata(metadata);
        
        RecordList records = null;
        try {
            records = adapter.search(request);
        } catch (BridgeError e) {
            error = e;
        }
        
        assertNull(error);
        assertTrue(records.getRecords().size() > 0);
    }
}
