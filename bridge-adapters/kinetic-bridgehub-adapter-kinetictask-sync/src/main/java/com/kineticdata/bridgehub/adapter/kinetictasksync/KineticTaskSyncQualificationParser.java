package com.kineticdata.bridgehub.adapter.kinetictasksync;

import com.kineticdata.bridgehub.adapter.BridgeRequest;
import com.kineticdata.bridgehub.adapter.QualificationParser;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;
import org.apache.commons.lang.StringUtils;
import org.slf4j.LoggerFactory;

public class KineticTaskSyncQualificationParser extends QualificationParser {
    /** Defines the logger */
    protected static final org.slf4j.Logger logger 
        = LoggerFactory.getLogger(KineticTaskSyncAdapter.class);
    
    public Map<String,ArrayList<String>> parseQuery(String queryString) {
        Map<String,ArrayList<String>> parsedQuery 
            = new HashMap<String,ArrayList<String>>();
        
        logger.trace("The query to be parsed: " + queryString);
        
        // Split the tree name from the rest of the query
        String[] parts = queryString.split("[?]",2);
        ArrayList<String> partsList = new ArrayList(Arrays.asList(parts));
        if (partsList.size() > 0 && !partsList.get(0).contains("=")) {
            parsedQuery.put("treeName", new ArrayList<String>());
            parsedQuery.get("treeName").add(parts[0]);
            partsList.remove(0);
        }
        
         
        if (partsList.size() > 0) {
            // Split into individual queries by splitting on the & between each 
            // distinct query
            String[] queries = partsList.get(0).split("[&]");

            for (String query : queries) {
                // Split the query on the = to determine the field/value key-pair.
                // Anything before the first = is considered to be the field and
                // anything after (including more = signs if there are any) is 
                // considered to be part of the value.
                String[] str_array = query.split("=");
                String field = str_array[0].trim();
                String value = "";
                if (str_array.length > 1) value = StringUtils
                    .join(Arrays.copyOfRange(str_array, 1, str_array.length),"=");

                if (parsedQuery.get(field) == null) {
                    parsedQuery.put(field, new ArrayList<String>());
                }
                parsedQuery.get(field).add(value);
            }
        }    
        return parsedQuery;
            
    }
    
    public String encodeParameter(String name, String value) {
        return value;
    }
}
