-- Weather preset helpers (split from IKST_StaffOps).
if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"

IKST_StaffOps = IKST_StaffOps or {}

function IKST_StaffOps.setWeather(presetName)
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        if IKST_Authority and not IKST_Authority.guardServerMutate() then
            return false, "server only"
        end
    end
    local cp = IKST_StaffOps.ensureClimatePresets()
    if cp and cp.applyPreset then
        local ok, msg = cp.applyPreset(presetName)
        if ok and IKST.isMultiplayerSession and IKST.isMultiplayerSession() and IKST_StaffOps.forEachOnline then
            IKST_StaffOps.forEachOnline(function(p)
                IKST.deliverClientCommand(p, IKST.CMD.weatherMirror, { preset = presetName })
            end)
        end
        return ok, msg
    end
    return false, "climate unavailable"
end

function IKST_StaffOps.clearWeather()
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        if IKST_Authority and not IKST_Authority.guardServerMutate() then
            return false, "server only"
        end
    end
    local cp = IKST_StaffOps.ensureClimatePresets()
    if cp and cp.clearWeather then
        local ok, msg = cp.clearWeather()
        if ok and IKST.isMultiplayerSession and IKST.isMultiplayerSession() and IKST_StaffOps.forEachOnline then
            IKST_StaffOps.forEachOnline(function(p)
                IKST.deliverClientCommand(p, IKST.CMD.weatherMirror, { clear = true })
            end)
        end
        return ok, msg
    end
    return false, "climate unavailable"
end
