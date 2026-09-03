if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISLabel"
require "IKST_Shared"
require "IKappaID_UI/IKUI_Chrome"
require "IKST_PreviewOverlay"
require "IKST_Rewind"
require "IKST_JobLayout"
require "IKST_WorldPick"

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
    if IKST_WorldPick and type(IKST_WorldPick.arm) == "function" then
        IKST_WorldPick.arm(panel.player, IKST.getCleanupAction(state), IKST.getCleanupScope(state), true)
    end
end

function IKST_JobCleanup.describeState(state)
    local action = IKST.cleanupActionLabel(IKST.getCleanupAction(state))
    local scope = IKST.cleanupScopeLabel(IKST.getCleanupScope(state), state)
    return action .. " · " .. scope
end

function IKST_JobCleanup.build(panel)
    if IKST_SoftTool_Tiles and type(IKST_SoftTool_Tiles.buildRemove) == "function" then
        return IKST_SoftTool_Tiles.buildRemove(panel)
    end
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return 8
    end

    local rect = IKST_JobLayout.toolContentRect(panel)
    local gap = 6
    local bands, stackBottom, soft = IKST_JobLayout.toolBands(panel, rect, 4, gap, { 3, 2, 1, 1 })
    local inner = IKST_JobLayout.SECTION_INNER
    local padY = IKST_JobLayout.CONTENT_PAD_Y
    local btnH = IKST_JobLayout.STANDARD_BTN_H

    local function openBand(band, title)
        local card, contentY = IKST_JobLayout.placeSectionCard(panel, rect.x, band.y, rect.w, band.h, nil, title)
        local areaX = inner
        local areaW = math.max(40, rect.w - inner * 2)
        local areaY = contentY + padY
        local areaH = math.max(btnH, band.h - contentY - padY * 2)
        return card, areaX, areaY, areaW, areaH
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[1], IKST.text("IGUI_IKST_Action_Label", "Action"))
        local items = {}
        for _, action in ipairs(IKST.CLEANUP_ACTIONS) do
            local id = action
            items[#items + 1] = {
                label = IKST.cleanupActionLabel(id),
                primary = IKST.getCleanupAction(state) == id,
                onClick = function()
                    IKST_JobCleanup.selectAction(panel, id)
                end,
            }
        end
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, items)
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[2], IKST.text("IGUI_IKST_Scope_Label", "Scope"))
        local items = {}
        for _, scope in ipairs(IKST.CLEANUP_SCOPE_LIST) do
            local id = scope
            items[#items + 1] = {
                label = IKST.cleanupScopeLabel(id, state),
                primary = IKST.getCleanupScope(state) == id,
                onClick = function()
                    IKST_JobCleanup.selectScope(panel, id)
                end,
            }
        end
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, items)
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[3], IKST.text("IGUI_IKST_Size_Label", "Size"))
        local scope = IKST.getCleanupScope(state)
        local useCube = scope == IKST.CLEANUP_SCOPES.cube
        local presets = useCube and IKST.CUBE_PRESETS or IKST.RADIUS_PRESETS
        local current = useCube and state.cleanupCubeHalf or state.cleanupRadius
        local items = {}
        for _, key in ipairs({ "S", "M", "L" }) do
            local val = presets[key]
            if val then
                local k = key
                local v = val
                items[#items + 1] = {
                    label = k,
                    primary = current == v,
                    onClick = function()
                        local sc = IKST.getCleanupScope(state)
                        if sc ~= IKST.CLEANUP_SCOPES.cube and sc ~= IKST.CLEANUP_SCOPES.radius then
                            state.cleanupScope = IKST.CLEANUP_SCOPES.radius
                            sc = IKST.CLEANUP_SCOPES.radius
                        end
                        if sc == IKST.CLEANUP_SCOPES.cube then
                            state.cleanupCubeHalf = IKST.CUBE_PRESETS[k] or v
                        else
                            state.cleanupRadius = IKST.RADIUS_PRESETS[k] or v
                        end
                        if IKST_PreviewOverlay then
                            IKST_PreviewOverlay.clear()
                        end
                        IKST_JobCleanup.syncArm(panel)
                        panel:refreshJobUI()
                    end,
                }
            end
        end
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, items)
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[4], IKST.text("IGUI_IKST_Active", "Active"))
        local rewindCount = 0
        if IKST_Rewind and type(IKST_Rewind.count) == "function" then
            rewindCount = IKST_Rewind.count(panel.player) or 0
        end
        local rewindLabel = IKST.text("IGUI_IKST_Rewind", "REWIND")
        if rewindCount > 0 then
            rewindLabel = rewindLabel .. " (" .. tostring(rewindCount) .. ")"
        end
        local armed = state.armed and state.armedJob == IKST.VIEW.cleanup
        local active = IKST_JobCleanup.describeState(state)
        if armed then
            active = active .. " [" .. IKST.text("IGUI_IKST_Armed", "ARMED") .. "]"
        end
        local noteH = 16
        local note = ISLabel:new(ax, ay, noteH, active, 1, 1, 1, 1, UIFont.Small, true)
        note:initialise()
        card:addChild(note)
        IKST_JobLayout.placePillGroup(panel, card, ax, ay + noteH + 4, aw, math.max(btnH, ah - noteH - 4), {
            {
                label = rewindLabel,
                primary = rewindCount > 0,
                onClick = function()
                    if IKST_WorldPick and type(IKST_WorldPick.disarm) == "function" then
                        IKST_WorldPick.disarm(panel.player)
                    end
                    IKST.dispatchCommand(panel.player, IKST.CMD.rewind, {})
                    panel:refreshJobUI()
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Disarm", "DISARM"),
                primary = true,
                onClick = function()
                    if IKST_WorldPick and type(IKST_WorldPick.disarm) == "function" then
                        IKST_WorldPick.disarm(panel.player)
                    end
                    panel:refreshJobUI()
                end,
            },
        })
    end

    panel._ikstToolFit = true
    if soft then
        return stackBottom + gap
    end
    return rect.y + rect.h
end

function IKST_JobCleanup.enter(panel)
    panel:enterJob(IKST.VIEW.cleanup)
    IKST_JobCleanup.syncArm(panel)
end
