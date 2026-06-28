if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_ClimatePresets"

IKST_ClientStaff = IKST_ClientStaff or {}

function IKST_ClientStaff.mayRunWeather(player)
    player = IKST.resolvePlayer(player)
    if not player then
        return false
    end
    if IKST_Access and IKST_Access.canUseStaffTools and not IKST_Access.canUseStaffTools(player) then
        IKST.notify(player, "not allowed", false)
        return false
    end
    return true
end

function IKST_ClientStaff.runWeather(player, preset)
    player = IKST.resolvePlayer(player)
    if not player or not preset then
        return
    end
    if type(isClient) == "function" and isClient() then
        if not IKST_ClientStaff.mayRunWeather(player) then
            return
        end
        local ok, msg = IKST_ClimatePresets.applyPreset(preset)
        if msg then
            IKST.notify(player, msg, ok == true)
        end
        return
    end
    IKST.dispatchCommand(player, IKST.CMD.setWeather, { preset = preset })
end

function IKST_ClientStaff.runClearWeather(player)
    player = IKST.resolvePlayer(player)
    if not player then
        return
    end
    if type(isClient) == "function" and isClient() then
        if not IKST_ClientStaff.mayRunWeather(player) then
            return
        end
        local ok, msg = IKST_ClimatePresets.clearWeather()
        if msg then
            IKST.notify(player, msg, ok == true)
        end
        return
    end
    IKST.dispatchCommand(player, IKST.CMD.clearWeather, {})
end

function IKST_ClientStaff.runSetTime(player, hour)
    IKST.dispatchCommand(player, IKST.CMD.setTime, { hour = hour })
end

function IKST_ClientStaff.applyTeleportLocal(player, x, y, z)
    player = IKST.resolvePlayer(player)
    if not player or not player.isLocalPlayer or not player:isLocalPlayer() then
        return
    end
    x = tonumber(x)
    y = tonumber(y)
    z = tonumber(z) or 0
    if not x or not y then
        return
    end
    local vehicle = player.getVehicle and player:getVehicle()
    if vehicle and type(vehicle.exit) == "function" then
        vehicle:exit(player)
    end
    if type(player.teleportTo) == "function" then
        player:teleportTo(x, y, z)
    else
        player:setX(x)
        player:setY(y)
        player:setZ(z)
        if type(player.setLx) == "function" then
            player:setLx(x)
            player:setLy(y)
        end
        if type(player.setLz) == "function" then
            player:setLz(z)
        end
    end
end
