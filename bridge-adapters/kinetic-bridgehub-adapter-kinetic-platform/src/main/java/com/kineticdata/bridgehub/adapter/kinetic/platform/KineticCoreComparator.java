package com.kineticdata.bridgehub.adapter.kinetic.platform;

import com.kineticdata.bridgehub.adapter.Record;
import java.util.Comparator;
import java.util.Map;

/**
 * This class compares Records for adapter side sorting.
 */
public class KineticCoreComparator implements Comparator<Record> {

  private final Map<String, String> sortOrderItems;

  public KineticCoreComparator(Map<String, String> sortOrderItems) {
    this.sortOrderItems = sortOrderItems;
  }

  @Override
  public int compare(Record r1, Record r2) {
    int result = 0;

    for (Map.Entry<String,String> sortOrderItem : sortOrderItems.entrySet()) {
        String fieldName = sortOrderItem.getKey();
        boolean isAscending = "asc".equals(sortOrderItem.getValue().toLowerCase());
        
        String r1Value = normalize(r1.getValue(fieldName));
        String r2Value = normalize(r2.getValue(fieldName));
        
        // Order based on field direction specified
        int fieldComparison = (isAscending)
            ? r1Value.compareTo(r2Value)
            : r2Value.compareTo(r1Value);
        if (fieldComparison != 0) {
            result = fieldComparison;
            break;
        }
    }

    return result;
  }

  protected String normalize(Object string) {
    String result;
    if (String.valueOf(string) == null) {
      result = "";
    } else {
      result = String.valueOf(string);
    }
    return result;
  }

}
