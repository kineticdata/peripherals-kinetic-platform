package com.kineticdata.bridgehub.adapter.kineticcore;

import com.kineticdata.bridgehub.adapter.BridgeError;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.apache.commons.lang.StringUtils;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;

/**
 *
 */
public class FilterUtils {
    
    private static final Pattern ATTR_PATTERN = Pattern.compile("(.*?)\\[(.*?)\\]");
    
    private static Pattern getPatternFromValue(String value) {
        // Escape regex characters from value
        String[] parts = value.split("(?<!\\\\)%");
        for (int i = 0; i<parts.length; i++) {
            if (!parts[i].isEmpty()) parts[i] = Pattern.quote(parts[i].replaceAll("\\\\%","%"));
        }
        String regex = StringUtils.join(parts,".*?");
        if (!value.isEmpty() && value.substring(value.length() - 1).equals("%")) regex += ".*?";
        return Pattern.compile("^"+regex+"$",Pattern.CASE_INSENSITIVE);
    }

    private static Object getChildValues(String type, String name, JSONObject submission) throws BridgeError {
        if (!submission.containsKey(type)) throw new BridgeError(String.format("The field '%s' cannot be found on the Submission object",type));
        Object child = submission.get(type);
        if (child instanceof JSONArray) {
            JSONArray attributes = (JSONArray)child;
            for (Object attribute : attributes) {
                HashMap attributeMap = (HashMap)attribute;
                if (((String)attributeMap.get("name")).equals(name)) {
                    return (List)attributeMap.get("values");
                }
            }
            return new ArrayList(); // Return an empty array list if nothing else was returned
        } else if (child instanceof JSONObject) {
            JSONObject values = (JSONObject)child;
            return values.get(name);
        } else {
            return child;
        }
    }
    
    protected static final JSONArray filterSubmissions(JSONArray submissions, String query) throws BridgeError {
        if (query.isEmpty()) return submissions;
        String[] queryParts = query.split("&");

        Map<String[],Object[]> queryMatchers = new HashMap<String[],Object[]>();
        // Variables used for OR query (pattern and fields)
        String pattern = null;
        String[] fields = null;
        // Iterate through the query parts and create all the possible matchers to check against
        // the user results
        for (String part : queryParts) {
            String[] split = part.split("=");
            String field = split[0].trim();
            String value = split.length > 1 ? split[1].trim() : "";

            Object[] matchers;
            if (field.equals("pattern")) {
                pattern = value;
            } else if (field.equals("fields")) {
                fields = value.split(",");
            } else {
                // If the field isn't 'pattern' or 'fields', add the field and appropriate values
                // to the query matcher
                if (value.equals("true") || value.equals("false")) {
                    matchers = new Object[] { getPatternFromValue(value), Boolean.valueOf(value) };
                } else if (value.equals("null")) {
                    matchers = new Object[] { null, getPatternFromValue(value) };
                } else if (value.isEmpty()) {
                    matchers = new Object[] { "" };
                } else {
                    matchers = new Object[] { getPatternFromValue(value) };
                }
                queryMatchers.put(new String[] { field }, matchers);
            }
        }

        // If both query and pattern are not equal to null, add the list of fields and the
        // pattern (compiled into a regex Pattern object) to the queryMatchers map
        if (pattern != null && fields != null) {
            queryMatchers.put(fields,new Object[] { Pattern.compile(".*"+Pattern.quote(pattern)+".*",Pattern.CASE_INSENSITIVE) });
        }
        // If both pattern & fields are not equals to null AND both pattern & fields are not
        // both null, that means that one is null and the other is not which is not an
        // allowed query.
        else if (pattern != null || fields != null) {
            throw new BridgeError("The 'pattern' and 'fields' parameter must be provided together.  When the 'pattern' parameter "+
                    "is provided the 'fields' parameter is required and when the 'fields' parameter is provided the 'pattern' parameter is required.");
        }

        // Start with a full list of submissions and then delete from the list when they don't match
        // a qualification. Will be left with a list of values that match all qualifications.
        JSONArray matchedSubmissions = submissions;
        for (Map.Entry<String[],Object[]> entry : queryMatchers.entrySet()) {
            JSONArray matchedSubmissionsEntry = new JSONArray();
            for (String field : entry.getKey()) {
                // If passed in field is an attribute, save its attributeName
                String attributeType = null;
                String attributeName = null;
                Matcher m = ATTR_PATTERN.matcher(field);
                if (m.find()) {
                    attributeType = m.group(1);
                    attributeName = m.group(2);
                }

                for (Object o : matchedSubmissions) {
                    JSONObject submission = (JSONObject)o;
                    // Check if the object matches the field qualification if it hasn't already been
                    // successfully matched
                    if (!matchedSubmissionsEntry.contains(o)) {
                        // Get the value for the field
                        List fieldValues;
                        if (attributeName != null) {
                            Object childValues = getChildValues(attributeType,attributeName,submission);
                            if (childValues instanceof List) {
                                fieldValues = (List)childValues;
                            } else {
                                fieldValues = Arrays.asList(new Object[] { childValues });
                            }
                        } else {
                            fieldValues = Arrays.asList(new Object[] { submission.get(field) });
                        }

                        // if field values is empty, check for an empty value
                        if (fieldValues.isEmpty()) {
                            for (Object value : entry.getValue()) {
                                if (value.equals("")) matchedSubmissionsEntry.add(o);
                            }
                        } else {
                            for (Object fieldValue : fieldValues) {
                                for (Object value : entry.getValue()) {
                                    if (fieldValue == value || // Objects equal
                                       fieldValue != null && value != null && (
                                           value.getClass() == Pattern.class && ((Pattern)value).matcher(fieldValue.toString()).matches() || // fieldValue != null && Pattern matches
                                           value.equals(fieldValue) // fieldValue != null && values equal
                                       )
                                    ) {
                                        matchedSubmissionsEntry.add(o);
                                    }
                                }
                            }
                        }
                    }
                }
            }
            matchedSubmissions = (JSONArray)matchedSubmissionsEntry;
        }

        return matchedSubmissions;
    }
}
