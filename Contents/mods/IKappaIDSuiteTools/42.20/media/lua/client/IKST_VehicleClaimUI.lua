if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_ClaimPermissionsUI"

IKST_VehicleClaimUI = IKST_VehicleClaimUI or {}
IKST_VehicleClaimUI.instance = nil

function IKST_VehicleClaimUI.close()
    IKST_ClaimPermissionsUI.close()
    IKST_VehicleClaimUI.instance = nil
end

function IKST_VehicleClaimUI.open(player, vehicleId)
    IKST_ClaimPermissionsUI.openVehicle(player, vehicleId)
    IKST_VehicleClaimUI.instance = IKST_ClaimPermissionsUI.instance
end
