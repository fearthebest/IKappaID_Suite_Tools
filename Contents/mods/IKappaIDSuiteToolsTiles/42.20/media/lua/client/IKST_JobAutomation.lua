if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKappaID_UI_Framework/IKUI_Chrome"
require "IKST_JobLayout"

IKST_JobAutomation = IKST_JobAutomation or {}

function IKST_JobAutomation.radiusLabel(preset)
    if preset == IKST.RADIUS_PRESETS.S then
        return IKST.text("IGUI_IKST_Radius_S", "Small") .. " (" .. preset .. ")"
    end
    if preset == IKST.RADIUS_PRESETS.L then
        return IKST.text("IGUI_IKST_Radius_L", "Large") .. " (" .. preset .. ")"
    end
    return IKST.text("IGUI_IKST_Radius_M", "Medium") .. " (" .. preset .. ")"
end

function IKST_JobAutomation.dispatchRadius(panel, command)
    local p = panel.player
    local state = IKST.getPlayerState(p)
    local radius = state and state.autoRadius or IKST.RADIUS_PRESETS.M
    IKST.dispatchCommand(p, command, {
        x = math.floor(p:getX()),
        y = math.floor(p:getY()),
        z = p:getZ(),
        radius = radius,
    })
end

function IKST_JobAutomation.build(panel)
    if IKST_SoftTool_Tiles and type(IKST_SoftTool_Tiles.buildArea) == "function" then
        return IKST_SoftTool_Tiles.buildArea(panel)
    end
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return 8
    end
    if not state.autoRadius then
        state.autoRadius = IKST.RADIUS_PRESETS.M
    end

    local rect = IKST_JobLayout.toolContentRect(panel)
    local gap = 6
    local bands, stackBottom, soft = IKST_JobLayout.toolBands(panel, rect, 2, gap, { 1, 3 })
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
        local card, ax, ay, aw, ah = openBand(bands[1], IKST.text("IGUI_IKST_SectionRadius", "Radius"))
        local items = {}
        for _, key in ipairs({ "S", "M", "L" }) do
            local preset = IKST.RADIUS_PRESETS[key]
            if preset then
                local val = preset
                items[#items + 1] = {
                    label = key,
                    primary = state.autoRadius == val,
                    onClick = function()
                        state.autoRadius = val
                        panel:refreshJobUI()
                    end,
                }
            end
        end
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, items)
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[2], IKST.text("IGUI_IKST_TilesTile_SectionAuto", "Actions"))
        local actions = {
            { cmd = IKST.CMD.autoGardener, label = IKST.text("IGUI_IKST_Auto_Gardener", "Gardener") },
            { cmd = IKST.CMD.autoLumberjack, label = IKST.text("IGUI_IKST_Auto_Lumberjack", "Lumberjack") },
            { cmd = IKST.CMD.autoGravel, label = IKST.text("IGUI_IKST_Auto_Gravel", "Gravel") },
            { cmd = IKST.CMD.autoCorpseStack, label = IKST.text("IGUI_IKST_Auto_Corpse", "Corpse"), primary = true },
            { cmd = IKST.CMD.autoHomeWreck, label = IKST.text("IGUI_IKST_Auto_HomeWreck", "Home wrecker") },
            { cmd = IKST.CMD.autoFarmer, label = IKST.text("IGUI_IKST_Auto_Farmer", "Farmer") },
            { cmd = IKST.CMD.autoUnloadContainers, label = IKST.text("IGUI_IKST_Auto_Unload", "Unload") },
        }
        local items = {}
        for i = 1, #actions do
            local action = actions[i]
            items[#items + 1] = {
                label = action.label,
                primary = action.primary == true,
                onClick = function()
                    IKST_JobAutomation.dispatchRadius(panel, action.cmd)
                end,
            }
        end
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, items)
    end

    panel._ikstToolFit = true
    if soft then
        return stackBottom + gap
    end
    return rect.y + rect.h
end
