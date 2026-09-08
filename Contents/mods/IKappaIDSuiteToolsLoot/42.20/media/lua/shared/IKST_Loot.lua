require "IKST_Shared"

IKST.LOOT_SCOPE_LIST = {
    IKST.CLEANUP_SCOPES.single,
    IKST.CLEANUP_SCOPES.radius,
    IKST.CLEANUP_SCOPES.room,
    IKST.CLEANUP_SCOPES.building,
    IKST.CLEANUP_SCOPES.cell,
}

-- Vanilla SuburbsDistributions / ItemPicker room names (wiki Room definitions).
IKST.LOOT_TABLE_IDS = {
    residential = true,
    grocery = true,
    medical = true,
    event = true,
    military = true,
}

IKST.LOOT_TABLE_ROOMS = {
    grocery = { "grocerystorage", "grocery", "conveniencestore" },
    medical = { "medicalstorage", "medical", "hospitalroom", "pharmacy" },
    event = { "SafehouseLoot" },
    military = { "armystorage", "armysurplus" },
}

function IKST.readLootTableId(val)
    if type(val) ~= "string" then
        return "residential"
    end
    if IKST.LOOT_TABLE_IDS[val] then
        return val
    end
    return "residential"
end

function IKST.lootTableRoomName(tableId)
    tableId = IKST.readLootTableId(tableId)
    if tableId == "residential" then
        return nil
    end
    local rooms = IKST.LOOT_TABLE_ROOMS[tableId]
    if not rooms then
        return nil
    end
    for i = 1, #rooms do
        local name = rooms[i]
        if SuburbsDistributions and type(SuburbsDistributions) == "table" and SuburbsDistributions[name] then
            return name
        end
    end
    return rooms[1]
end

-- Large radius presets for Loot only (Tiles cleanup keeps core S/M/L).
IKST.LOOT_RADIUS_PRESETS = { XL = 50, XXL = 200 }

function IKST.getMaxLootRadius()
    local sv = SandboxVars and SandboxVars.IKappaIDSuiteToolsLoot
    if sv and sv.MaxLootRadius ~= nil then
        local n = math.floor(tonumber(sv.MaxLootRadius) or 200)
        if n < 1 then
            n = 1
        end
        if n > 500 then
            n = 500
        end
        return n
    end
    return 200
end

function IKST.clampLootRadius(r)
    r = tonumber(r) or IKST.RADIUS_PRESETS.M
    return math.max(1, math.min(math.floor(r), IKST.getMaxLootRadius()))
end

function IKST.ensureLootPlayerState(state)
    if not state then
        return
    end
    if state.lootOnlyEmpty == nil then
        state.lootOnlyEmpty = true
    end
    if state.lootSkipLocked == nil then
        state.lootSkipLocked = true
    end
    if state.lootSkipClaimed == nil then
        state.lootSkipClaimed = false
    end
    if state.lootPreserveExisting == nil then
        state.lootPreserveExisting = false
    end
    if state.lootTable == nil then
        state.lootTable = "residential"
    else
        state.lootTable = IKST.readLootTableId(state.lootTable)
    end
end

function IKST.getLootScope(state)
    if not state then
        return IKST.CLEANUP_SCOPES.single
    end
    if not state.lootScope then
        state.lootScope = IKST.CLEANUP_SCOPES.single
    end
    return state.lootScope
end

function IKST.lootScopeLabel(scope, state)
    return IKST.cleanupScopeLabel(scope, state)
end
