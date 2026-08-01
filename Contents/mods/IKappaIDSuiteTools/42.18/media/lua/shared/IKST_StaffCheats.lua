require "IKST_Shared"

IKST_StaffCheats = IKST_StaffCheats or {}

IKST_StaffCheats.MOD_DATA_KEY = "ikst_cheats"

-- Vanilla admin-style toggles (IsoGameCharacter cheat APIs).
-- B42 also mirrors several cheats into module-level flags (ISBuildMenu.cheat, etc.).
IKST_StaffCheats.CHEATS = {
    build = { isFn = "isBuildCheat", setFn = "setBuildCheat", labelKey = "IGUI_IKST_Cheat_Build", fallback = "Build" },
    mechanics = { isFn = "isMechanicsCheat", setFn = "setMechanicsCheat", labelKey = "IGUI_IKST_Cheat_Mechanics", fallback = "Mechanics" },
    health = { isFn = "isHealthCheat", setFn = "setHealthCheat", labelKey = "IGUI_IKST_Cheat_Health", fallback = "Health" },
    fastMove = { isFn = "isFastMoveCheat", setFn = "setFastMoveCheat", labelKey = "IGUI_IKST_Cheat_FastMove", fallback = "Fast move" },
    unlimitedCarry = { isFn = "isUnlimitedCarry", setFn = "setUnlimitedCarry", labelKey = "IGUI_IKST_Cheat_UnlimitedCarry", fallback = "No weight" },
    unlimitedEndurance = { isFn = "isUnlimitedEndurance", setFn = "setUnlimitedEndurance", labelKey = "IGUI_IKST_Cheat_UnlimitedEndurance", fallback = "No fatigue" },
    unlimitedAmmo = { isFn = "isUnlimitedAmmo", setFn = "setUnlimitedAmmo", labelKey = "IGUI_IKST_Cheat_UnlimitedAmmo", fallback = "Unl. ammo" },
    instantActions = { isFn = "isTimedActionInstantCheat", setFn = "setTimedActionInstantCheat", labelKey = "IGUI_IKST_Cheat_InstantActions", fallback = "Instant" },
    movables = { isFn = "isMovablesCheat", setFn = "setMovablesCheat", labelKey = "IGUI_IKST_Cheat_Movables", fallback = "Movables" },
    farming = { isFn = "isFarmingCheat", setFn = "setFarmingCheat", labelKey = "IGUI_IKST_Cheat_Farming", fallback = "Farming" },
}

-- Vanilla ISAdminPowerUI / ISCheatPanelUI set these alongside player:set*Cheat().
IKST_StaffCheats.MODULE_FLAGS = {
    build = {
        client = { req = "BuildingObjects/ISUI/ISBuildMenu", global = "ISBuildMenu", field = "cheat" },
        server = { req = "BuildingObjects/ISBuildUtil", global = "buildUtil", field = "cheat" },
    },
    mechanics = {
        client = { req = "Vehicles/ISUI/ISVehicleMechanics", global = "ISVehicleMechanics", field = "cheat" },
    },
    farming = {
        client = { req = "Farming/ISUI/ISFarmingMenu", global = "ISFarmingMenu", field = "cheat" },
    },
    movables = {
        shared = { req = "Moveables/ISMoveableDefinitions", global = "ISMoveableDefinitions", field = "cheat" },
    },
    health = {
        client = { req = "XpSystem/ISUI/ISHealthPanel", global = "ISHealthPanel", field = "cheat" },
    },
    fastMove = {
        client = { req = "DebugUIs/ISFastTeleportMove", global = "ISFastTeleportMove", field = "cheat" },
    },
}

IKST_StaffCheats.SELF_UI = {
    "build", "mechanics", "health", "fastMove",
    "unlimitedCarry", "unlimitedEndurance", "unlimitedAmmo", "instantActions",
    "movables", "farming",
}

function IKST_StaffCheats.isValidId(cheatId)
    return cheatId ~= nil and IKST_StaffCheats.CHEATS[cheatId] ~= nil
end

function IKST_StaffCheats.cheatTable(player)
    if not player or not player.getModData then
        return nil
    end
    local md = player:getModData()
    if not md then
        return nil
    end
    local tbl = md[IKST_StaffCheats.MOD_DATA_KEY]
    if type(tbl) ~= "table" then
        tbl = {}
        md[IKST_StaffCheats.MOD_DATA_KEY] = tbl
    end
    return tbl
end

