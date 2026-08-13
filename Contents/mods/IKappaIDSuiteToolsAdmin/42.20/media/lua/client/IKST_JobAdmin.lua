if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISLabel"
require "ISUI/ISPanel"
require "ISUI/ISTextEntryBox"
require "IKST_Shared"
require "IKST_Chrome"
require "IKST_UI_Layout"
require "IKST_JobLayout"
require "IKST_JobStaff"
require "IKST_Confirm"

IKST_JobAdmin = IKST_JobAdmin or {}

local function ghostOn(player)
    return player and type(player.isGhostMode) == "function" and player:isGhostMode() == true
end

local function readReason(panel)
    if panel.adminReasonBox and panel.adminReasonBox.getText then
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
    if IKST_JobStaff and IKST_JobStaff.getSelectedTarget then
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
    local x = panel.contentX or IKST_JobLayout.MARGIN
    local w = math.max(220, panel.contentW or (panel.width - 24))
    local y = 8
    local gap = IKST_JobLayout.GAP or IKST_UI_Layout.s(12)
    local headerBtnH = math.max(24, IKST_UI_Layout.s(28))

    local title = IKST.text("IGUI_IKST_WS_Admin", "Admin")
    local titleLabel = ISLabel:new(x, y, 26, title, 1, 1, 1, 1, UIFont.Large, true)
    titleLabel:initialise()
    panel:addJobWidget(titleLabel)

    local spectatorLabel = IKST.text("IGUI_IKST_UtilTile_Spectator", "Spectator")
    local spectatorW = IKST_UI_Layout.buttonWidth(spectatorLabel, UIFont.Small, 90)
    local spectatorKind = ghostOn(p) and "primary" or "chip"
    local spectatorBtn = IKST_Chrome.newActionButton(
        x + w - spectatorW, y, spectatorW, headerBtnH, spectatorLabel, panel, function()
            IKST.dispatchCommand(p, IKST.CMD.ghostSelf, {})
            panel:refreshJobUI()
        end, spectatorKind)
    panel:addJobWidget(spectatorBtn)

    y = y + math.max(26, headerBtnH) + gap

    if IKST.isMultiplayerSession() and #(IKST_JobStaff.onlinePlayers or {}) == 0
        and not panel._adminPlayersRequested then
        panel._adminPlayersRequested = true
        IKST_JobStaff.requestPlayers(p)
    end

    local rowH = math.max(26, IKST_UI_Layout.s(30))
    local padX = IKST_UI_Layout.s(14)
    local headerH = IKST_Chrome.sectionHeaderH()
    local bottomPad = IKST_UI_Layout.s(14)
    local reasonH = 22
    local hintH = 16
    local filterLabelH = 16
    local listH = IKST_JobLayout.selectListHeight(8)
    local contentH = filterLabelH + 6 + 22 + 6 + listH + gap + rowH + gap + reasonH + gap + rowH + gap + hintH
    local cardH = headerH + contentH + bottomPad
    local card, contentY = IKST_Chrome.newSectionCardPanel(
        x, y, w, cardH, "media/ui/ikst/tool_players.png",
        IKST.text("IGUI_IKST_UtilTile_SectionPlayers", "Players & moderation"))
    panel:addJobWidget(card)

    local cc = IKST_Chrome.colors
    local innerW = math.max(80, w - (padX * 2))
    local filterLbl = ISLabel:new(padX, contentY, filterLabelH,
        IKST.text("IGUI_IKST_ListFilter", "Filter"),
        cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small, true)
    filterLbl:initialise()
    card:addChild(filterLbl)
    local listY = IKST_JobStaff.buildPlayerSelectList(panel, card, padX, contentY + filterLabelH + 4, innerW, 8)

    local target = selectedTarget(panel)
    local targetText
    local noTargetMsg = IKST.text("IGUI_IKST_UtilTile_NoTarget", "No target selected")
    if target then
        targetText = IKST.text("IGUI_IKST_UtilTile_Target", "Target") .. ": " .. tostring(target.name or "?")
    elseif IKST.isMultiplayerSession() and #(IKST_JobStaff.onlinePlayers or {}) == 0 then
        targetText = IKST.text("IGUI_IKST_UtilTile_NoOtherPlayers", "No other players online")
    else
        targetText = noTargetMsg
    end
    local nameLabel = ISLabel:new(padX, listY + 6, 16, targetText,
        cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small, true)
    nameLabel:initialise()
    card:addChild(nameLabel)

    local reasonY = listY + rowH + gap
    local reasonLabel = ISLabel:new(padX, reasonY + 2, 16,
        IKST.text("IGUI_IKST_Admin_Reason", "Reason"),
        cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small, true)
    reasonLabel:initialise()
    card:addChild(reasonLabel)
    local reasonX = padX + IKST_UI_Layout.buttonWidth(
        IKST.text("IGUI_IKST_Admin_Reason", "Reason"), UIFont.Small, 56) + 8
    panel.adminReasonBox = ISTextEntryBox:new("", reasonX, reasonY, math.max(80, w - reasonX - padX), reasonH)
    panel.adminReasonBox:initialise()
    panel.adminReasonBox:instantiate()
    card:addChild(panel.adminReasonBox)

    local btnY = reasonY + reasonH + gap
    local kickLabel = IKST.text("IGUI_IKST_UtilTile_KickPlayer", "Kick player")
    local banLabel = IKST.text("IGUI_IKST_UtilTile_BanPlayer", "Ban player")
    local kickW = IKST_UI_Layout.buttonWidth(kickLabel, UIFont.Small, 96)
    local banW = IKST_UI_Layout.buttonWidth(banLabel, UIFont.Small, 96)
    local kickBtn = IKST_Chrome.newActionButton(padX, btnY, kickW, rowH, kickLabel, panel, function()
        dispatchOnTarget(panel, IKST.CMD.kickPlayer, "IGUI_IKST_Admin_ConfirmKick", "Kick")
    end, "outline")
    card:addChild(kickBtn)
    local banBtn = IKST_Chrome.newActionButton(padX + kickW + 8, btnY, banW, rowH, banLabel, panel, function()
        dispatchOnTarget(panel, IKST.CMD.banPlayer, "IGUI_IKST_Admin_ConfirmBan", "Ban")
    end, "danger")
    card:addChild(banBtn)

    local hint = ISLabel:new(padX, btnY + rowH + gap, 16,
        IKST.text("IGUI_IKST_Admin_BanHint", "Ban writes vanilla username and Steam ID lists, then disconnects."),
        cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small, true)
    hint:initialise()
    card:addChild(hint)

    return y + cardH + gap
end
