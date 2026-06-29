if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then return end



require "IKST_Shared"
require "IKST_Chrome"
require "IKST_Grid"
require "IKST_PreviewOverlay"
require "IKST_Rewind"
require "IKST_JobLayout"



IKST_JobCleanup = IKST_JobCleanup or {}



function IKST_JobCleanup.selectAction(panel, action)

    local state = IKST.getPlayerState(panel.player)

    if not state then

        return

    end

    state.cleanupAction = action

    state.cleanupMode = action

    if IKST_PreviewOverlay then

        IKST_PreviewOverlay.clear()

    end

    IKST_JobCleanup.syncArm(panel)

    panel:refreshJobUI()

end



function IKST_JobCleanup.selectScope(panel, scope)

    local state = IKST.getPlayerState(panel.player)

    if not state then

        return

    end

    state.cleanupScope = scope

    if IKST_PreviewOverlay then

        IKST_PreviewOverlay.clear()

    end

    IKST_JobCleanup.syncArm(panel)

    panel:refreshJobUI()

end



function IKST_JobCleanup.syncArm(panel)

    local state = IKST.getPlayerState(panel.player)

    if not state then

        return

    end

    IKST_WorldPick.arm(panel.player, IKST.getCleanupAction(state), IKST.getCleanupScope(state), true)

end



function IKST_JobCleanup.buildActionRow(panel, y, state)

    local x = 12

    panel:makeJobLabel(x, y, IKST.text("IGUI_IKST_Action_Label", "Action") .. ":", UIFont.Small)

    y = y + 18

    x = 12

    for _, action in ipairs(IKST.CLEANUP_ACTIONS) do

        local label = IKST.cleanupActionLabel(action)

        local w = getTextManager():MeasureStringX(UIFont.Small, label) + 20

        panel:makeJobButton(x, y, w, 24, label, function()

            IKST_JobCleanup.selectAction(panel, action)

        end, IKST.getCleanupAction(state) == action)

        x = x + w + 6

    end

    return y + 32

end



function IKST_JobCleanup.buildScopeRow(panel, y, state)

    local x = 12

    panel:makeJobLabel(x, y, IKST.text("IGUI_IKST_Scope_Label", "Scope") .. ":", UIFont.Small)

    y = y + 18

    x = 12

    for _, scope in ipairs(IKST.CLEANUP_SCOPE_LIST) do

        local label = IKST.cleanupScopeLabel(scope, state)

        local w = getTextManager():MeasureStringX(UIFont.Small, label) + 20

        panel:makeJobButton(x, y, w, 24, label, function()

            IKST_JobCleanup.selectScope(panel, scope)

        end, IKST.getCleanupScope(state) == scope)

        x = x + w + 6

        if x > panel.width - 100 then

            x = 12

            y = y + 28

        end

    end

    return y + 32

end



function IKST_JobCleanup.buildSizeRow(panel, y, state)

    local scope = IKST.getCleanupScope(state)

    if scope ~= IKST.CLEANUP_SCOPES.cube and scope ~= IKST.CLEANUP_SCOPES.radius then

        return y

    end



    local x = 12

    local sizeLabel = scope == IKST.CLEANUP_SCOPES.cube

        and IKST.text("IGUI_IKST_Cube_Size", "Cube half-size")

        or IKST.text("IGUI_IKST_Radius_Size", "Radius")

    panel:makeJobLabel(x, y, IKST.text("IGUI_IKST_Size_Label", "Size") .. ": " .. sizeLabel, UIFont.Small)

    y = y + 18

    x = 12



    local presets = scope == IKST.CLEANUP_SCOPES.cube and IKST.CUBE_PRESETS or IKST.RADIUS_PRESETS

    local current = scope == IKST.CLEANUP_SCOPES.cube and state.cleanupCubeHalf or state.cleanupRadius



    for key, val in pairs(presets) do

        panel:makeJobButton(x, y, 28, 24, key, function()

            if scope == IKST.CLEANUP_SCOPES.cube then

                state.cleanupCubeHalf = val

            else

                state.cleanupRadius = val

            end

            if IKST_PreviewOverlay then

                IKST_PreviewOverlay.clear()

            end

            panel:refreshJobUI()

        end, current == val)

        x = x + 34

    end



    if scope == IKST.CLEANUP_SCOPES.cube then

        local edge = IKST.cubeEdgeLength(state.cleanupCubeHalf)

        panel:makeJobButton(x + 8, y, 90, 24, edge .. " x " .. edge .. " x " .. edge, function() end, false)

    else

        panel:makeJobButton(x + 8, y, 80, 24, tostring(state.cleanupRadius) .. " tiles", function() end, false)

    end



    return y + 34

