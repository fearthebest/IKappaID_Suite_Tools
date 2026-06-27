require "IKST_Shared"

IKST_Utility = IKST_Utility or {}
IKST_Utility.FAR_FUTURE = 2147483647

function IKST.forEachJavaCollection(collection, visitor)
    if not collection or not visitor then
        return
    end
    if collection.iterator then
        local it = collection:iterator()
        if it and it.hasNext and it.next then
            while it:hasNext() do
                local item = it:next()
                if item then
                    visitor(item)
                end
            end
        end
        return
    end
    if collection.size and collection.get then
        for i = 0, collection:size() - 1 do
            visitor(collection:get(i))
        end
    end
end

function IKST.utilityModifierName(which)
    return (which == "water" and "WaterShut" or "ElecShut") .. "Modifier"
end

function IKST.getShutModifierOption(which)
    if not getSandboxOptions then
        return nil
    end
    local sb = getSandboxOptions()
    if not sb or not sb.getOptionByName then
        return nil
    end
    return sb:getOptionByName(IKST.utilityModifierName(which))
end

function IKST.readUtilityModifier(which)
    local name = IKST.utilityModifierName(which)
    if SandboxVars and SandboxVars[name] ~= nil then
        return tonumber(SandboxVars[name])
    end
    local opt = IKST.getShutModifierOption(which)
    if opt and opt.getValue then
        return opt:getValue()
    end
    return IKST_Utility.FAR_FUTURE
end

function IKST.isWaterOn()
    return IKST.readUtilityModifier("water") > -1
end

function IKST.isPowerOn()
    return IKST.readUtilityModifier("power") > -1
end

function IKST.applyUtilitySandboxVar(which, value)
    if SandboxVars then
        SandboxVars[IKST.utilityModifierName(which)] = value
    end
    local live = getSandboxOptions and getSandboxOptions()
    if live and live.getOptionByName then
        local opt = live:getOptionByName(IKST.utilityModifierName(which))
        if opt and opt.setValue then
            opt:setValue(value)
        end
    end
end

function IKST.setUtilityOnServer(which, on)
    if which ~= "water" and which ~= "power" then
        return false
    end
    local value = on and IKST_Utility.FAR_FUTURE or -1
    IKST.applyUtilitySandboxVar(which, value)
    local live = getSandboxOptions and getSandboxOptions()
    if live and live.getOptionByName then
        local opt = live:getOptionByName(IKST.utilityModifierName(which))
        if opt and opt.setValue then
            opt:setValue(value)
        end
    end
    return true
end

function IKST_Utility.broadcastSync()
    if not getOnlinePlayers then
        return
    end
    local list = getOnlinePlayers()
    if not list or not list.size then
        return
    end
    local payload = {
        waterOn = IKST.isWaterOn(),
        powerOn = IKST.isPowerOn(),
    }
    for i = 0, list:size() - 1 do
        local p = list:get(i)
        if p and IKST.deliverClientCommand then
            IKST.deliverClientCommand(p, IKST.CMD.utilitySync, payload)
        end
    end
end

-- SP only: apply sandbox utility modifiers locally. MP uses server quickWater/quickPower.
function IKST.setUtilityOn(which, on)
    if type(isClient) == "function" and not isClient() then
        return false
    end
    if IKST.isMultiplayerSession() then
        if type(isServer) == "function" and isServer() then
            return IKST.setUtilityOnServer(which, on == true)
        end
        return false
    end
    if not SandboxOptions or not SandboxOptions.new or not getSandboxOptions then
        return false
    end
    local live = getSandboxOptions()
    if not live then
        return false
    end
    local value = on and IKST_Utility.FAR_FUTURE or -1
    local options = SandboxOptions.new()
    options:copyValuesFrom(live)
    local opt = options:getOptionByName(IKST.utilityModifierName(which))
    if not opt or not opt.setValue then
        return false
    end
    opt:setValue(value)
    if live.copyValuesFrom then
        live:copyValuesFrom(options)
    end
    if live.toLua then
        live:toLua()
    end
    IKST.applyUtilitySandboxVar(which, value)
    return true
end

function IKST.setUtilityExplicit(which, on)
    if which == "water" then
        return IKST.setWaterOn(on == true)
    end
    if which == "power" then
        return IKST.setPowerOn(on == true)
    end
    return false
end

function IKST.toggleUtilityForPlayer(player, which)
    player = IKST.resolvePlayer(player)
    if not player or (which ~= "water" and which ~= "power") then
        return false
    end
    if IKST_Access and IKST_Access.canToggleUtilities and not IKST_Access.canToggleUtilities(player) then
        IKST.notify(player, "not allowed", false)
        return false
    end
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        local cmd = which == "water" and IKST.CMD.quickWater or IKST.CMD.quickPower
        IKST.dispatchCommand(player, cmd, {})
        return true
    end
    local wantOn
    if which == "water" then
        wantOn = not IKST.isWaterOn()
    else
        wantOn = not IKST.isPowerOn()
    end
    local ok = IKST.setUtilityExplicit(which, wantOn)
    if ok then
        IKST.notifyUtilityToggle(player, which, wantOn)
    end
    return ok
end

function IKST.toggleUtility(which)
    if which == "water" then
        return IKST.setWaterOn(not IKST.isWaterOn())
    end
    return IKST.setPowerOn(not IKST.isPowerOn())
end

function IKST.setWaterOn(on)
    return IKST.setUtilityOn("water", on == true)
end

function IKST.setPowerOn(on)
    return IKST.setUtilityOn("power", on == true)
end

function IKST.isWaterShutOff()
    return not IKST.isWaterOn()
end

function IKST.isPowerShutOff()
    return not IKST.isPowerOn()
end

function IKST.utilityStatusLine()
    local water = IKST.isWaterOn()
        and IKST.text("IGUI_IKST_Utility_On", "ON")
        or IKST.text("IGUI_IKST_Utility_Off", "OFF")
    local power = IKST.isPowerOn()
        and IKST.text("IGUI_IKST_Utility_On", "ON")
        or IKST.text("IGUI_IKST_Utility_Off", "OFF")
    return IKST.text("IGUI_IKST_Water", "Water") .. ": " .. water
        .. "  |  "
        .. IKST.text("IGUI_IKST_Power", "Power") .. ": " .. power
end

function IKST.utilityContextLabel(which)
    local on = which == "water" and IKST.isWaterOn() or IKST.isPowerOn()
    local state = on
        and IKST.text("IGUI_IKST_Utility_On", "ON")
        or IKST.text("IGUI_IKST_Utility_Off", "OFF")
    local name = which == "water"
        and IKST.text("IGUI_IKST_Water", "Water")
        or IKST.text("IGUI_IKST_Power", "Power")
    return name .. " [" .. state .. "]"
end

function IKST.notifyUtilityToggle(player, which, on)
    local name = which == "water"
        and IKST.text("IGUI_IKST_Water", "Water")
        or IKST.text("IGUI_IKST_Power", "Power")
    local state = on
        and IKST.text("IGUI_IKST_Utility_On", "ON")
        or IKST.text("IGUI_IKST_Utility_Off", "OFF")
    IKST.notify(player, name .. ": " .. state, true)
end
