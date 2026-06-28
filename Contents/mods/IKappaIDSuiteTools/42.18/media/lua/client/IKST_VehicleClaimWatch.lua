-- Backup vehicle enforcement if a timed action slips past IKST_Enforcement.

if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_VehicleClaim"

IKST_VehicleClaimWatch = IKST_VehicleClaimWatch or {}
IKST_VehicleClaimWatch._tick = 0

function IKST_VehicleClaimWatch.notifyDenied(player)
    if not player then
        return
    end
    IKST.notify(player, IKST.text("IGUI_IKST_Claim_VehicleDenied", "This vehicle is claimed by another player."), false)
end

function IKST_VehicleClaimWatch.onPlayerUpdate(player)
    if not player or not player.isLocalPlayer or not player:isLocalPlayer() then
        return
    end
    IKST_VehicleClaimWatch._tick = IKST_VehicleClaimWatch._tick + 1
    if IKST_VehicleClaimWatch._tick % 15 ~= 0 then
        return
    end
    if not player.getVehicle then
        return
    end
    local vehicle = player:getVehicle()
    if not vehicle then
        return
    end
    if not IKST_VehicleClaim.canUseVehicle(player, vehicle, "enter") then
        if vehicle.shutOff then
            vehicle:shutOff()
        end
        if vehicle.exit then
            vehicle:exit(player)
        end
        IKST_VehicleClaimWatch.notifyDenied(player)
        return
    end
    if vehicle.isEngineRunning and vehicle:isEngineRunning() then
        if not IKST_VehicleClaim.canUseVehicle(player, vehicle, "engine") then
            if vehicle.shutOff then
                vehicle:shutOff()
            end
        end
    end
end

if Events and Events.OnPlayerUpdate then
    Events.OnPlayerUpdate.Add(IKST_VehicleClaimWatch.onPlayerUpdate)
end
