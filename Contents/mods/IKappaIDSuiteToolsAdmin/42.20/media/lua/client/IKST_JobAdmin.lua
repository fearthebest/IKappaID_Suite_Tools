if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISLabel"
require "ISUI/ISPanel"
require "ISUI/ISTextEntryBox"
require "IKST_Shared"
require "IKappaID_UI/IKUI_Chrome"
require "IKST_UI_Layout"
require "IKST_JobLayout"
require "IKST_JobStaff"
require "IKST_Confirm"

IKST_JobAdmin = IKST_JobAdmin or {}

local function ghostOn(player)
    return player and type(player.isGhostMode) == "function" and player:isGhostMode() == true
end

local function readReason(panel)
    if panel.adminReasonBox and type(panel.adminReasonBox.getText) == "function" then
        local t = panel.adminReasonBox:getText() or ""
        t = string.gsub(t, "^%s*(.-)%s*$", "%1")
        if #t > 64 then
            t = string.sub(t, 1, 64)
        end
        return t
    end
    return ""
end

local function selectedTarget(panel)
    if IKST_JobStaff and type(IKST_JobStaff.getSelectedTarget) == "function" then
        return IKST_JobStaff.getSelectedTarget(panel)
    end
    return nil
end

local function dispatchOnTarget(panel, cmd, confirmKey, confirmFallback)
    local p = panel.player
    local target = selectedTarget(panel)
    if not target then
        IKST.notify(p, IKST.text("IGUI_IKST_UtilTile_NoTarget", "No target selected"), false)
        return
    end
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        IKST.notify(p, IKST.text("IGUI_IKST_Admin_MpOnly", "Kick and ban are multiplayer only"), false)
        return
    end
    local reason = readReason(panel)
    local name = tostring(target.name or "?")
    local msg = IKST.text(confirmKey, confirmFallback) .. " " .. name .. "?"
    IKST_Confirm.showDestructive(msg, function()
        IKST.dispatchCommand(p, cmd, { target = target.id, reason = reason })
    end)
end

function IKST_JobAdmin.build(panel)
    local p = panel.player
    if not p then
        return 8
    end

    if IKST.isMultiplayerSession() and #(IKST_JobStaff.onlinePlayers or {}) == 0
        and not panel._adminPlayersRequested then
        panel._adminPlayersRequested = true
        IKST_JobStaff.requestPlayers(p)
    end

    local rect = IKST_JobLayout.toolContentRect(panel)
    local gap = 6
    local bands = IKST_JobLayout.splitBands(rect.y, rect.h, 3, gap)
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
        local card, ax, ay, aw, ah = openBand(bands[1], IKST.text("IGUI_IKST_UtilTile_SectionPlayers", "Players"))
        local listH, pillH, gapLP = IKST_JobLayout.listPillSplit(ah, 1, true)
        local visible = IKST_JobLayout.rowsForListHeight(listH)
        local listBottom = IKST_JobStaff.buildPlayerSelectList(panel, card, ax, ay, aw, visible)
        local actionY = listBottom + gapLP
        local actionH = math.max(btnH, pillH)
        if actionY + actionH > ay + ah then
            actionY = math.max(ay, ay + ah - actionH)
        end
        IKST_JobLayout.placePillGroup(panel, card, ax, actionY, aw, actionH, {
            {
                label = IKST.text("IGUI_IKST_AdminGhostSelf", "Ghost (self)"),
                primary = ghostOn(p) == true,
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.ghostSelf, {})
                    panel:refreshJobUI()
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[2], IKST.text("IGUI_IKST_Admin_Reason", "Moderation"))
        IKST_JobLayout.placeFieldActionCorner(panel, card, ax, ay, aw, ah, {
            { text = "", fieldName = "adminReasonBox" },
        }, IKST.text("IGUI_IKST_UtilTile_KickPlayer", "Kick"), function()
            dispatchOnTarget(panel, IKST.CMD.kickPlayer, "IGUI_IKST_Admin_ConfirmKick", "Kick")
        end)
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[3], IKST.text("IGUI_IKST_UtilTile_BanPlayer", "Ban"))
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_UtilTile_BanPlayer", "Ban"),
                primary = true,
                onClick = function()
                    dispatchOnTarget(panel, IKST.CMD.banPlayer, "IGUI_IKST_Admin_ConfirmBan", "Ban")
                end,
            },
        })
    end

    panel._ikstToolFit = true
    return rect.y + rect.h
end
