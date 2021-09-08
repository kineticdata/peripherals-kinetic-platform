package com.kineticdata.bridgehub.adapter.kinetic.platform;

import com.kineticdata.bridgehub.adapter.BridgeAdapter;
import com.kineticdata.bridgehub.adapter.BridgeAdapterTestBase;
import com.kineticdata.bridgehub.adapter.BridgeError;
import com.kineticdata.bridgehub.adapter.BridgeRequest;
import com.kineticdata.bridgehub.adapter.Count;
import com.kineticdata.bridgehub.adapter.Record;
import com.kineticdata.bridgehub.adapter.RecordList;
import static com.kineticdata.bridgehub.adapter.kinetic.platform.KineticCoreAdapter.MAPPINGS;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.Assert;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import org.junit.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 *
 */
public class KineticCoreAdapterTest extends BridgeAdapterTestBase {
    
    private static final Logger LOGGER = LoggerFactory
        .getLogger(KineticCoreAdapterTest.class);
    static String userRecordsMockData = null;

    @Override
    public String getConfigFilePath() {
        return "src/test/resources/bridge-config.yml";
    }
    
    @Override
    public Class getAdapterClass() {
        return KineticCoreAdapter.class;
    }

    @Test
    public void test_invalidBridgeConfiguration() {
        BridgeError error = null;
        
        Map<String,String> invalidConfiguration = new LinkedHashMap<String,String>();
        invalidConfiguration.put("Username", "badUsername");
        invalidConfiguration.put("Password", "badPassword");
        invalidConfiguration.put("Kinetic Core Space Url","https://rcedev.kineticdata.com/kinetic/internal");
        
        BridgeAdapter adapter = new KineticCoreAdapter();
        adapter.setProperties(invalidConfiguration);
        try {
            adapter.initialize();
        } catch (BridgeError e) {
            error = e;
        }
        
        assertNotNull(error);
    }
    
    @Test
    public void test_invalidField() {
        BridgeError error = null;
        
        List<String> invalidFields = new ArrayList<String>();
        UUID randomField = UUID.randomUUID();
        invalidFields.add(randomField.toString());
        
        BridgeRequest request = new BridgeRequest();
        request.setStructure(getStructure());
        request.setFields(invalidFields);
        request.setQuery(getSingleValueQuery());
        
        Record record = null;
        try {
            record = getAdapter().retrieve(request);
        } catch (BridgeError e) { error = e; }
        
        assertNull(error);
        assertNull(record.getRecord().get(randomField.toString()));
    }
    
    @Test
    public void test_blankQuery() {
        BridgeError error = null;
        
        BridgeRequest request = new BridgeRequest();
        request.setStructure(getStructure());
        request.setFields(getFields());
        request.setQuery("");
        
        try {
            getAdapter().search(request);
        } catch (BridgeError e) { error = e; }
        
        assertNull(error);
    }
    
    /* The need for this test must be evaluated.  What should the behavior of the
     * adapter be if no feilds are provided?
     */
    @Test
    public void test_blankFields() {
        BridgeError error = null;
        
        BridgeRequest request = new BridgeRequest();
        request.setStructure(getStructure());
        request.setFields(new ArrayList());
        request.setQuery(getSingleValueQuery());
        
        try {
            getAdapter().retrieve(request);
        } catch (BridgeError e) { error = e; }
        
        assertNull(error);
    }

    @Test
    public void test_retrieve_form() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Forms > services");
        request.setQuery("q=slug=\"cleaning\"");
        
        List<String> list = Arrays.asList("name", "slug", "attributes[Icon]");
        request.setFields(list);
        
