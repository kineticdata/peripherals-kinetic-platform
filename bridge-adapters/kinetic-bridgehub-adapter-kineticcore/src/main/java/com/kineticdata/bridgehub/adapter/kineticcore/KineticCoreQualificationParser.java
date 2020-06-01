package com.kineticdata.bridgehub.adapter.kineticcore;

import com.kineticdata.bridgehub.adapter.BridgeError;
import com.kineticdata.bridgehub.adapter.BridgeRequest;
import java.util.Map;

import com.kineticdata.bridgehub.adapter.QualificationParser;
import java.net.URLEncoder;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import org.apache.commons.lang.StringUtils;

/**
 *
 */
public class KineticCoreQualificationParser extends QualificationParser {

    // A list of field that should be parsed out of a query
    private static final List<String> SUBMISSION_QUERY_PARSE_FIELDS = Arrays.asList(
        "formSlug","kappSlug","parent","ancestor","limit"//,"coreState"
    );

    public String encodeParameter(String name, String value) {
        return value;
    }

    protected Map<String,String> parseSubmissionQuery(BridgeRequest request) throws BridgeError {
        Map<String,String> parsedQuery = new HashMap<String,String>();
        StringBuilder queryString = new StringBuilder();
        StringBuilder encodedQueryString = new StringBuilder();
        // Split into individual queries by splitting on the & between each distinct query
        String[] queries = request.getQuery().split("&(?=[^&]*?=)");
        for (String query : queries) {
            // Split the query on the = to determine the field/value key-pair. Anything before the
            // first = is considered to be the field and anything after (including more = signs if
            // there are any) is considered to be part of the value
            String[] str_array = query.split("=");
            String field = str_array[0].trim();
            String value = "";
            if (str_array.length > 1) value = StringUtils.join(Arrays.copyOfRange(str_array, 1, str_array.length),"=");

            // Separate any values that shouldn't be passed to the serverSideQuery (or that need to
            // be selectively modified before being passed to the query) and concatenate the rest
            if (SUBMISSION_QUERY_PARSE_FIELDS.contains(field)) {
                parsedQuery.put(field,value);
            } else {
                if (queryString.length() != 0) {
                    queryString.append("&");
                    encodedQueryString.append("&");
                }
                queryString.append(field).append("=").append(value.trim());
                encodedQueryString.append(URLEncoder.encode(field)).append("=");
                encodedQueryString.append(URLEncoder.encode(value.trim()));
            }
        }
        // Throw any errors that have been caught during the parsing of the query
        if (parsedQuery.containsKey("parent") && parsedQuery.containsKey("ancestor")) {
            throw new BridgeError("Invalid Query: The bridge query cannot contain both 'parent' and 'ancestor'.");
        }
        if (!parsedQuery.containsKey("parent") && !parsedQuery.containsKey("ancestor") && !parsedQuery.containsKey("kappSlug")) {
            throw new BridgeError("Invalid Query: The bridge query needs to include a kappSlug.");
        }
        // Add both to the parsedQuery map
        parsedQuery.put("query",queryString.toString());
        parsedQuery.put("encodedQuery",encodedQueryString.toString());
        return parsedQuery;
    }
}