if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISLabel"
require "IKST_Shared"
require "IKappaID_UI/IKUI_Chrome"
require "IKST_JobLayout"
require "IKST_WorldPick"

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

    local rect = IKST_JobLayout.toolContentRect(panel)
    local gap = 6
    local bands = IKST_JobLayout.splitBands(rect.y, rect.h, 2, gap)
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

    local armed = state.armed and state.armedJob == IKST.VIEW.inspector

    do
        local card, ax, ay, aw, ah = openBand(bands[1], IKST.text("IGUI_IKST_SectionArm", "Arm"))
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_ArmInspect", "Arm inspect"),
                primary = armed and not (state.inspectAudit == true),
                onClick = function()
                    if IKST_WorldPick and type(IKST_WorldPick.armInspect) == "function" then
                        IKST_WorldPick.armInspect(panel.player)
                    end
                    panel:refreshJobUI()
                end,
            },
            {
                label = IKST.text("IGUI_IKST_TilesTile_ContainerAudit", "Container audit"),
                primary = armed and state.inspectAudit == true,
                onClick = function()
                    if IKST_WorldPick and type(IKST_WorldPick.armInspect) == "function" then
                        IKST_WorldPick.armInspect(panel.player, false, true)
                    end
                    panel:refreshJobUI()
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Disarm", "Disarm"),
                onClick = function()
                    if IKST_WorldPick and type(IKST_WorldPick.disarm) == "function" then
                        IKST_WorldPick.disarm(panel.player)
                    end
                    panel:refreshJobUI()
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[2], IKST.text("IGUI_IKST_SectionResults", "Results"))
        local inspect = state.lastInspect
        local header = IKST.text("IGUI_IKST_NoInspect", "Click a square to inspect objects and sprites.")
        if inspect and inspect.x then
            header = IKST.text("IGUI_IKST_Inspect_Square", "Square {1}, {2}, {3}")
            header = string.gsub(header, "{1}", tostring(inspect.x))
            header = string.gsub(header, "{2}", tostring(inspect.y))
            header = string.gsub(header, "{3}", tostring(inspect.z or 0))
        end
        local lineH = 16
        local note = ISLabel:new(ax, ay, lineH, header, 1, 1, 1, 1, UIFont.Small, true)
        note:initialise()
        card:addChild(note)

        local rows = {}
        if inspect and inspect.items then
            for i, item in ipairs(inspect.items) do
                if i > 24 then
                    break
                end
                local label = tostring(item.name or IKST.text("IGUI_IKST_Inspect_Object", "object"))
                if item.isFloor then
                    label = label .. " " .. IKST.text("IGUI_IKST_Inspect_Floor", "(floor)")
                end
                rows[#rows + 1] = { id = i, label = label, data = item }
                local extra = item.containerItems
                if type(extra) == "table" then
                    local max = #extra
                    if max > 6 then
                        max = 6
                    end
                    for n = 1, max do
                        local entry = extra[n]
                        rows[#rows + 1] = {
                            id = i .. ":" .. n,
                            label = "  " .. tostring(entry.count or 1) .. "x " .. tostring(entry.name or "?"),
                            data = entry,
                        }
                    end
                end
            end
        end
        local listY = ay + lineH + 6
        local listH = math.max(40, ah - lineH - 6)
        IKST_JobLayout.makeSelectList(panel, card, ax, listY, aw, listH, rows, {})
    end

    panel._ikstToolFit = true
    return rect.y + rect.h
end
