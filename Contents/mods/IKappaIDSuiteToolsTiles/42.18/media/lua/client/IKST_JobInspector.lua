if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Chrome"
require "IKST_JobLayout"

IKST_JobInspector = IKST_JobInspector or {}

function IKST_JobInspector.inspectAtPlayer(panel)
    local p = panel.player
    if not p then
        return
    end
    IKST.dispatchCommand(p, IKST.CMD.inspectSquare, {
        x = math.floor(p:getX()),
        y = math.floor(p:getY()),
        z = p:getZ(),
    })
end

function IKST_JobInspector.build(panel)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return 8
    end

    local y = 8
    local armed = state.armed and state.armedJob == IKST.VIEW.inspector

    panel:makeJobButton(12, y, 160, 24, IKST.text("IGUI_IKST_ArmInspect", "Arm inspect cursor"), function()
        if IKST_WorldPick and IKST_WorldPick.armInspect then
            IKST_WorldPick.armInspect(panel.player)
        end
        panel:refreshJobUI()
    end, armed)

    panel:makeJobButton(180, y, 120, 24, IKST.text("IGUI_IKST_InspectHere", "Inspect here"), function()
        IKST_JobInspector.inspectAtPlayer(panel)
    end, false)

    panel:makeJobButton(IKST_JobLayout.contentRight(panel) - 84, y, 84, 22, IKST.text("IGUI_IKST_Disarm", "DISARM"), function()
        if IKST_WorldPick and IKST_WorldPick.disarm then
            IKST_WorldPick.disarm(panel.player)
        end
        panel:refreshJobUI()
    end, false)

    y = y + 34

    local inspect = state.lastInspect
    local header = IKST.text("IGUI_IKST_NoInspect", "Click a square to inspect objects and sprites.")
    if inspect and inspect.x then
        header = string.format("Square %d, %d, %d", inspect.x, inspect.y, inspect.z or 0)
    end

    local info = ISPanel:new(IKST_JobLayout.MARGIN, y, panel.contentW or (panel.width - 24), 36)
    info.backgroundColor = IKST_Chrome.colors.bgCard
    info.borderColor = IKST_Chrome.colors.accentDim
    info:initialise()
    info.render = function(p)
        ISPanel.render(p)
        local cc = IKST_Chrome.colors
        p:drawText(header, 8, 10, cc.textPrimary.r, cc.textPrimary.g, cc.textPrimary.b, 1, UIFont.Small)
    end
    panel:addJobWidget(info)
    y = y + 44

    if inspect and inspect.items then
        for i, item in ipairs(inspect.items) do
            if i > 14 then
                break
            end
            local label = tostring(item.name or "object")
            if item.isFloor then
                label = label .. " (floor)"
            end
            local rowY = y
            local row = ISPanel:new(IKST_JobLayout.MARGIN, rowY, panel.contentW or (panel.width - 24), 20)
            row.backgroundColor = IKST_Chrome.colors.bgToolbar
            row.borderColor = { r = 0, g = 0, b = 0, a = 0 }
            row:initialise()
            row.render = function(p)
                ISPanel.render(p)
                local cc = IKST_Chrome.colors
                p:drawText(label, 8, 3, cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small)
            end
            panel:addJobWidget(row)
            y = y + 22
        end
    end

    IKST_ActionLog.dock(panel, panel.player, y)
    return y
end
