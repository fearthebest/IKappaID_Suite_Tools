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
    end, armed and not (state.inspectAudit == true))

    panel:makeJobButton(178, y, 150, 24, IKST.text("IGUI_IKST_TilesTile_ContainerAudit", "Container audit"), function()
        if IKST_WorldPick and IKST_WorldPick.armInspect then
            IKST_WorldPick.armInspect(panel.player, false, true)
        end
        panel:refreshJobUI()
    end, armed and state.inspectAudit == true)

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
        header = IKST.text("IGUI_IKST_Inspect_Square", "Square %1, %2, %3")
        header = string.gsub(header, "%%1", tostring(inspect.x))
        header = string.gsub(header, "%%2", tostring(inspect.y))
        header = string.gsub(header, "%%3", tostring(inspect.z or 0))
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
            local label = tostring(item.name or IKST.text("IGUI_IKST_Inspect_Object", "object"))
            if item.isFloor then
                label = label .. " " .. IKST.text("IGUI_IKST_Inspect_Floor", "(floor)")
            end
            local rowY = y
            local rowH = 20
            local extra = item.containerItems
            if type(extra) == "table" and #extra > 0 then
                rowH = 20 + (#extra * 16)
                if #extra > 8 then
                    rowH = 20 + (8 * 16)
                end
            end
            local row = ISPanel:new(IKST_JobLayout.MARGIN, rowY, panel.contentW or (panel.width - 24), rowH)
            row.backgroundColor = IKST_Chrome.colors.bgToolbar
            row.borderColor = { r = 0, g = 0, b = 0, a = 0 }
            row:initialise()
            row.render = function(p)
                ISPanel.render(p)
                local cc = IKST_Chrome.colors
                p:drawText(label, 8, 3, cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small)
                if type(extra) == "table" then
                    local max = #extra
                    if max > 8 then
                        max = 8
                    end
                    for n = 1, max do
                        local entry = extra[n]
                        local line = "  " .. tostring(entry.count or 1) .. "x " .. tostring(entry.name or "?")
                        p:drawText(line, 8, 4 + (n * 16), cc.textPrimary.r, cc.textPrimary.g, cc.textPrimary.b, 1, UIFont.Small)
                    end
                end
            end
            panel:addJobWidget(row)
            y = y + rowH + 2
        end
    end

    return y
end
