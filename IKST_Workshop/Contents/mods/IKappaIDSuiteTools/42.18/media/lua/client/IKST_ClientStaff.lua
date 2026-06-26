if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_ClimatePresets"

IKST_ClientStaff = IKST_ClientStaff or {}

function IKST_ClientStaff.runWeather(player, preset)
    player = IKST.resolvePlayer(player)
    if not player or not preset then
        return
    end
    if type(isClient) == "function" and isClient() then
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
