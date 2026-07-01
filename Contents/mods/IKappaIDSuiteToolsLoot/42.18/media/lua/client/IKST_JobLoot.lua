if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Chrome"
require "IKST_JobLayout"
require "IKST_ActionLog"
require "IKST_Loot"
require "IKST_LootOps"
require "IKST_LootWorldPick"

IKST_JobLoot = IKST_JobLoot or {}

function IKST_JobLoot.selectScope(panel, scope)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return
    end
    state.lootScope = scope
    IKST_JobLoot.syncArm(panel)
    panel:refreshJobUI()
end

function IKST_JobLoot.selectRadius(panel, radius)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return
    end
    state.cleanupRadius = radius
    IKST_JobLoot.syncArm(panel)
    panel:refreshJobUI()
end

function IKST_JobLoot.syncArm(panel)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return
    end
    if state.armed and state.armedJob == IKST.VIEW.loot then
        IKST_LootWorldPick.arm(panel.player, IKST.getLootScope(state), true)
    end
    if IKST_Preview and IKST_Preview.syncForPanel then
        IKST_Preview.syncForPanel(panel)
    end
end

function IKST_JobLoot.buildScopeRow(panel, y, state)
    local x = IKST_JobLayout.MARGIN
    panel:makeJobLabel(x, y, IKST.text("IGUI_IKST_Scope_Label", "How big an area") .. ":", UIFont.Small)
    y = y + 18
    x = IKST_JobLayout.MARGIN
    for _, scope in ipairs(IKST.LOOT_SCOPE_LIST) do
        local label = IKST.lootScopeLabel(scope, state)
        local w = getTextManager():MeasureStringX(UIFont.Small, label) + 20
        panel:makeJobButton(x, y, w, 24, label, function()
            IKST_JobLoot.selectScope(panel, scope)
        end, IKST.getLootScope(state) == scope)
        x = x + w + 6
    end
    return y + 32
end

function IKST_JobLoot.buildSizeRow(panel, y, state)
    if IKST.getLootScope(state) ~= IKST.CLEANUP_SCOPES.radius then
        return y
    end
    local x = IKST_JobLayout.MARGIN
    panel:makeJobLabel(x, y, IKST.text("IGUI_IKST_Radius_Size", "Circle size") .. ":", UIFont.Small)
    y = y + 18
    x = IKST_JobLayout.MARGIN
    for key, radius in pairs(IKST.RADIUS_PRESETS) do
        local label = key .. " (" .. radius .. ")"
        panel:makeJobButton(x, y, 72, 24, label, function()
            IKST_JobLoot.selectRadius(panel, radius)
        end, state.cleanupRadius == radius)
        x = x + 78
    end
    return y + 32
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
    if not player or not IKST_LootOps or not IKST_LootOps.previewZone then
        return false
    end
    local preview = IKST_LootOps.previewZone(x, y, z, scope, { radius = radius })
    if preview.count == 0 then
        IKST_JobLoot.notifyPreview(player, preview, false)
        return false
    end
    IKST.dispatchCommand(player, IKST.CMD.lootRepopulateZone, {
        x = x,
        y = y,
        z = z,
        scope = scope,
        radius = radius,
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
    local msg = IKST_LootOps.formatResultMessage(args.message)
    if msg and msg ~= "" then
        IKST.notify(player, msg, args.success == true)
    end
end

function IKST_JobLoot.repopulateAtPlayer(panel)
    local player = panel.player
    if not player then
        return
    end
    local state = IKST.getPlayerState(player)
    if not state then
        return
    end
    local x = math.floor(player:getX())
    local y = math.floor(player:getY())
    local z = math.floor(player:getZ())
    IKST_JobLoot.tryDispatchZone(player, x, y, z, IKST.getLootScope(state), state.cleanupRadius)
end

function IKST_JobLoot.build(panel)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return 8
    end

    local y = 8
    panel:makeJobLabel(IKST_JobLayout.MARGIN, y, IKST.text("IGUI_IKST_Job_Loot_Desc", "Refill containers with vanilla loot for this room and container type."), UIFont.Small)
    y = y + 22

    y = IKST_JobLoot.buildScopeRow(panel, y, state)
    y = IKST_JobLoot.buildSizeRow(panel, y, state)

    local active = IKST_JobLoot.describeState(state)
    if state.armed and state.armedJob == IKST.VIEW.loot then
        active = active .. " [" .. IKST.text("IGUI_IKST_Armed", "READY — click the ground") .. "]"
    end
    local preview = IKST_JobLoot.previewAtPlayer(panel)
    local previewLine = IKST_LootOps.previewSummary(preview)

    local barW = panel.contentW or (panel.width - 24)
    local barH = previewLine ~= "" and 44 or 30
    local bar = ISPanel:new(IKST_JobLayout.MARGIN, y, barW, barH)
    bar.backgroundColor = IKST_Chrome.colors.bgToolbar
    bar.borderColor = IKST_Chrome.colors.accentDim
    bar:initialise()
    bar.render = function(p)
        ISPanel.render(p)
        local cc = IKST_Chrome.colors
        p:drawText(IKST.text("IGUI_IKST_Active", "Ready") .. ": " .. active, 8, 7,
            cc.textPrimary.r, cc.textPrimary.g, cc.textPrimary.b, 1, UIFont.Small)
        if previewLine ~= "" then
            p:drawText(IKST.text("IGUI_IKST_Loot_Preview_Label", "Affected") .. ": " .. previewLine, 8, 22,
                cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small)
        end
    end
    panel:addJobWidget(bar)

    panel:makeJobButton(IKST_JobLayout.MARGIN + barW - 188, y + 4, 88, 22,
        IKST.text("IGUI_IKST_Loot_Here", "At my feet"), function()
            IKST_JobLoot.repopulateAtPlayer(panel)
        end, false)
    panel:makeJobButton(IKST_JobLayout.MARGIN + barW - 92, y + 4, 84, 22,
        IKST.text("IGUI_IKST_Disarm", "STOP"), function()
            IKST_LootWorldPick.disarm(panel.player)
            panel:refreshJobUI()
        end, false)

    y = y + barH + 8

    panel:makeJobButton(IKST_JobLayout.MARGIN, y, barW, 28,
        IKST.text("IGUI_IKST_Loot_Arm", "Click ground to repopulate"), function()
            IKST_LootWorldPick.arm(panel.player, IKST.getLootScope(state), false)
            panel:refreshJobUI()
        end, state.armed and state.armedJob == IKST.VIEW.loot)

    y = y + 36

    if IKST_ActionLog and IKST_ActionLog.dock then
        panel.logPanel = IKST_ActionLog.dock(panel, panel.player, y)
    end
    return y
end

function IKST_JobLoot.enter(panel)
    local state = IKST.getPlayerState(panel.player)
    if state and not state.lootScope then
        state.lootScope = IKST.CLEANUP_SCOPES.single
    end
    IKST_JobLoot.syncArm(panel)
    if IKST_Preview and IKST_Preview.syncForPanel then
        IKST_Preview.syncForPanel(panel)
    end
end
