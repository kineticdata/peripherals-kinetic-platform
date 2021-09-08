package com.kineticdata.bridgehub.adapter.kinetic.platform;

import com.kineticdata.bridgehub.adapter.BridgeError;
import com.kineticdata.bridgehub.adapter.QualificationParser;
import java.util.HashMap;
import java.util.Map;
import java.util.stream.Collectors;
import org.slf4j.LoggerFactory;

/**
 * This class is has helpers used to parser the qualification mapping value. 
 */
public class KineticCoreQualificationParser extends QualificationParser {
    /** 
     * Temporarily encoding '&' in request parameters to fix KP-3631.  This prevents
     * getParameters method from splitting on ampersands that are in parameter values.
     */
    private static final String TEMP_ENCODED_AMPERSAND = "%26";
    
    /** Defines the logger */
    protected static final org.slf4j.Logger logger 
        = LoggerFactory.getLogger(KineticCoreAdapter.class);
    
    protected Map<String, String> getParameters (String queryString)
        throws BridgeError {
      
        Map<String, String> parameters = new HashMap<>();
        
        // Return empyt map if no query was provided from reqeust.
        if (!queryString.isEmpty()) {
            // Regex allows for & to be in field names.
            String[] queries = queryString.split("&(?=[^&]*?=)");
            for (String query : queries) {
                // Split the query on the = to determine the field/value key-pair. 
                // Anything before the first = is considered to be the field and 
                // anything after (including more = signs if there are any) is 
                // considered to be part of the value
                String[] str_array = query.split("=",2);
                if (str_array.length == 2) {
                    parameters.merge(str_array[0].trim(), str_array[1].trim(), 
                        (prev, curr) -> {
                            return String.join(",", prev, curr);
                        }
                    );
                } else if (str_array.length == 1) {
                    parameters.put(str_array[0].trim(), null);
                } else {
                    logger.debug("%s has a parameter that was unexpected.",
                        queryString);
                }
            }
        }

        parameters = parameters.entrySet().stream()
            .collect(Collectors.toMap(
                    Map.Entry::getKey, 
                    entry -> entry.getValue().replaceAll(TEMP_ENCODED_AMPERSAND, "&")
            ));
        
        return parameters;
    }
    
    @Override
    public String encodeParameter(String name, String value) {
        String result = null;
        if (value != null) {
            result = value.replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("&", TEMP_ENCODED_AMPERSAND);
        }
        return result;
    }
}