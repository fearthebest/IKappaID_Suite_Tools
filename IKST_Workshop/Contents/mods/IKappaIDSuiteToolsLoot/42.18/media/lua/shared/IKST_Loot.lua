require "IKST_Shared"

IKST.LOOT_SCOPE_LIST = {
    IKST.CLEANUP_SCOPES.single,
    IKST.CLEANUP_SCOPES.radius,
    IKST.CLEANUP_SCOPES.room,
    IKST.CLEANUP_SCOPES.building,
}

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
