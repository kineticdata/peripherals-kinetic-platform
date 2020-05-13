package com.kineticdata.bridgehub.adapter.kinetictask;

import com.kineticdata.bridgehub.adapter.BridgeAdapterTestBase;
import com.kineticdata.bridgehub.adapter.BridgeRequest;
import org.junit.Ignore;
import org.junit.Test;

/**
 *
 */
public class KineticTaskAdapterTest extends BridgeAdapterTestBase {
    
    static String userRecordsMockData = null;

    @Override
    public String getConfigFilePath() {
        return "src/test/resources/bridge-config.yml";
    }
    
    @Override
    public Class getAdapterClass() {
        return KineticTaskAdapter.class;
    }
    
    @Test
    public void test_countRuns() throws Exception {
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Runs");
        request.setQuery("source=Kinetic Task");
        
        getAdapter().count(request);
    }
    
    @Override
    @Ignore("Ignoring because there isn't a good way to get an empty retrieve when searching by ids is required")
    public void test_emptyRetrieve() throws Exception {
    }
}