end



function IKST_JobCleanup.describeState(state)

    local action = IKST.cleanupActionLabel(IKST.getCleanupAction(state))

    local scope = IKST.cleanupScopeLabel(IKST.getCleanupScope(state), state)

    return action .. " · " .. scope

end



function IKST_JobCleanup.build(panel)

    local state = IKST.getPlayerState(panel.player)

    if not state then

        return

    end



    local y = 8

    y = IKST_JobCleanup.buildActionRow(panel, y, state)

    y = IKST_JobCleanup.buildScopeRow(panel, y, state)

    y = IKST_JobCleanup.buildSizeRow(panel, y, state)

    local roofHint = ISPanel:new(IKST_JobLayout.MARGIN, y, panel.contentW or (panel.width - 24), 18)
    roofHint.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    roofHint.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    roofHint:initialise()
    local hintText = IKST.text("IGUI_IKST_Tip_Roof", "Roofs: use Remove tile or Remove object with Cube scope (hits upper Z levels).")
    roofHint.render = function(p)
        ISPanel.render(p)
        local cc = IKST_Chrome.colors
        p:drawText(hintText, 0, 0, cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small)
    end
    panel:addJobWidget(roofHint)
    y = y + 22

    local active = IKST_JobCleanup.describeState(state)

    if state.armed and state.armedJob == IKST.VIEW.cleanup then

        active = active .. " [" .. IKST.text("IGUI_IKST_Armed", "ARMED") .. "]"

    end



    local barW = panel.contentW or (panel.width - 24)
    local bar = ISPanel:new(IKST_JobLayout.MARGIN, y, barW, 30)

    bar.backgroundColor = IKST_Chrome.colors.bgToolbar

    bar.borderColor = IKST_Chrome.colors.accentDim

    bar:initialise()

    bar.render = function(p)

        ISPanel.render(p)

        local cc = IKST_Chrome.colors

        p:drawText(IKST.text("IGUI_IKST_Active", "Active") .. ": " .. active, 8, 7,

            cc.textPrimary.r, cc.textPrimary.g, cc.textPrimary.b, 1, UIFont.Small)

    end

    panel:addJobWidget(bar)

    local rewindCount = IKST_Rewind.count(panel.player)
    local rewindLabel = IKST.text("IGUI_IKST_Rewind", "REWIND")
    if rewindCount > 0 then
        rewindLabel = rewindLabel .. " (" .. rewindCount .. ")"
    end
    panel:makeJobButton(IKST_JobLayout.MARGIN + barW - 188, y + 4, 88, 22, rewindLabel, function()
        IKST_WorldPick.disarm(panel.player)
        IKST.dispatchCommand(panel.player, IKST.CMD.rewind, {})
        panel:refreshJobUI()
    end, rewindCount > 0)
    panel:makeJobButton(IKST_JobLayout.MARGIN + barW - 92, y + 4, 84, 22, IKST.text("IGUI_IKST_Disarm", "DISARM"), function()
        IKST_WorldPick.disarm(panel.player)
        panel:refreshJobUI()
    end, false)

    y = y + 40

    IKST_ActionLog.dock(panel, panel.player, y)
    return y
end



function IKST_JobCleanup.enter(panel)

    panel:enterJob(IKST.VIEW.cleanup)

    IKST_JobCleanup.syncArm(panel)

end

