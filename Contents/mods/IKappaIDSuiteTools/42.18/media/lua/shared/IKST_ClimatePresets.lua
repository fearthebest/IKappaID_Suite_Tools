require "IKST_Shared"

IKST_ClimatePresets = IKST_ClimatePresets or {}

-- Matches vanilla ISAdmPanelClimate float indices.
IKST_ClimatePresets.FLOAT = {
    desat = 0,
    night = 2,
    rain = 3,
    fog = 5,
    wind = 6,
    cloud = 8,
}

IKST_ClimatePresets.WEATHER = {
    Clear = { rain = 0, cloud = 0, fog = 0, wind = 0 },
    Rain = { rain = 0.6, cloud = 0.8, fog = 0.1, wind = 0.4 },
    Storm = { rain = 1.0, cloud = 1.0, fog = 0.2, wind = 0.85 },
    Fog = { rain = 0, cloud = 0.4, fog = 0.85, wind = 0.1 },
}

function IKST_ClimatePresets.climateMgr()
    if getClimateManager then
        return getClimateManager()
    end
    local world = getWorld and getWorld()
    if world and world.getClimateManager then
        return world:getClimateManager()
    end
    return nil
end

function IKST_ClimatePresets.releaseClimate()
    local cm = IKST_ClimatePresets.climateMgr()
    if not cm then
        return false
    end
    for _, idx in pairs(IKST_ClimatePresets.FLOAT) do
        if cm.getClimateFloat then
            local f = cm:getClimateFloat(idx)
            if f and f.setEnableAdmin then
                f:setEnableAdmin(false)
            end
        end
    end
    return true
end

function IKST_ClimatePresets.setClimateFloat(idx, value)
    local cm = IKST_ClimatePresets.climateMgr()
    if not cm or not cm.getClimateFloat then
        return false
    end
    local f = cm:getClimateFloat(idx)
    if not f or not f.setEnableAdmin or not f.setAdminValue then
        return false
    end
    f:setEnableAdmin(true)
    f:setAdminValue(value)
    return true
end

function IKST_ClimatePresets.transmitClimate()
    local cm = IKST_ClimatePresets.climateMgr()
    if cm and cm.transmitClientChangeAdminVars then
        cm:transmitClientChangeAdminVars()
    end
end

function IKST_ClimatePresets.applyPreset(presetName)
    local preset = IKST_ClimatePresets.WEATHER[presetName]
    if not preset then
        return false, "unknown weather"
    end
    IKST_ClimatePresets.releaseClimate()
    local applied = 0
    for key, value in pairs(preset) do
        local idx = IKST_ClimatePresets.FLOAT[key]
        if idx and IKST_ClimatePresets.setClimateFloat(idx, value) then
            applied = applied + 1
        end
    end
    if applied == 0 then
        return false, "climate unavailable"
    end
    IKST_ClimatePresets.transmitClimate()
    return true, presetName .. " weather"
end

function IKST_ClimatePresets.clearWeather()
    IKST_ClimatePresets.releaseClimate()
    local cm = IKST_ClimatePresets.climateMgr()
    if not cm then
        return false, "climate unavailable"
    end
    if type(isClient) == "function" and isClient() and IKST.isMultiplayerSession() and cm.transmitStopWeather then
        cm:transmitStopWeather()
    else
        if cm.stopWeatherAndThunder then
            cm:stopWeatherAndThunder()
        end
        if IKST.isMultiplayerSession() and cm.transmitServerStopWeather then
            cm:transmitServerStopWeather()
        end
    end
    IKST_ClimatePresets.transmitClimate()
    return true, "Weather cleared"
end
