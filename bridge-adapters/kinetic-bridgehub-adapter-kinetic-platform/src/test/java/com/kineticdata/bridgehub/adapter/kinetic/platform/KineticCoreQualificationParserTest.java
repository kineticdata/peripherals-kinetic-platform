package com.kineticdata.bridgehub.adapter.kinetic.platform;

import com.kineticdata.bridgehub.adapter.kinetic.platform.KineticCoreQualificationParser;
import java.util.HashMap;
import org.junit.Before;
import org.junit.Test;
import java.util.LinkedHashMap;
import java.util.Map;
import static org.junit.Assert.assertEquals;
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
    public void test_get_parameter_none() throws Exception {
        String queryString = "";
        Map <String, String> parameterMap = parser.getParameters(queryString);
        
        assertTrue(parameterMap.isEmpty());
    }
}
