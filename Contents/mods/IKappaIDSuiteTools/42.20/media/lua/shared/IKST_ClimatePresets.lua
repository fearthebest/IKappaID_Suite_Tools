require "IKST_Shared"
require "IKST_Authority"

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

-- MP: only the server JVM may commit climate. Clients request via commands / apply mirrors only.
function IKST_ClimatePresets.mayMutateAuthoritative()
    if IKST_Authority and type(IKST_Authority.guardServerMutate) == "function" then
        return IKST_Authority.guardServerMutate() == true
    end
    if IKST.isRemoteClient and IKST.isRemoteClient() then
        return false
    end
    if IKST.isListenHostClient and IKST.isListenHostClient() then
        return false
    end
    return true
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

-- Local display apply only (server-authored mirror). Never transmits.
function IKST_ClimatePresets.applyPresetLocal(presetName)
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
    return true, presetName .. " weather"
end

function IKST_ClimatePresets.clearWeatherLocal()
    IKST_ClimatePresets.releaseClimate()
    local cm = IKST_ClimatePresets.climateMgr()
    if not cm then
        return false, "climate unavailable"
    end
    if type(cm.stopWeatherAndThunder) == "function" then
        cm:stopWeatherAndThunder()
    end
    return true, "Weather cleared"
end

-- Snap clock + lighting for staff setTime / timeMirror (avoids ~20s climate lerp).
-- See GameTime.setTimeOfDay / setLastTimeOfDay and ClimateManager night/daylight.
-- Vanilla Darkness admin uses FLOAT_NIGHT_STRENGTH + FLOAT_DAYLIGHT_STRENGTH + FLOAT_AMBIENT
-- (ISAdmPanelClimate). setNightStrength alone is overwritten by the climate tick lerp.
function IKST_ClimatePresets.normalizeHour(hour)
    hour = tonumber(hour)
    if not hour then
        return nil
    end
    if hour < 0 then
        return 0
    end
    if hour >= 24 then
        return 23.99
    end
    return hour
end

function IKST_ClimatePresets.lightFloatIds()
    local night = 2
    local daylight = 11
    local ambient = 9
    if ClimateManager then
        night = ClimateManager.FLOAT_NIGHT_STRENGTH or night
        daylight = ClimateManager.FLOAT_DAYLIGHT_STRENGTH or daylight
        ambient = ClimateManager.FLOAT_AMBIENT or ambient
    end
    return { night = night, daylight = daylight, ambient = ambient }
end

function IKST_ClimatePresets.nightFactorForHour(hour)
    local cm = IKST_ClimatePresets.climateMgr()
    local dawn = 6
    local dusk = 21
    if cm and type(cm.getSeason) == "function" then
        local season = cm:getSeason()
        if season then
            if type(season.getDawn) == "function" then
                dawn = tonumber(season:getDawn()) or dawn
            end
            if type(season.getDusk) == "function" then
                dusk = tonumber(season:getDusk()) or dusk
            end
        end
    end
    local night = 0
    if hour < dawn or hour >= dusk then
        night = 1
    elseif hour < dawn + 1 then
        night = 1 - (hour - dawn)
    elseif hour > dusk - 1 then
        night = hour - (dusk - 1)
    end
    if night < 0 then
        return 0
    end
    if night > 1 then
        return 1
    end
    return night
end

function IKST_ClimatePresets.snapLightFloat(cm, idx, value)
    if not cm or type(cm.getClimateFloat) ~= "function" then
        return
    end
    local f = cm:getClimateFloat(idx)
    if not f then
        return
    end
    -- Jump the rendered value; climate otherwise eases Final toward the new TOD for many seconds.
    if type(f.setFinalValue) == "function" then
        f:setFinalValue(value)
    end
    if type(f.setEnableOverride) == "function" and type(f.setOverride) == "function" then
        f:setEnableOverride(true)
        -- inter 0 = immediate (ClimateFloat override blend), not a multi-second ease.
        f:setOverride(value, 0)
    end
end

function IKST_ClimatePresets.releaseDayNightOverrides()
    local cm = IKST_ClimatePresets.climateMgr()
    if not cm or type(cm.getClimateFloat) ~= "function" then
        return
    end
    local ids = IKST_ClimatePresets.lightFloatIds()
    for _, idx in pairs(ids) do
        local f = cm:getClimateFloat(idx)
        if f and type(f.setEnableOverride) == "function" then
            f:setEnableOverride(false)
        end
    end
end

function IKST_ClimatePresets.nowMs()
    if type(getTimestampMs) == "function" then
        return getTimestampMs()
    end
    if type(getTimeInMillis) == "function" then
        return getTimeInMillis()
    end
    return (os.time() or 0) * 1000
end

function IKST_ClimatePresets.snapDayNightVisual(hour)
    local cm = IKST_ClimatePresets.climateMgr()
    if not cm then
        return
    end
    local night = IKST_ClimatePresets.nightFactorForHour(hour)
    local ids = IKST_ClimatePresets.lightFloatIds()
    IKST_ClimatePresets.snapLightFloat(cm, ids.night, night)
    IKST_ClimatePresets.snapLightFloat(cm, ids.daylight, 1 - night)
    IKST_ClimatePresets.snapLightFloat(cm, ids.ambient, 1 - night)
    if type(cm.setNightStrength) == "function" then
        cm:setNightStrength(night)
    end
    if type(cm.setDayLightStrength) == "function" then
        cm:setDayLightStrength(1 - night)
    end
    -- Re-pin for a few seconds while climate/day-info settle, then release overrides.
    IKST_ClimatePresets._lightHoldHour = hour
    IKST_ClimatePresets._lightHoldUntil = IKST_ClimatePresets.nowMs() + 4000
    IKST_ClimatePresets.ensureLightHoldTick()
