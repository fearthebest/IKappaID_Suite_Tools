require "IKST_Shared"

IKST_StaffCheats = IKST_StaffCheats or {}

-- Vanilla admin-style toggles (IsoGameCharacter cheat APIs).
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

IKST_StaffCheats.SELF_UI = {
    "build", "mechanics", "health", "fastMove",
    "unlimitedCarry", "unlimitedEndurance", "unlimitedAmmo", "instantActions",
    "movables", "farming",
}

function IKST_StaffCheats.isValidId(cheatId)
    return cheatId ~= nil and IKST_StaffCheats.CHEATS[cheatId] ~= nil
end

function IKST_StaffCheats.toggle(player, cheatId)
    if not player or not IKST_StaffCheats.isValidId(cheatId) then
        return false, "invalid cheat"
    end
    local row = IKST_StaffCheats.CHEATS[cheatId]
    local isFn = row.isFn
    local setFn = row.setFn
    if type(player[isFn]) ~= "function" or type(player[setFn]) ~= "function" then
        return false, "unavailable"
    end
    local on = not player[isFn](player)
    player[setFn](player, on)
    local label = IKST.text(row.labelKey, row.fallback)
    return true, label .. (on and " ON" or " OFF")
end
