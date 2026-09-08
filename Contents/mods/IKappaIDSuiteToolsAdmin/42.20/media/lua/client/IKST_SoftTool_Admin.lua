-- SoftTool Admin: soft-shell Admin workspace painted via IKUI_SoftBody.
-- Kick/ban/ghost dispatch stays on IKST.dispatchCommand; player list via JobStaff.
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_JobStaff"
require "IKST_Confirm"
require "IKappaID_UI/IKUI_SoftBody"

IKST_SoftTool_Admin = IKST_SoftTool_Admin or {}

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

local function ensurePlayers(panel, p)
    if IKST.isMultiplayerSession() and #(IKST_JobStaff.onlinePlayers or {}) == 0
        and not panel._adminPlayersRequested then
        panel._adminPlayersRequested = true
        IKST_JobStaff.requestPlayers(p)
    end
end

local function openCol(panel, col, title)
    local card, contentY = IKUI_SoftBody.section(panel, col.x, col.y, col.w, col.h, title)
    local inner = IKUI_SoftBody.SECTION_INNER
    local padY = 8
    local btnH = IKUI_SoftBody.STANDARD_BTN_H
    return card, inner, contentY + padY, math.max(40, col.w - inner * 2), math.max(btnH, col.h - contentY - padY * 2)
end

local function buildMasterDetail(panel, leftTitle, rightTitle, rightFill)
    local p = panel.player
    ensurePlayers(panel, p)
    local rect = IKUI_SoftBody.contentRect(panel)
    local left, right = IKUI_SoftBody.masterDetail(rect, 280, 12)
    do
        local card, ax, ay, aw, ah = openCol(panel, left, leftTitle)
        local listH = math.max(48, ah - (math.max(22, 22) + 6))
        IKST_JobStaff.buildPlayerSelectList(panel, card, ax, ay, aw, nil, listH)
    end
    do
        local card, ax, ay, aw, ah = openCol(panel, right, rightTitle)
        rightFill(panel, card, ax, ay, aw, ah, p)
    end
    return rect.y + rect.h
end

function IKST_SoftTool_Admin.buildGhost(panel)
    return buildMasterDetail(panel,
        IKST.text("IGUI_IKST_UtilTile_SectionPlayers", "Players"),
        IKST.text("IGUI_IKST_AdminGhostSelf", "Ghost mode"),
        function(panelRef, card, ax, ay, aw, ah, p)
            IKUI_SoftBody.pillRow(panelRef, card, ax, ay, aw, ah, {
                {
                    label = IKST.text("IGUI_IKST_AdminGhostSelf", "Ghost (self)"),
                    primary = ghostOn(p) == true,
                    onClick = function()
                        IKST.dispatchCommand(p, IKST.CMD.ghostSelf, {})
                        panelRef:refreshJobUI()
                    end,
                },
            })
        end)
end

function IKST_SoftTool_Admin.buildKick(panel)
    return buildMasterDetail(panel,
        IKST.text("IGUI_IKST_UtilTile_SectionPlayers", "Players & moderation"),
        IKST.text("IGUI_IKST_Admin_Reason", "Reason"),
        function(panelRef, card, ax, ay, aw, ah, _p)
            IKUI_SoftBody.fieldAction(panelRef, card, ax, ay, aw, ah, {
                { text = "", fieldName = "adminReasonBox" },
            }, IKST.text("IGUI_IKST_UtilTile_KickPlayer", "Kick"), function()
                dispatchOnTarget(panelRef, IKST.CMD.kickPlayer, "IGUI_IKST_Admin_ConfirmKick", "Kick")
            end)
        end)
end

function IKST_SoftTool_Admin.buildBan(panel)
    return buildMasterDetail(panel,
        IKST.text("IGUI_IKST_UtilTile_SectionPlayers", "Players & moderation"),
        IKST.text("IGUI_IKST_UtilTile_BanPlayer", "Ban player"),
        function(panelRef, card, ax, ay, aw, ah, _p)
            IKUI_SoftBody.fieldAction(panelRef, card, ax, ay, aw, ah, {
                { text = "", fieldName = "adminReasonBox" },
            }, IKST.text("IGUI_IKST_UtilTile_BanPlayer", "Ban"), function()
                dispatchOnTarget(panelRef, IKST.CMD.banPlayer, "IGUI_IKST_Admin_ConfirmBan", "Ban")
            end)
        end)
end

function IKST_SoftTool_Admin.build(panel)
    local p = panel.player
    if not p then
        return 8
    end
    local state = IKST.getPlayerState(p)
    local tool = (state and state.navTool) or (state and state.adminTool) or "ghost"
    if tool == "admin" then
        tool = "ghost"
    end
    if tool == "kick" then
        return IKST_SoftTool_Admin.buildKick(panel)
    end
    if tool == "ban" then
        return IKST_SoftTool_Admin.buildBan(panel)
    end
    return IKST_SoftTool_Admin.buildGhost(panel)
end
