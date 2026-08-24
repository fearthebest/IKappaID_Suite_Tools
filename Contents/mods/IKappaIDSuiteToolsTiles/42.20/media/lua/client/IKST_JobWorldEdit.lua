if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Plugins"
require "IKappaID_UI/IKUI_Chrome"
require "IKST_JobLayout"
require "IKST_JobGuard"
require "IKST_JobAutomation"
require "IKST_JobCleanup"
require "IKST_JobPainter"
require "IKST_JobInspector"
require "IKST_JobStaff"
require "IKST_JobTilesGuard"
require "IKST_WorldPick"

IKST_JobWorldEdit = IKST_JobWorldEdit or {}

-- Overview is a directory only: pills describe tools and open that tab. Never arm.
function IKST_JobWorldEdit.buildOverview(panel)
    local p = panel.player
    if not p then
        return 8
    end

    local rect = IKST_JobLayout.toolContentRect(panel)
    local gap = 6
    local bands = IKST_JobLayout.splitBands(rect.y, rect.h, 5, gap)
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

    local function go(toolId)
        if panel and type(panel.enterNav) == "function" then
            panel:enterNav(IKST.VIEW.tiles, toolId)
        end
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[1], IKST.text("IGUI_IKST_Job_Cleanup", "Remove Stuff"))
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.cleanupActionLabel(IKST.CLEANUP_MODES.removeObject),
                primary = true,
                onClick = function()
                    go("remove")
                end,
            },
            {
                label = IKST.cleanupActionLabel(IKST.CLEANUP_MODES.removeTile),
                onClick = function()
                    go("remove")
                end,
            },
            {
                label = IKST.cleanupActionLabel(IKST.CLEANUP_MODES.vegetation),
                onClick = function()
                    go("remove")
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[2], IKST.text("IGUI_IKST_Job_Painter", "Paint Tiles"))
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_Paint", "Paint"),
                primary = true,
                onClick = function()
                    go("paint")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Eyedropper", "Eyedropper"),
                onClick = function()
                    go("paint")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Replace", "Replace tile"),
                onClick = function()
                    go("paint")
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[3], IKST.text("IGUI_IKST_TilesTile_SectionInspect", "Inspect & build"))
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_Job_Inspector", "Inspect Tile"),
                primary = true,
                onClick = function()
                    go("inspect")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_TilesTile_ContainerAudit", "Container audit"),
                onClick = function()
                    go("inspect")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Guard_BpCopy", "Copy build"),
                onClick = function()
                    go("blueprints")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Guard_BpPaste", "Paste build"),
                onClick = function()
                    go("blueprints")
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[4], IKST.text("IGUI_IKST_Job_Automation", "Area jobs"))
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_Job_Automation", "Area jobs"),
                primary = true,
                onClick = function()
                    go("area")
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[5], IKST.text("IGUI_IKST_Tool_Protect", "Protection"))
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_Protect_Square", "Protect square"),
                primary = true,
                onClick = function()
                    go("protect")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Protect_Unhere", "Unprotect square"),
                onClick = function()
                    go("protect")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Protect_KeypadSection", "Keypad lock"),
                onClick = function()
                    go("protect")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Guard_Dropbox", "Drop box"),
                onClick = function()
                    go("protect")
                end,
            },
        })
    end

    panel._ikstToolFit = true
    return rect.y + rect.h
end

function IKST_JobWorldEdit.build(panel)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return 8
    end
    local tool = state.navTool or "overview"
    if tool == "overview" and IKST_JobWorldEdit.buildOverview then
        return IKST_JobWorldEdit.buildOverview(panel)
    end
    if IKST.Plugins and IKST.Plugins.buildJobTool then
        local y = IKST.Plugins.buildJobTool(panel, tool)
        if y then
            return y
        end
    end
    return 8
end

function IKST_JobWorldEdit.buildForServer(panel)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return 8
    end
    local tool = state.navTool
    if tool == "safehouses" and IKST_JobGuard then
        return IKST_JobGuard.build(panel) or 8
    end
    if tool == "players" and IKST_JobStaff then
        return IKST_JobStaff.build(panel) or 8
    end
    if tool == "overview" and IKST_JobWorldEdit.buildOverview then
        return IKST_JobWorldEdit.buildOverview(panel)
    end
    if IKST.Plugins and IKST.Plugins.buildJobTool then
        local y = IKST.Plugins.buildJobTool(panel, tool)
        if y then
            return y
        end
    end
    return 8
end