        Record record = getAdapter().retrieve(request);
        Assert.assertTrue(record.getRecord().size() > 0);
    }
    
    @Test
    public void test_search_form_limit() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Forms > services");
        request.setQuery("limit=2");
        
        List<String> list = Arrays.asList("name", "slug", "attributes[Icon]");
        request.setFields(list);
        
        RecordList record = getAdapter().search(request);
        Assert.assertTrue(record.getRecords().size() == 2);
    }
    
    @Test
    public void test_search_form() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Forms > services");
        request.setQuery("q=name=*\"c\" AND status=\"<%=parameter[\"Status\"]%>\"");
        
        Map parameters = new HashMap();
        parameters.put("Status", "Active");
        request.setParameters(parameters);
        
        List<String> list = Arrays.asList("name", "slug", "attributes[Icon]");
        request.setFields(list);
        
        RecordList records = getAdapter().search(request);
        Assert.assertTrue(records.getRecords().size() > 0);
    }
    
    @Test
    public void test_count_form() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Forms > services");
        request.setQuery("q=name=*\"zzzz\"");
        
        List<String> list = Arrays.asList("name", "slug");
        request.setFields(list);
        
        Count count = getAdapter().count(request);
        Assert.assertTrue(count.getValue() == 0);
    }
    
    @Test
    public void test_form_limit() throws Exception {
        
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Forms > services");
        request.setQuery("limit=100");
        
        List<String> list = Arrays.asList("name", "slug");
        request.setFields(list);
        
        RecordList records = getAdapter().search(request);
        Assert.assertTrue(records.getRecords().size() > 0);
    }
   
    @Test
    public void test_form_query() throws Exception {
        
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Forms > services");
        request.setQuery("limit=100&q=name=*\"c\" AND status=\"Active\"");
        
        List<String> list = Arrays.asList("name", "slug");
        request.setFields(list);
        
        RecordList records = getAdapter().search(request);
        Assert.assertTrue(records.getRecords().size() > 0);
    }
    
    @Test
    public void test_form_query_include() throws Exception {
        
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Forms > services");
        request.setQuery("q=slug=\"cleaning\"&include=fields");
        
        List<String> list = Arrays.asList("name", "slug", "fields");
        request.setFields(list);
        
        Record record = getAdapter().retrieve(request);
        Assert.assertTrue(record.getRecord().size() > 0);
    }
    
    @Test
    public void test_form_no_query() throws Exception {
        
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Forms > services");
        request.setQuery("");
        
        List<String> list = Arrays.asList("name", "slug");
        request.setFields(list);
        
        RecordList records = getAdapter().search(request);
        Assert.assertTrue(records.getRecords().size() > 0);
    }
    
    @Test
    public void test_retrieve_datastore_form() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Datastore Forms");
        request.setQuery("q=slug=\"alerts\"");
        
        List<String> list = Arrays.asList("name", "slug");
        request.setFields(list);
        
        Record record = getAdapter().retrieve(request);
        Assert.assertTrue(record.getRecord().size() > 0);
    }
    
    @Test
    public void test_search_datastore_form() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Datastore Forms");
        request.setQuery("q=name=*\"a\" AND status=\"Active\"");
        
        List<String> list = Arrays.asList("name", "slug");
        request.setFields(list);
        
        RecordList records = getAdapter().search(request);
        Assert.assertTrue(records.getRecords().size() > 0);
    }
    
    @Test
    public void test_count_datastore_form() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Datastore Forms");
        request.setQuery("");
        
        List<String> list = Arrays.asList("name", "slug");
        request.setFields(list);
        
        Count count = getAdapter().count(request);
        Assert.assertTrue(count.getValue() > 0);
    }
  
    @Test
    public void test_retrieve_users() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Users");
        request.setQuery("q=username=\"chad.rehm@kineticdata.com\"");
        
        List<String> list = Arrays.asList("displayName", "email", "profileAttributes[First Name]");
        request.setFields(list);
        
        Record record = getAdapter().retrieve(request);
        Assert.assertTrue(record.getRecord().size() > 0);
    }
    
    @Test
    public void test_search_users() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Users");
        request.setQuery("includes=details&limit=10&q=username=*\"c\" AND enabled=\"true\"");
        
        List<String> list = Arrays.asList("displayName", "email");
        request.setFields(list);
        
        RecordList records = getAdapter().search(request);
        Assert.assertTrue(records.getRecords().size() > 0);
    }
    
    @Test
    public void test_temp_search_users() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Users");
        List<String> list = Arrays.asList("displayName", "email");
        request.setFields(list);
        
        request.setQuery("limit=2");
        RecordList records1 = getAdapter().search(request);
        
        // Test that the next page of result can be retrieved.
        request.setQuery("limit=2&pageToken=" 
            + records1.getMetadata().get("nextPageToken"));
        RecordList records2 = getAdapter().search(request);
        
        request.setQuery("limit=4");
        RecordList records3 = getAdapter().search(request);
        
        Assert.assertTrue(records1.getRecords().size() > 0);
        Assert.assertTrue(records2.getRecords().size() > 0);
        Assert.assertTrue(records3.getRecords().size() > 0);
    }
    
    @Test
    public void test_count_users() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Users");
        request.setQuery("");
        
        List<String> list = Arrays.asList("displayName", "email");
        request.setFields(list);
        
        Count count = getAdapter().count(request);
        Assert.assertTrue(count.getValue() > 0);
    }
   
    @Test
    public void test_retrieve_teams() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Teams");
        request.setQuery("q=name=\"<%=parameter[\"Team Name\"]%>\"");
        
        Map parameters = new HashMap();
        parameters.put("Team Name", "Role::Contractor");
        request.setParameters(parameters);
        
        List<String> list = Arrays.asList("name", "description");
        request.setFields(list);
        
        Record record = getAdapter().retrieve(request);
        Assert.assertTrue(record.getRecord().size() > 0);
    }
    
    @Test
    public void test_search_teams_null_fields() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Teams");
        request.setQuery("");
        
        request.setFields(null);
        
        RecordList records = getAdapter().search(request);
        Assert.assertTrue(records.getRecords().size() > 0);
    }
    
        @Test
    public void test_search_teams_query() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Teams");
        request.setQuery("q=name=*\"a\"");
        
        List<String> list = Arrays.asList("name", "description", "memberships", "attributes[Icon]");
        request.setFields(list);
        
        RecordList records = getAdapter().search(request);
        Assert.assertTrue(records.getRecords().size() > 0);
    }
    
    @Test
    public void test_count_teams() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Teams");
        request.setQuery("");
        
        List<String> list = Arrays.asList("name", "description");
        request.setFields(list);
        
        Count count = getAdapter().count(request);
        Assert.assertTrue(count.getValue() > 0);
    }
        
    @Test
    public void test_retrieve_kapps() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Kapps");
        request.setQuery("q=slug=\"admin\"");
        
        List<String> list = Arrays.asList("name", "slug", "attributes[Bundle Package]");
        request.setFields(list);
        
        Record record = getAdapter().retrieve(request);
        Assert.assertTrue(record.getRecord().size() > 0);
    }
    
    @Test
    public void test_search_kapps() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Kapps");
        request.setQuery("q=name=*\"q\"");
        
        List<String> list = Arrays.asList("name", "slug");
        request.setFields(list);
        
        RecordList records = getAdapter().search(request);
        Assert.assertTrue(records.getRecords().size() > 0);
    }
    
    @Test
    public void test_count_kapps() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Kapps");
        request.setQuery("");
        
        List<String> list = Arrays.asList("name", "slug");
        request.setFields(list);
        
        Count count = getAdapter().count(request);
        Assert.assertTrue(count.getValue() > 0);
    }
    
    @Test
    public void test_retrieve_submissions() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Submissions");
        request.setQuery("id=7c30f7a6-f0ed-11e9-9061-ff3ea81280ec");
        
        List<String> list = Arrays.asList("createdBy", "label", "values[Checkbox Field]");
        request.setFields(list);
        
        Record record = getAdapter().retrieve(request);
        Assert.assertTrue(record.getRecord().size() > 0);
    }
    
    @Test
    public void test_search_submissions_by_form() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Submissions > services > checkbox-field-bridge-test");
        request.setQuery("");
        
        List<String> list = Arrays.asList("createdBy", "label", "values[Checkbox Field]");
        request.setFields(list);
        
        RecordList records = getAdapter().search(request);
        Assert.assertTrue(records.getRecords().size() > 0);
    }
    
    @Test
    public void test_search_submissions() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Submissions > services");
        request.setQuery("");
        
        List<String> list = Arrays.asList("createdBy", "label");
        request.setFields(list);
        
        RecordList records = getAdapter().search(request);
        Assert.assertTrue(records.getRecords().size() > 0);
    }
    
    @Test
    public void test_search_datastore_submissions() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Datastore Submissions > movies");
        request.setQuery("index=values[Name]");
        
        List<String> list = Arrays.asList("values[Name]", "values[Year]");
        request.setFields(list);
        
        Map <String, String> metadata = new HashMap<>();
        metadata.put("order", "<%=field[\"values[Name]\"]%>:ASC");
        request.setMetadata(metadata);
        
        RecordList records = getAdapter().search(request);
        Assert.assertTrue(records.getRecords().size() > 0);
    }
    
    @Test
    public void test_search_submissions_order() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Submissions > services");
        request.setQuery("timeline=createdAt&direction=ASC");
        
        Map <String, String> metadata = new HashMap<>();
        metadata.put("order", "<%=field[\"createdAt\"]%>:ASC");
        request.setMetadata(metadata);
        
        List<String> list = Arrays.asList("createdAt", "label");
        request.setFields(list);
        
        RecordList records = getAdapter().search(request);
        Assert.assertTrue(records.getRecords().size() > 0);
    }
    
    @Test
    public void test_search_submissions_order_2() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Submissions > services > aaa-test-form");
        request.setQuery("");
        
        Map <String, String> metadata = new HashMap<>();
        metadata.put("order", "<%=field[\"values[Dropdown Field]\"]%>:DESC"
            + ",<%=field[\"values[Radio Button]\"]%>:ASC");
        
        request.setMetadata(metadata);
        
        List<String> fields = Arrays.asList("createdAt", "label",
            "values[Radio Button]","values[Dropdown Field]");
        request.setFields(fields);
        
        RecordList records = getAdapter().search(request);
        Assert.assertTrue(records.getRecords().size() > 0);
    }
    
    @Test
    public void test_search_submissions_order_limit() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Submissions > services > aaa-test-form");
        request.setQuery("coreState=<%=parameter[\"Core State\"]%>&limit=10");
        
        Map parameters = new HashMap();
        parameters.put("Core State", "Submitted");
        request.setParameters(parameters);
        
        Map <String, String> metadata = new HashMap<>();
        metadata.put("order", "<%=field[\"values[Dropdown Field]\"]%>:DESC"
            + ",<%=field[\"values[Radio Button]\"]%>:ASC");
        
        request.setMetadata(metadata);
        
        List<String> fields = Arrays.asList("createdAt", "label",
            "values[Radio Button]","values[Dropdown Field]");
        request.setFields(fields);
        
        RecordList records = getAdapter().search(request);
        Assert.assertTrue(records.getRecords().size() > 0);
        
        RecordList records2 = getAdapter().search(request);
        Assert.assertTrue(records2.getRecords().size() > 0);
    }
    
    @Test
    public void test_search_submissions_by_query() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Submissions > services > aaa-test-form");
        request.setQuery("q=values[Test Text]=\"<%=parameter[\"Field Value\"]%>\"");
        
        Map parameters = new HashMap();
        parameters.put("Field Value", "Foo & Bar");
        request.setParameters(parameters);
        
        List<String> fields = Arrays.asList("createdAt", "label",
            "values[Test Text]","values[Dropdown Field]");
        request.setFields(fields);
        
        RecordList records = getAdapter().search(request);
        Assert.assertTrue(records.getRecords().size() > 0);
    }
    
    @Test
    public void test_search_submissions_order_limit_2() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Submissions > services > bbb-test-form");
        request.setQuery("coreState=<%=parameter[\"Core State\"]%>&limit=10");
        
        Map parameters = new HashMap();
        parameters.put("Core State", "Submitted");
        request.setParameters(parameters);
        
        Map <String, String> metadata = new HashMap<>();
        metadata.put("order", "<%=field[\"values[Dropdown Field]\"]%>:DESC"
            + ",<%=field[\"values[Radio Button]\"]%>:ASC");
        
        request.setMetadata(metadata);
        
        List<String> fields = Arrays.asList("createdAt", "label",
            "values[Radio Button]","values[Dropdown Field]");
        request.setFields(fields);
        
        RecordList records = getAdapter().search(request);
        Assert.assertTrue(records.getRecords().size() == 10);
        
        RecordList records2 = getAdapter().search(request);
        Assert.assertTrue(records2.getRecords().size() == 10);
        
        RecordList records3 = getAdapter().search(request);
        Assert.assertTrue(records3.getRecords().size() > 0);
    }
    
    @Test
    public void test_search_datastore_by_query() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Datastore Submissions > test");
        request.setQuery("index=values[Test Text]&"
                + "q=values[Test Text]=\"<%=parameter[\"Field Value\"]%>\"");
        
        Map parameters = new HashMap();
        parameters.put("Field Value", "Foo & Bar");
        request.setParameters(parameters);
        
        List<String> fields = Arrays.asList("createdAt", "label", "values[Test Text]");
        request.setFields(fields);
        
        RecordList records = getAdapter().search(request);
        Assert.assertTrue(records.getRecords().size() > 0);
    }
    
    @Test
    public void test_search_datastore_multi_by_query() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Datastore Submissions > test");
        request.setQuery("index=values[Test Text],values[Text 2]&"
                + "q=values[Test Text]=\"<%=parameter[\"Field Value\"]%>\" AND"
                + " values[Text 2]=\"\"");
        
        Map parameters = new HashMap();
        parameters.put("Field Value", "Foo & Bar");
        request.setParameters(parameters);
        
        List<String> fields = Arrays.asList("createdAt", "label", "values[Test Text]");
        request.setFields(fields);
        
        RecordList records = getAdapter().search(request);
        Assert.assertTrue(records.getRecords().size() > 0);
    }
    
    @Test
    public void test_count_submissions() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Submissions > services");
        request.setQuery("");
        
        List<String> list = Arrays.asList("name", "slug");
        request.setFields(list);
        
        Count count = getAdapter().count(request);
        Assert.assertTrue(count.getValue() > 0);
    }
    
    @Test
    public void test_restricted_model() throws Exception {
        LinkedHashMap<String,String> sortOrderItems = new LinkedHashMap<>();
        sortOrderItems.put("name", "DESC");
        
        KineticCoreMapping mapping = MAPPINGS.get("Teams");
        List<String> paginationFields = mapping.getPaginationFields();
        
        Map<String,String> parameters = new HashMap<>();
        
        Map<String,String> constantParameters = new HashMap<>();
        constantParameters.put("orderBy", "name");
        constantParameters.put("direction", "DESC");
        
        boolean unsupported = mapping.getPaginationPredicate()
            .apply(paginationFields, parameters, sortOrderItems);
        
        Assert.assertTrue(unsupported);
        Assert.assertTrue(parameters.equals(constantParameters));
        
        // Test that sort order item exists in paginatied fields.
        sortOrderItems.clear();
        sortOrderItems.put("foo", "DESC");
        unsupported = mapping.getPaginationPredicate()
            .apply(paginationFields, parameters, sortOrderItems);
        Assert.assertFalse(unsupported);
    }
    
    @Test
    public void test_restricted_model_multiple_items() throws Exception {
        LinkedHashMap<String,String> sortOrderItems = new LinkedHashMap<>();
        sortOrderItems.put("status","DESC");
        sortOrderItems.put("name", "DESC");
        
        KineticCoreMapping mapping = MAPPINGS.get("Teams");
        List<String> paginationFields = mapping.getPaginationFields();
        
        Map<String,String> parameters = new HashMap<>();
        
        boolean unsupported = mapping.getPaginationPredicate()
            .apply(paginationFields, parameters, sortOrderItems);
        
        // Test that multiple sort order items failes
        Assert.assertFalse(unsupported);
    }
    
    @Test
    public void test_unrestricted_model() throws Exception {
        LinkedHashMap<String,String> sortOrderItems = new LinkedHashMap<>();
        sortOrderItems.put("name", "DESC");
        
        KineticCoreMapping mapping = MAPPINGS.get("Datastore Forms");
        List<String> paginationFields = mapping.getPaginationFields();
        
        Map<String,String> parameters = new HashMap<>();
        
        // Create a constant to compare the result of parameters against.
        Map<String,String> constantParameters = new HashMap<>();
        constantParameters.put("orderBy", "name");
        constantParameters.put("direction", "DESC");
        
        boolean unsupported = mapping.getPaginationPredicate()
            .apply(paginationFields, parameters, sortOrderItems);
        
        Assert.assertTrue(unsupported);
        Assert.assertTrue(parameters.equals(constantParameters));
        
        // Test that sort order item is a supported field.
        sortOrderItems.clear();
        sortOrderItems.put("foo", "DESC");
        
        unsupported = mapping.getPaginationPredicate()
            .apply(paginationFields, parameters, sortOrderItems);
        
        Assert.assertFalse(unsupported);
    }
    
    @Test
    public void test_unrestricted_model_multiple_items() throws Exception {
        LinkedHashMap<String,String> sortOrderItems = new LinkedHashMap<>();
        sortOrderItems.put("status","DESC");
        sortOrderItems.put("name", "DESC");
        
        KineticCoreMapping mapping = MAPPINGS.get("Datastore Forms");
        List<String> paginationFields = mapping.getPaginationFields();
        
        Map<String,String> parameters = new HashMap<>();
        
        Map<String,String> constantParameters = new HashMap<>();
        constantParameters.put("orderBy", "status,name");
        constantParameters.put("direction", "DESC");
        
        boolean unsupported = mapping.getPaginationPredicate()
            .apply(paginationFields, parameters, sortOrderItems);
        
        Assert.assertTrue(unsupported);
        Assert.assertTrue(parameters.equals(constantParameters));
        
        // Test that orderBy order is correct. Should match put order of 
        // sortOrderItems above.
        constantParameters.put("orderBy", "name,status");
        Assert.assertFalse(parameters.equals(constantParameters));
    }
    
    @Test
    public void test_unrestricted_model_diff_direction() throws Exception {
        LinkedHashMap<String,String> sortOrderItems = new LinkedHashMap<>();
        sortOrderItems.put("status","ASC");
        sortOrderItems.put("name", "DESC");
        
        List<String> paginationFields = Arrays.asList("name", "status");
        
        Map<String,String> parameters = new HashMap<>();
        
        KineticCoreMapping mapping = MAPPINGS.get("Datastore Forms");
        boolean unsupported = mapping.getPaginationPredicate()
            .apply(paginationFields, parameters, sortOrderItems);
        
        Assert.assertFalse(unsupported);
    }
    
    @Test
    public void test_index_model() throws Exception {
        List<String> list = Arrays.asList("values[Name]");
        
        LinkedHashMap<String,String> sortOrderItems = new LinkedHashMap<>();
        sortOrderItems.put("values[Name]", "ASC");
        
        KineticCoreMapping mapping = MAPPINGS.get("Datastore Submissions");
        boolean unsupported = mapping.getPaginationPredicate()
            .apply(list, new HashMap<String, String>(), sortOrderItems);
        
        Assert.assertTrue(unsupported);
    }
    
    @Test
    public void test_index_model_multiple_items() throws Exception {
        List<String> list = Arrays.asList("values[Name]", "values[Year]");
        
        LinkedHashMap<String,String> sortOrderItems = new LinkedHashMap<>();
        sortOrderItems.put("values[Name]", "DESC");
        sortOrderItems.put("values[Year]", "DESC");
        
        KineticCoreMapping mapping = MAPPINGS.get("Datastore Submissions");
        boolean unsupported = mapping.getPaginationPredicate()
            .apply(list, new HashMap<String, String>(), sortOrderItems);
        
        Assert.assertTrue(unsupported);
    }
            
    @Test
    public void test_index_model_diff_direction() throws Exception {
        List<String> list = Arrays.asList("values[Name]", "values[Year]");
        
        LinkedHashMap<String,String> sortOrderItems = new LinkedHashMap<>();
        sortOrderItems.put("values[Name]", "ASC");
        sortOrderItems.put("values[Year]", "DESC");
        
        KineticCoreMapping mapping = MAPPINGS.get("Datastore Submissions");
        boolean unsupported = mapping.getPaginationPredicate()
            .apply(list, new HashMap<String, String>(), sortOrderItems);
        
        Assert.assertFalse(unsupported);
    }
     
    @Test
    public void test_index_model_diff_order() throws Exception {
        List<String> list = Arrays.asList("values[Year]", "values[Name]");
        
        LinkedHashMap<String,String> sortOrderItems = new LinkedHashMap<>();
        sortOrderItems.put("values[Name]", "ASC");
        sortOrderItems.put("values[Year]", "ASC");
        
        KineticCoreMapping mapping = MAPPINGS.get("Datastore Submissions");
        boolean unsupported = mapping.getPaginationPredicate()
            .apply(list, new HashMap<String, String>(), sortOrderItems);
        
        Assert.assertFalse(unsupported);
    }
    
    @Test
    public void test_unrestricted_kapps_sort() throws Exception {        
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Kapps");
        request.setQuery("");
        
        request.setParameters(new HashMap() {{
          put("","");  
        }});
        
        request.setMetadata(new HashMap() {{
            put("order", "<%=field[\"createdBy\"]%>:ASC"
                + ",<%=field[\"name\"]%>:ASC");
        }});
               
        List<String> list = Arrays.asList("name", "slug", "createdBy");
        request.setFields(list);
        
        RecordList records = getAdapter().search(request);
    }
}