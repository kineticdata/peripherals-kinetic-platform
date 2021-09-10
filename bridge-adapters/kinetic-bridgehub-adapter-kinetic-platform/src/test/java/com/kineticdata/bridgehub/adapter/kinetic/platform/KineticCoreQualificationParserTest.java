package com.kineticdata.bridgehub.adapter.kinetic.platform;

import com.kineticdata.bridgehub.adapter.kinetic.platform.KineticCoreQualificationParser;
import java.util.HashMap;
import org.junit.Before;
import org.junit.Test;
import java.util.LinkedHashMap;
import java.util.Map;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotEquals;
import static org.junit.Assert.assertTrue;

public class KineticCoreQualificationParserTest {

    protected KineticCoreQualificationParser parser;

    @Before
    public void beforeEach() throws Exception {
        parser = new KineticCoreQualificationParser();
    }

    /*----------------------------------------------------------------------------------------------
     * TESTS
     *--------------------------------------------------------------------------------------------*/
    @Test
    public void test_parse_parametera_backslash() throws Exception {
        // `\` should be escaped to `\\`

        // Build the parameter map
        Map<String, String> bridgeParameters = new LinkedHashMap<>();
        bridgeParameters.put("widget", "\\");
        String queryString = parser.parse("q=\"<%=parameter[widget]%>\"",
            bridgeParameters);
        
        assertEquals("q=\"" + "\\\\" + "\"", queryString);
    }
    
    @Test
    public void test_parse_parameter_backslash_quotation() throws Exception {
        // `\"` should be escaped to `\\\"`

        // Build the parameter map
        Map<String, String> bridgeParameters = new LinkedHashMap<>();
        bridgeParameters.put("widget", "\\\"");
        String queryString = parser.parse("q=\"<%=parameter[widget]%>\"",
            bridgeParameters);
        
        assertEquals("q=\"" + "\\\\\\\"" + "\"", queryString);
    }

    @Test
    public void test_parse_parameter_quotation() throws Exception {
        // `"` should be escaped to `\"`

        // Build the parameter map
        Map<String, String> bridgeParameters = new LinkedHashMap<>();
        bridgeParameters.put("widget", "\"abc");
        String queryString = parser.parse("q=\"<%=parameter[widget]%>\"",
            bridgeParameters);
        
        assertEquals("q=\"" + "\\\"abc" + "\"", queryString);
    }

    @Test
    public void test_get_parameter() throws Exception {
        String queryString = "q=name=\"foo\"";
        Map <String, String> parameterMap = parser.getParameters(queryString);
        
        Map <String, String> constantMap = new HashMap<>();
        constantMap.put("q", "name=\"foo\"");
        
        assertEquals(parameterMap, constantMap);
    }
    
    @Test
    public void test_get_parameter_multiple() throws Exception {
        String queryString = "coreState=Draft&start=2019-02-05";
        Map <String, String> parameterMap = parser.getParameters(queryString);
        
        Map <String, String> constantMap = new HashMap<>();
        constantMap.put("coreState", "Draft");
        constantMap.put("start", "2019-02-05");
        
        assertEquals(parameterMap, constantMap);
    }
    
    @Test
    public void test_get_parameter_ampersand() throws Exception {
        String queryString = "index=values[Test Text] & q=values[foo]=\"Fizz & Buzz\" ";
        Map <String, String> parameterMap = parser.getParameters(queryString);
        
        Map <String, String> constantMap = new HashMap<>();
        constantMap.put("index", "values[Test Text]");
        constantMap.put("q", "values[foo]=\"Fizz & Buzz\"");
        
        assertEquals(parameterMap, constantMap);;
    }
    
    @Test
    public void test_get_parameter_multi_index_ampersand() throws Exception {
        String queryString = "index=values[foo],values[bar]&"
            + "q=values[foo]=\"Fizz %26 Buzz\" AND values[bar]=\"\"";
        Map <String, String> parameterMap = parser.getParameters(queryString);
        
        Map <String, String> constantMap = new HashMap<>();
        constantMap.put("index", "values[foo],values[bar]");
        constantMap.put("q", "values[foo]=\"Fizz & Buzz\" AND values[bar]=\"\"");
        
        assertEquals(parameterMap, constantMap);;
    }
    
    @Test
    public void test_get_parameter_ampersand_field_name() throws Exception {
        String queryString = "index=values[foo &]&"
            + "q=values[foo &]=\"bazz\"";
        Map <String, String> parameterMap = parser.getParameters(queryString);
        
        Map <String, String> constantMap = new HashMap<>();
        constantMap.put("index", "values[foo &]");
        constantMap.put("q", "values[foo &]=\"bazz\"");
        
        assertEquals(parameterMap, constantMap);;
    }
    
    @Test
    public void test_get_parameter_hardcoded_ampersand() throws Exception {
        String queryString = "index=values[foo],values[bar]&"
            + "q=values[foo]=\"Fizz & Buzz\" AND values[bar]=\"Cat & Dog\"";
        Map <String, String> parameterMap = parser.getParameters(queryString);
        
        Map <String, String> constantMap = new HashMap<>();
        constantMap.put("index", "values[foo],values[bar]");
        constantMap.put("q", "values[foo]=\"Fizz & Buzz\" AND values[bar]=\"Cat & Dog\"");
        
        // Assertion should fail because hardcoded '&' that are used as parameters
        // are not supported.
        assertNotEquals(parameterMap, constantMap);
        
        queryString = "index=values[foo],values[bar]&"
            + "q=values[foo]=\"Fizz %26 Buzz\" AND values[bar]=\"Cat %26 Dog\"";
        parameterMap = parser.getParameters(queryString);
        
        assertEquals(parameterMap, constantMap);;
    }
    
    @Test
    public void test_get_parameter_none() throws Exception {
        String queryString = "";
        Map <String, String> parameterMap = parser.getParameters(queryString);
        
        assertTrue(parameterMap.isEmpty());
    }
}
