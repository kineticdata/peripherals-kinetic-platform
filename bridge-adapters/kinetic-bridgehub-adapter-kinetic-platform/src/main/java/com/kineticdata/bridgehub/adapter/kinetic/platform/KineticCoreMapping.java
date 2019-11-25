package com.kineticdata.bridgehub.adapter.kinetic.platform;

import com.kineticdata.bridgehub.adapter.BridgeError;
import java.util.ArrayList;
import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
  * This class is used to define valid Structures.
  *  Properties:
  *      String structure - name of a model of data.
  *      String plural - property name accessor when multiple results returned
  *      String plural - property name accessor when single result returned
  *      Set<String> implicitIncludes - additions placed on the parameters of
  *          the request to source system.
  *      PaginationPredicate paginationPredicate - method called to determine
  *          if request may be paginated server side.
  */
public class KineticCoreMapping {
    private final String structure;
    private final String plural;
    private final String singular;
    private final Set<String> implicitIncludes;
    private final List<String> paginationFields;
    private final PaginationPredicate paginationPredicate;
    private final PathBuilder pathBuilder;

    public KineticCoreMapping(String structure, String plural, String singular, 
        Collection<String> implicitIncludes, 
        PaginationPredicate paginationPredicate, PathBuilder pathBuilder) {

        this.paginationFields = null;
        this.structure = structure;
        this.plural = plural;
        this.singular = singular;
        this.implicitIncludes = new LinkedHashSet<>(implicitIncludes);
        this.paginationPredicate = paginationPredicate;
        this.pathBuilder = pathBuilder;
    }

    public KineticCoreMapping(String structure, String plural, String singular, 
        Collection<String> implicitIncludes, 
        Collection<String> paginationFields,
        PaginationPredicate paginationPredicate, PathBuilder pathBuilder) {

        this.structure = structure;
        this.plural = plural;
        this.singular = singular;
        this.implicitIncludes = new LinkedHashSet<>(implicitIncludes);
        this.paginationFields = new ArrayList<>(paginationFields);
        this.paginationPredicate = paginationPredicate;
        this.pathBuilder = pathBuilder;
    }
    
    /**
    * Interfaces for mappings.
    */
    @FunctionalInterface
    public static interface PaginationPredicate {
        boolean apply(List<String> paginationFields, Map<String, String> parameters,
            LinkedHashMap<String, String> sortOrderItems);
    }


    @FunctionalInterface
    public static interface PathBuilder {
        String apply(String[] structureArray, Map<String, String> parameters) 
           throws BridgeError;
    }


    public String getStructure() {
        return structure;
    }

    public String getPlural() {
        return plural;
    }

    public String getSingular() {
        return singular;
    }

    public Set<String> getImplicitIncludes() {
        return implicitIncludes;
    }

    public List<String> getPaginationFields() {
        return paginationFields;
    }

    public PaginationPredicate getPaginationPredicate() {
        return paginationPredicate;
    }
    
    public PathBuilder getPathBuilder(){
        return pathBuilder;
    }
}
