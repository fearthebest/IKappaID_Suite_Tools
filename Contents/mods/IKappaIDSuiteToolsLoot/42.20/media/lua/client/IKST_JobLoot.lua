if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISPanel"
require "IKST_Shared"
require "IKST_Access"
require "IKappaID_UI_Framework/IKUI_Chrome"
require "IKST_UI_Layout"
require "IKST_JobLayout"
require "IKST_ActionLog"
require "IKST_Confirm"
require "IKST_Loot"
require "IKST_LootOps"

IKST_JobLoot = IKST_JobLoot or {}

function IKST_JobLoot.invalidatePreview()
    if IKST_LootOps and type(IKST_LootOps.invalidatePreviewCache) == "function" then
        IKST_LootOps.invalidatePreviewCache()
    end
end

function IKST_JobLoot.selectScope(panel, scope)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return
    end
    state.lootScope = scope
    IKST_JobLoot.invalidatePreview()
    IKST_JobLoot.syncArm(panel)
    panel:refreshJobUI()
end

function IKST_JobLoot.selectRadius(panel, radius)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return
    end
    if IKST.clampLootRadius then
        radius = IKST.clampLootRadius(radius)
    end
    state.cleanupRadius = radius
    state.lootScope = IKST.CLEANUP_SCOPES.radius
    IKST_JobLoot.invalidatePreview()
    IKST_JobLoot.syncArm(panel)
    panel:refreshJobUI()
end

function IKST_JobLoot.filterArgs(state)
    if not state then
        return {}
    end
    if IKST.ensureLootPlayerState then
        IKST.ensureLootPlayerState(state)
    end
    return {
        onlyEmpty = state.lootOnlyEmpty == true,
        skipLocked = state.lootSkipLocked == true,
        skipClaimed = state.lootSkipClaimed == true,
        preserveExisting = state.lootPreserveExisting == true,
        lootTable = IKST.readLootTableId(state.lootTable),
    }
end

function IKST_JobLoot.toggleFilter(panel, field)
    local state = IKST.getPlayerState(panel and panel.player)
    if not state or not field then
        return
    end
    state[field] = not (state[field] == true)
    IKST_JobLoot.invalidatePreview()
    panel:refreshJobUI()
end

function IKST_JobLoot.selectLootTable(panel, tableId)
    local state = IKST.getPlayerState(panel and panel.player)
    if not state then
        return
    end
    if IKST.ensureLootPlayerState then
        IKST.ensureLootPlayerState(state)
    end
    state.lootTable = IKST.readLootTableId(tableId)
    IKST_JobLoot.invalidatePreview()
    panel:refreshJobUI()
end

function IKST_JobLoot.armPick(panel, silent)
    local player = panel and panel.player
    if not player or not IKST_WorldPick or not IKST_WorldPick.armCommand then
        if not silent then
            IKST.notify(player, IKST.text("IGUI_IKST_Loot_NeedsTiles", "Loot world pick needs Suite Tools Tiles"), false)
        end
        return false
    end
    if not IKST_Access.canUseLoot(player) then
        if not silent then
            IKST.notify(player, IKST.text("IGUI_IKST_Loot_NoAccess", "Loot repopulate is not available"), false)
        end
        return false
    end
    local state = IKST.getPlayerState(player)
    if not state then
        return false
    end
    IKST_WorldPick.armCommand(player, IKST.VIEW.loot, nil, {
        scope = IKST.getLootScope(state),
        radius = state.cleanupRadius,
    }, {
        silent = silent == true,
        notifyKey = "IGUI_IKST_ClickWorld",
        onClick = function(p, square)
            if not p or not square then
                return
            end
            local st = IKST.getPlayerState(p)
            if not st then
                return
            end
            IKST_JobLoot.tryDispatchZone(
                p,
                square:getX(),
                square:getY(),
                square:getZ(),
                IKST.getLootScope(st),
                st.cleanupRadius
            )
        end,
    })
    return true
end

function IKST_JobLoot.syncArm(panel)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return
    end
    if state.armed and state.armedJob == IKST.VIEW.loot then
        IKST_JobLoot.armPick(panel, true)
    end
    if IKST_Preview and type(IKST_Preview.syncForPanel) == "function" then
        IKST_Preview.syncForPanel(panel)
    end
