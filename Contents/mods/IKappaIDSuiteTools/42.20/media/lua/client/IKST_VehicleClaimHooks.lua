-- Vehicle claim engine watchdog (timed-action wraps live in IKST_Enforcement).
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Authority"
require "IKST_VehicleClaim"
require "IKST_Access"

IKST_VehicleClaimHooks = IKST_VehicleClaimHooks or {}
IKST_VehicleClaimHooks._engineTick = 0

function IKST_VehicleClaimHooks.notifyDenied(player)
    if not player then
        return
    end
    IKST.notify(player, IKST.text("IGUI_IKST_Claim_VehicleDenied", "This vehicle is claimed by another player."), false)
end

function IKST_VehicleClaimHooks.engineWatchdog(player)
    if IKST_Authority and IKST_Authority.clientReadsMirroredStateOnly
        and IKST_Authority.clientReadsMirroredStateOnly() then
        return
    end
    if not player or not player.isLocalPlayer or not player:isLocalPlayer() then
        return
    end
    if type(player.getVehicle) ~= "function" then
        return
    end
    local vehicle = player:getVehicle()
    if not vehicle then
        return
    end
    if not IKST_VehicleClaim.canUseVehicle(player, vehicle, "enter") then
        if type(vehicle.shutOff) == "function" then
            vehicle:shutOff()
        end
        if type(vehicle.exit) == "function" and player then
            vehicle:exit(player)
        end
        IKST_VehicleClaimHooks.notifyDenied(player)
        return
    end
    if type(vehicle.isEngineRunning) == "function" and vehicle:isEngineRunning() then
        if not IKST_VehicleClaim.canUseVehicle(player, vehicle, "engine") then
            if type(vehicle.shutOff) == "function" then
                vehicle:shutOff()
            end
        end
    end
end

function IKST_VehicleClaimHooks.onPlayerUpdate(player)
    IKST_VehicleClaimHooks._engineTick = IKST_VehicleClaimHooks._engineTick + 1
    if IKST_VehicleClaimHooks._engineTick % 15 ~= 0 then
        return
    end
    IKST_VehicleClaimHooks.engineWatchdog(player)
end

if Events and Events.OnPlayerUpdate then
    Events.OnPlayerUpdate.Add(IKST_VehicleClaimHooks.onPlayerUpdate)
end
