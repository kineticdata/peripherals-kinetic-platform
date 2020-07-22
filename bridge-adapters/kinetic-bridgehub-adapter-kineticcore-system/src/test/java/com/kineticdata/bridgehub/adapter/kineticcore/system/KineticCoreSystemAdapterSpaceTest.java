package com.kineticdata.bridgehub.adapter.kineticcore.system;

import com.kineticdata.bridgehub.adapter.BridgeAdapterTestBase;

/**
 *
 */
public class KineticCoreSystemAdapterSpaceTest extends BridgeAdapterTestBase {

    @Override
    public String getConfigFilePath() {
        return "src/test/resources/bridge-config-space.yml";
    }
    
    @Override
    public Class getAdapterClass() {
        return KineticCoreSystemAdapter.class;
    }
}
