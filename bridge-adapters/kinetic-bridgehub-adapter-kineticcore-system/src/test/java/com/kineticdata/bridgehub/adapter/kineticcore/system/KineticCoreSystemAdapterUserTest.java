package com.kineticdata.bridgehub.adapter.kineticcore.system;

import com.kineticdata.bridgehub.adapter.BridgeAdapterTestBase;

/**
 *
 */
public class KineticCoreSystemAdapterUserTest extends BridgeAdapterTestBase {

    @Override
    public String getConfigFilePath() {
        return "src/test/resources/bridge-config-user.yml";
    }
    
    @Override
    public Class getAdapterClass() {
        return KineticCoreSystemAdapter.class;
    }
}