end

function IKST_JobLoot.repopulateHere(panel)
    local player = panel and panel.player
    if not player then
        return false
    end
    if not IKST_Access.canUseLoot(player) then
        IKST.notify(player, IKST.text("IGUI_IKST_Loot_NoAccess", "Loot repopulate is not available"), false)
        return false
    end
    local state = IKST.getPlayerState(player)
    if not state then
        return false
    end
    local scope = IKST.getLootScope(state)
    local function go()
        return IKST_JobLoot.tryDispatchZone(
            player,
            math.floor(player:getX()),
            math.floor(player:getY()),
            math.floor(player:getZ()),
            scope,
            state.cleanupRadius
        )
    end
    if scope == IKST.CLEANUP_SCOPES.cell then
        IKST_Confirm.showDestructive(
            IKST.text("IGUI_IKST_Confirm_LootCell",
                "Refill loaded containers in this map cell? Filters still apply."),
            go
        )
        return true
    end
    return go()
end

function IKST_JobLoot.buildScopeRow(panel, y, state)
    y = panel:makeJobHeader(IKST_JobLayout.MARGIN, y, IKST.text("IGUI_IKST_Scope_Label", "How big an area"))
    local specs = {}
    for _, scope in ipairs(IKST.LOOT_SCOPE_LIST) do
        local label = IKST.lootScopeLabel(scope, state)
        local w = getTextManager():MeasureStringX(UIFont.Small, label) + 20
        specs[#specs + 1] = {
            label = label,
            w = w,
            primary = IKST.getLootScope(state) == scope,
            fn = function()
                IKST_JobLoot.selectScope(panel, scope)
            end,
        }
    end
    y = IKST_JobLayout.flowRow(panel, y, specs, 6, 24)
    return y + 8
end

function IKST_JobLoot.buildSizeRow(panel, y, state)
    if IKST.getLootScope(state) ~= IKST.CLEANUP_SCOPES.radius then
        return y
    end
    y = panel:makeJobHeader(IKST_JobLayout.MARGIN, y, IKST.text("IGUI_IKST_Radius_Size", "Circle size"))
    local order = { "S", "M", "L" }
    local specs = {}
    for _, key in ipairs(order) do
        local radius = IKST.RADIUS_PRESETS[key]
        if radius then
            specs[#specs + 1] = {
                label = key .. " (" .. radius .. ")",
                w = 72,
                primary = state.cleanupRadius == radius,
                fn = function()
                    IKST_JobLoot.selectRadius(panel, radius)
                end,
            }
        end
    end
    y = IKST_JobLayout.flowRow(panel, y, specs, 6, 24)
    return y + 8
end

function IKST_JobLoot.describeState(state)
    return IKST.text("IGUI_IKST_Loot_Repopulate", "Repopulate loot") .. " · " .. IKST.lootScopeLabel(IKST.getLootScope(state), state)
end

function IKST_JobLoot.previewAt(panel, x, y, z)
    if not panel or not IKST_LootOps or not IKST_LootOps.previewZone then
        return nil
    end
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return nil
    end
    return IKST_LootOps.previewZone(x, y, z, IKST.getLootScope(state), {
        radius = state.cleanupRadius,
    })
end

function IKST_JobLoot.previewAtPlayer(panel)
    local player = panel and panel.player
    if not player then
        return nil
    end
    return IKST_JobLoot.previewAt(panel, math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ()))
end

function IKST_JobLoot.previewForPanel(panel)
    local player = panel and panel.player
    if not player then
        return nil
    end
    local state = IKST.getPlayerState(player)
    if not state then
        return nil
    end
    local ax = math.floor(player:getX())
    local ay = math.floor(player:getY())
    local az = math.floor(player:getZ())
    if state.armed and state.armedJob == IKST.VIEW.loot
        and IKST_WorldPick and IKST_WorldPick.hoverSquare then
        local hs = IKST_WorldPick.hoverSquare
        if type(hs.getX) == "function" and type(hs.getY) == "function" then
            ax = hs:getX()
            ay = hs:getY()
            if type(hs.getZ) == "function" then
                az = hs:getZ()
            end
        end
    end
    return IKST_JobLoot.previewAt(panel, ax, ay, az)
