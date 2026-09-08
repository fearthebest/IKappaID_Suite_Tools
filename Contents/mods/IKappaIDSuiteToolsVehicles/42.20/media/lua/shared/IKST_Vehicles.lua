require "IKST_Shared"

IKST_Vehicles = IKST_Vehicles or {}

function IKST_Vehicles.remoteListMinDistance()
    local sv = SandboxVars and SandboxVars.IKappaIDSuiteToolsVehicles
    local n = math.floor(tonumber(sv and sv.VehicleRemoteListMinDistance) or 10)
    if n < 3 then
        n = 3
    end
    if n > 50 then
        n = 50
    end
    return n
end
