package com.kineticdata.bridgehub.adapter.kinetictask;

import com.kineticdata.bridgehub.adapter.QualificationParser;

/**
 *
 */
public class KineticTaskQualificationParser extends QualificationParser {
    public String encodeParameter(String name, String value) {
        return value;
    }
}