function IKST_StaffCheats.getStored(player, cheatId)
    local tbl = IKST_StaffCheats.cheatTable(player)
    if not tbl then
        return nil
    end
    if IKST_Args and IKST_Args.readBool then
        return IKST_Args.readBool(tbl[cheatId])
    end
    local v = tbl[cheatId]
    if v == true or v == 1 then
        return true
    end
    if v == false or v == 0 then
        return false
    end
    return nil
end

function IKST_StaffCheats.setStored(player, cheatId, on)
    local tbl = IKST_StaffCheats.cheatTable(player)
    if not tbl then
        return
    end
    if on == true then
        tbl[cheatId] = 1
    else
        tbl[cheatId] = 0
    end
end

function IKST_StaffCheats.isActive(player, cheatId)
    local stored = IKST_StaffCheats.getStored(player, cheatId)
    if stored ~= nil then
        return stored
    end
    local row = IKST_StaffCheats.CHEATS[cheatId]
    if row and player and type(player[row.isFn]) == "function" then
        return player[row.isFn](player) == true
    end
    return false
end

function IKST_StaffCheats.setModuleFlag(spec, on)
    if not spec or type(require) ~= "function" then
        return
    end
    require(spec.req)
    local mod = _G[spec.global]
    local field = spec.field or "cheat"
    if mod ~= nil then
        mod[field] = on == true
    end
end

function IKST_StaffCheats.applyModuleFlags(cheatId, on)
    local flags = IKST_StaffCheats.MODULE_FLAGS[cheatId]
    if not flags then
        return
    end
    local onFlag = on == true
    if flags.shared then
        IKST_StaffCheats.setModuleFlag(flags.shared, onFlag)
    end
    if flags.client and type(isClient) == "function" and isClient() then
        IKST_StaffCheats.setModuleFlag(flags.client, onFlag)
    end
    if flags.server and type(isServer) == "function" and isServer() then
        IKST_StaffCheats.setModuleFlag(flags.server, onFlag)
    end
end

function IKST_StaffCheats.apply(player, cheatId, on)
    if not player or not IKST_StaffCheats.isValidId(cheatId) then
        return false
    end
    local row = IKST_StaffCheats.CHEATS[cheatId]
    if type(player[row.setFn]) ~= "function" then
        return false
    end
    if IKST_Args and IKST_Args.readBool then
        on = IKST_Args.readBool(on)
    else
        on = on == true
    end
    if on == nil then
        return false
    end
    player[row.setFn](player, on)
    IKST_StaffCheats.applyModuleFlags(cheatId, on)
    return true
end

function IKST_StaffCheats.syncToClient(player, cheatId, on)
    if not player or not IKST.deliverClientCommand then
        return
    end
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        return
    end
    if not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return
    end
    local onFlag = false
    if IKST_Args and IKST_Args.readBool then
        onFlag = IKST_Args.readBool(on) == true
    else
        onFlag = on == true
    end
    IKST.deliverClientCommand(player, IKST.CMD.applySelfCheat, {
        cheat = cheatId,
        on = onFlag and 1 or 0,
    })
end

function IKST_StaffCheats.syncAllToClient(player)
    if not player or not IKST_StaffCheats.SELF_UI then
        return
    end
    for _, cheatId in ipairs(IKST_StaffCheats.SELF_UI) do
        local on = IKST_StaffCheats.getStored(player, cheatId)
        if on == nil then
            on = IKST_StaffCheats.isActive(player, cheatId)
        end
        IKST_StaffCheats.syncToClient(player, cheatId, on)
    end
end

function IKST_StaffCheats.reapplyStored(player)
    if not player or not IKST_StaffCheats.SELF_UI then
        return
    end
    for _, cheatId in ipairs(IKST_StaffCheats.SELF_UI) do
        local on = IKST_StaffCheats.getStored(player, cheatId)
        if on ~= nil then
            IKST_StaffCheats.apply(player, cheatId, on)
        end
    end
end

function IKST_StaffCheats.toggle(player, cheatId)
    if not player or not IKST_StaffCheats.isValidId(cheatId) then
        return false, "invalid cheat"
    end
    local row = IKST_StaffCheats.CHEATS[cheatId]
    if type(player[row.isFn]) ~= "function" or type(player[row.setFn]) ~= "function" then
        return false, "unavailable"
    end
    local on = not IKST_StaffCheats.isActive(player, cheatId)
    IKST_StaffCheats.setStored(player, cheatId, on)
    IKST_StaffCheats.apply(player, cheatId, on)
    IKST_StaffCheats.syncToClient(player, cheatId, on)
    local label = IKST.text(row.labelKey, row.fallback)
    return true, label .. (on and " ON" or " OFF")
end
