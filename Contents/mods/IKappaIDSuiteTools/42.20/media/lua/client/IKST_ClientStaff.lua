if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_ClimatePresets"
require "IKST_VehicleMirror"
require "IKST_StaffCheats"

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
    if not IKST_ClientStaff.mayRunWeather(player) then
        return
    end
    -- MP: client requests only; server commits and mirrors.
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        IKST.dispatchCommand(player, IKST.CMD.setWeather, { preset = preset })
        return
    end
    -- SP / non-MP: local sim is the authority.
    if not IKST_ClimatePresets then
        require "IKST_ClimatePresets"
    end
    local ok, msg = IKST_ClimatePresets.applyPreset(preset)
    if msg then
        IKST.notify(player, msg, ok == true)
    end
end

function IKST_ClientStaff.runClearWeather(player)
    player = IKST.resolvePlayer(player)
    if not player then
        return
    end
    if not IKST_ClientStaff.mayRunWeather(player) then
        return
    end
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        IKST.dispatchCommand(player, IKST.CMD.clearWeather, {})
        return
    end
    if not IKST_ClimatePresets then
        require "IKST_ClimatePresets"
    end
    local ok, msg = IKST_ClimatePresets.clearWeather()
    if msg then
        IKST.notify(player, msg, ok == true)
    end
end

function IKST_ClientStaff.runSetTime(player, hour)
    -- Always request; server sets GameTime. Clients never choose the hour themselves.
    IKST.dispatchCommand(player, IKST.CMD.setTime, { hour = hour })
end

-- Engine PlayerCheats only. SP without -debug: setGodMod/setInvisible/setNoClip are no-ops.
-- MP uses forced sync (on, true). SP with -debug uses (on, false).
function IKST_ClientStaff.applyPlayerModes(player, args)
    player = IKST_ClientStaff.resolveLocalPlayer(player)
    if not player or not args then
        return
    end
    local mp = IKST.isMultiplayerSession and IKST.isMultiplayerSession()
    local function setMode(setFnName, on)
        if type(player[setFnName]) ~= "function" then
            return
        end
        on = on == true
        if mp then
            player[setFnName](player, on, true)
        else
            player[setFnName](player, on, false)
        end
    end
    if args.god ~= nil then
        setMode("setGodMod", args.god)
    end
    if args.ghost ~= nil then
        setMode("setGhostMode", args.ghost)
    end
    if args.noclip ~= nil then
        setMode("setNoClip", args.noclip)
    elseif args.ghost ~= nil then
        setMode("setNoClip", args.ghost)
    end
    if args.invisible ~= nil then
        setMode("setInvisible", args.invisible)
    end
end

function IKST_ClientStaff.applyVehicleSync(args)
    if IKST_VehicleMirror and IKST_VehicleMirror.applyServerState then
        IKST_VehicleMirror.applyServerState(args)
    end
end

function IKST_ClientStaff.resolveLocalPlayer(player)
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        if getSpecificPlayer then
            local localPlayer = getSpecificPlayer(0)
            if localPlayer then
                return localPlayer
            end
        end
    end
    player = IKST.resolvePlayer(player)
    if not player then
        return nil
    end
    if player.isLocalPlayer and not player:isLocalPlayer() then
        return nil
    end
    return player
end

function IKST_ClientStaff.applySelfCheatLocal(player, cheatId, on)
    player = IKST_ClientStaff.resolveLocalPlayer(player)
    if not player then
        return
    end
    if IKST_StaffCheats and IKST_StaffCheats.setStored then
        IKST_StaffCheats.setStored(player, cheatId, on)
    end
    if IKST_StaffCheats and IKST_StaffCheats.apply then
        IKST_StaffCheats.apply(player, cheatId, on)
    end
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
    local vehicle = type(player.getVehicle) == "function" and player:getVehicle()
    if vehicle and type(vehicle.exit) == "function" then
        vehicle:exit(player)
    end
    if type(player.teleportTo) == "function" then
        player:teleportTo(x, y, z)
    else
        player:setX(x)
        player:setY(y)
        player:setZ(z)
        if type(player.setLastX) == "function" then
            player:setLastX(x)
            player:setLastY(y)
        end
        if type(player.setLastZ) == "function" then
            player:setLastZ(z)
        end
    end
end

if Events and Events.OnEnterVehicle and Events.OnEnterVehicle.Add then
    Events.OnEnterVehicle.Add(function(character)
        if IKST_VehicleMirror and IKST_VehicleMirror.onEnterVehicle then
            IKST_VehicleMirror.onEnterVehicle(character)
        end
    end)
end