end

function IKST_JobLoot.notifyPreview(player, preview, ok)
    if not player or not preview then
        return
    end
    local line = IKST_LootOps.previewSummary(preview)
    if line ~= "" then
        IKST.notify(player, line, ok == true)
    end
end

function IKST_JobLoot.tryDispatchZone(player, x, y, z, scope, radius)
    if not player then
        return false
    end
    if IKST_LootOps and type(IKST_LootOps.ensureLootPickerReady) == "function" then
        IKST_LootOps.ensureLootPickerReady()
    end
    x = math.floor(tonumber(x) or 0)
    y = math.floor(tonumber(y) or 0)
    z = math.floor(tonumber(z) or 0)
    scope = scope or IKST.CLEANUP_SCOPES.single
    radius = radius or IKST.RADIUS_PRESETS.M
    local state = IKST.getPlayerState(player)
    local filters = IKST_JobLoot.filterArgs(state)

    local preview = nil
    if IKST_LootOps and type(IKST_LootOps.previewZone) == "function" then
        preview = IKST_LootOps.previewZone(x, y, z, scope, { radius = radius })
        if preview and preview.count == 0 and type(IKST_LootOps.squaresForScope) == "function" then
            local squares = IKST_LootOps.squaresForScope(x, y, z, scope, { radius = radius })
            local loose = IKST_LootOps.collectContainersFromSquares(squares, {}, {}, false)
            local candidateCount = 0
            for i = 1, #loose do
                if IKST_LootOps.isRepopulateCandidate(loose[i]) then
                    candidateCount = candidateCount + 1
                end
            end
            if candidateCount > 0 then
                preview.count = candidateCount
            end
        end
        IKST_JobLoot.notifyPreview(player, preview, preview and preview.count and preview.count > 0)
    end

    if IKST_WorldPick and type(IKST_WorldPick.setPickCooldown) == "function" then
        IKST_WorldPick.setPickCooldown()
    end
    if IKST.pushLog then
        local scopeLabel = IKST.lootScopeLabel and IKST.lootScopeLabel(scope, IKST.getPlayerState(player)) or tostring(scope)
        IKST.pushLog(player, "lootRepopulateZone " .. scopeLabel
            .. " @ " .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z), "progress")
    end
    IKST.dispatchCommand(player, IKST.CMD.lootRepopulateZone, {
        x = x,
        y = y,
        z = z,
        scope = scope,
        radius = radius,
        onlyEmpty = filters.onlyEmpty == true,
        skipLocked = filters.skipLocked == true,
        skipClaimed = filters.skipClaimed == true,
        preserveExisting = filters.preserveExisting == true,
        lootTable = filters.lootTable,
    })
    return true
end

function IKST_JobLoot.onServerResult(panel, args)
    if not args then
        return
    end
    if args.mode ~= IKST.CMD.lootRepopulateZone and args.mode ~= IKST.CMD.lootRepopulateContainer then
        return
    end
    local player = panel and panel.player
    if not player then
        return
    end
    local msg = IKST.formatServerResult(args.message, args)
    if msg and msg ~= "" then
        IKST.notify(player, msg, args.success == true)
    end
    if args.success == true and IKST_LootOps and type(IKST_LootOps.invalidatePreviewCache) == "function" then
        IKST_LootOps.invalidatePreviewCache()
    end
    if args.success == true and IKST_Preview and type(IKST_Preview.syncForPanel) == "function" then
        IKST_Preview.syncForPanel(panel)
    end
end

function IKST_JobLoot.build(panel)
    if IKST_SoftTool_Loot and type(IKST_SoftTool_Loot.build) == "function" then
        return IKST_SoftTool_Loot.build(panel)
    end
    return 8
end

function IKST_JobLoot.enter(panel)
    local state = IKST.getPlayerState(panel.player)
    if state then
        if IKST.ensureLootPlayerState then
            IKST.ensureLootPlayerState(state)
        end
        if not state.lootScope then
            state.lootScope = IKST.CLEANUP_SCOPES.single
        end
    end
    IKST_JobLoot.armPick(panel, true)
    if IKST_Preview and type(IKST_Preview.syncForPanel) == "function" then
        IKST_Preview.syncForPanel(panel)
    end
end
