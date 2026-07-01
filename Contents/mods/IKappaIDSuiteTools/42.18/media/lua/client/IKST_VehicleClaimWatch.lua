-- Deprecated: server enforces claims (IKST_GuardOps.enforceVehicleClaim);
-- client uses IKST_VehicleClaimHooks for timed actions and engine watchdog.

if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"

IKST_VehicleClaimWatch = IKST_VehicleClaimWatch or {}
