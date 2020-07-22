package com.kineticdata.bridgehub.adapter.kineticcore.system;

import com.kineticdata.bridgehub.adapter.QualificationParser;

/**
 *
 */
public class KineticCoreSystemQualificationParser extends QualificationParser {
    public String encodeParameter(String name, String value) {
        return value;
    }
}