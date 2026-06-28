require "IKST_Shared"
require "IKST_Utility"

IKST_QuickActions = IKST_QuickActions or {}

-- Pin ids map to server commands or client-side utility toggles.
IKST_QuickActions.DEFS = {
    healSelf = { cmd = "healSelf", labelKey = "IGUI_IKST_Heal", fallback = "Heal" },
    feedSelf = { cmd = "feedSelf", labelKey = "IGUI_IKST_Feed", fallback = "Feed" },
    cureSelf = { cmd = "cureSelf", labelKey = "IGUI_IKST_Cure", fallback = "Cure" },
    godSelf = { cmd = "godSelf", labelKey = "IGUI_IKST_God", fallback = "God" },
    clearZombies = { cmd = "clearZombies", labelKey = "IGUI_IKST_ClearZombies", fallback = "Clear zombies", args = { radius = 30 } },
    clearWeather = { cmd = "clearWeather", labelKey = "IGUI_IKST_ClearWeather", fallback = "Clear weather" },
    quickWater = { utility = "water", labelKey = "IGUI_IKST_Water", fallback = "Water" },
    quickPower = { utility = "power", labelKey = "IGUI_IKST_Power", fallback = "Power" },
    quickSave = { cmd = "quickSave", labelKey = "IGUI_IKST_Save", fallback = "Save" },
}

IKST_QuickActions.DEFAULTS = { "healSelf", "clearZombies", "quickWater" }

function IKST_QuickActions.getFavorites(player)
    local state = IKST.getPlayerState(player)
    if not state then
        return IKST_QuickActions.DEFAULTS
    end
    if not state.quickFavorites or #state.quickFavorites == 0 then
        state.quickFavorites = {}
        for _, id in ipairs(IKST_QuickActions.DEFAULTS) do
            state.quickFavorites[#state.quickFavorites + 1] = id
        end
    end
    return state.quickFavorites
end

function IKST_QuickActions.label(def)
    if not def then
        return "?"
    end
    return IKST.text(def.labelKey, def.fallback or def.cmd or "?")
end

function IKST_QuickActions.run(player, pinId)
    player = IKST.resolvePlayer(player)
    local def = IKST_QuickActions.DEFS[pinId]
    if not player or not def then
        return
    end
    if def.utility == "water" or def.utility == "power" then
        IKST.toggleUtilityForPlayer(player, def.utility)
        return
    end
    if pinId == "clearWeather" then
        if IKST_ClientStaff and IKST_ClientStaff.runClearWeather then
            IKST_ClientStaff.runClearWeather(player)
        elseif type(isClient) == "function" and isClient() then
            if not IKST_ClimatePresets then
                require "IKST_ClimatePresets"
            end
            local ok, msg = false, "climate unavailable"
            if IKST_ClimatePresets and IKST_ClimatePresets.clearWeather then
                ok, msg = IKST_ClimatePresets.clearWeather()
            end
            if msg then
                IKST.notify(player, msg, ok == true)
            end
        else
            IKST.dispatchCommand(player, IKST.CMD.clearWeather, {})
        end
        return
    end
    if def.cmd and IKST.CMD[def.cmd] then
        IKST.dispatchCommand(player, IKST.CMD[def.cmd], def.args or {})
    end
end

function IKST_QuickActions.getPinnedCommands(player)
    local out = {}
    for _, pinId in ipairs(IKST_QuickActions.getFavorites(player)) do
        local def = IKST_QuickActions.DEFS[pinId]
        if def then
            local label = IKST_QuickActions.label(def)
            if pinId == "quickWater" then
                label = IKST.isWaterOn()
                    and IKST.text("IGUI_IKST_Water_On", "Water: ON")
                    or IKST.text("IGUI_IKST_Water_Off", "Water: OFF")
            elseif pinId == "quickPower" then
                label = IKST.isPowerOn()
                    and IKST.text("IGUI_IKST_Power_On", "Power: ON")
                    or IKST.text("IGUI_IKST_Power_Off", "Power: OFF")
            end
            out[#out + 1] = { id = pinId, label = label, run = function()
                IKST_QuickActions.run(player, pinId)
            end }
        end
    end
    return out
end