end

function IKST_ClimatePresets.onLightHoldTick()
    local untilMs = IKST_ClimatePresets._lightHoldUntil
    if not untilMs then
        IKST_ClimatePresets.releaseLightHoldTick()
        return
    end
    local hour = IKST_ClimatePresets._lightHoldHour
    if hour == nil then
        IKST_ClimatePresets._lightHoldUntil = nil
        IKST_ClimatePresets.releaseLightHoldTick()
        return
    end
    if IKST_ClimatePresets.nowMs() >= untilMs then
        IKST_ClimatePresets._lightHoldUntil = nil
        IKST_ClimatePresets._lightHoldHour = nil
        IKST_ClimatePresets.releaseDayNightOverrides()
        IKST_ClimatePresets.releaseLightHoldTick()
        return
    end
    -- Throttle re-pin; climate ticks are infrequent but can fight the snap.
    local tick = (IKST_ClimatePresets._lightHoldTick or 0) + 1
    IKST_ClimatePresets._lightHoldTick = tick
    if tick % 10 ~= 0 then
        return
    end
    local cm = IKST_ClimatePresets.climateMgr()
    if not cm then
        return
    end
    local night = IKST_ClimatePresets.nightFactorForHour(hour)
    local ids = IKST_ClimatePresets.lightFloatIds()
    IKST_ClimatePresets.snapLightFloat(cm, ids.night, night)
    IKST_ClimatePresets.snapLightFloat(cm, ids.daylight, 1 - night)
    IKST_ClimatePresets.snapLightFloat(cm, ids.ambient, 1 - night)
end

function IKST_ClimatePresets.releaseLightHoldTick()
    if not IKST_ClimatePresets._lightHoldHooked then
        return
    end
    if Events and Events.OnTick and Events.OnTick.Remove then
        Events.OnTick.Remove(IKST_ClimatePresets.onLightHoldTick)
    end
    IKST_ClimatePresets._lightHoldHooked = false
    IKST_ClimatePresets._lightHoldTick = 0
end

function IKST_ClimatePresets.ensureLightHoldTick()
    IKST_ClimatePresets._lightHoldTick = 0
    if IKST_ClimatePresets._lightHoldHooked then
        return
    end
    if not Events or not Events.OnTick or not Events.OnTick.Add then
        return
    end
    Events.OnTick.Add(IKST_ClimatePresets.onLightHoldTick)
    IKST_ClimatePresets._lightHoldHooked = true
end

function IKST_ClimatePresets.applyTimeOfDayLocal(hour)
    hour = IKST_ClimatePresets.normalizeHour(hour)
    if hour == nil then
        return false, "no hour"
    end
    local gt = getGameTime and getGameTime()
    if not gt or type(gt.setTimeOfDay) ~= "function" then
        return false, "no game time"
    end
    gt:setTimeOfDay(hour)
    -- Without this, lighting lerps from the old hour for many real seconds.
    if type(gt.setLastTimeOfDay) == "function" then
        gt:setLastTimeOfDay(hour)
    end
    if type(gt.updateCalendar) == "function" and type(gt.getYear) == "function"
        and type(gt.getMonth) == "function" and type(gt.getDay) == "function" then
        gt:updateCalendar(gt:getYear(), gt:getMonth(), gt:getDay(),
            math.floor(hour), math.floor((hour % 1) * 60))
    end
    local cm = IKST_ClimatePresets.climateMgr()
    -- Rebuild dawn/dusk day infos immediately instead of waiting for the climate tick.
    if cm and type(cm.forceDayInfoUpdate) == "function" then
        cm:forceDayInfoUpdate()
    end
    IKST_ClimatePresets.snapDayNightVisual(hour)
    return true, string.format("Time %02d:%02d", math.floor(hour), math.floor((hour % 1) * 60))
end

-- Server JVM authority path: mutate + engine sync.
function IKST_ClimatePresets.applyPreset(presetName)
    if not IKST_ClimatePresets.mayMutateAuthoritative() then
        return false, "server only"
    end
    local ok, msg = IKST_ClimatePresets.applyPresetLocal(presetName)
    if not ok then
        return false, msg
    end
    local cm = IKST_ClimatePresets.climateMgr()
    if cm and type(cm.transmitClientChangeAdminVars) == "function" then
        cm:transmitClientChangeAdminVars()
    end
    return true, msg
end

function IKST_ClimatePresets.clearWeather()
    if not IKST_ClimatePresets.mayMutateAuthoritative() then
        return false, "server only"
    end
    local ok, msg = IKST_ClimatePresets.clearWeatherLocal()
    if not ok then
        return false, msg
    end
    local cm = IKST_ClimatePresets.climateMgr()
    if cm and type(cm.transmitServerStopWeather) == "function" then
        cm:transmitServerStopWeather()
    elseif cm and type(cm.transmitClientChangeAdminVars) == "function" then
        cm:transmitClientChangeAdminVars()
    end
    return true, msg
end
