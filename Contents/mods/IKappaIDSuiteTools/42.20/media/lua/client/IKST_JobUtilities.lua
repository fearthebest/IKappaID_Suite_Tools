if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISTextEntryBox"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "IKST_Shared"
require "IKST_Chrome"
require "IKST_ActionLog"
require "IKST_JobLayout"
require "IKST_JobStaff"
require "IKST_JobThreat"
require "IKST_QuickActions"
require "IKST_ClientStaff"
require "IKST_StaffCheats"

IKST_JobUtilities = IKST_JobUtilities or {}

function IKST_JobUtilities.buildServerTools(panel)
    local p = panel.player
    local state = IKST.getPlayerState(p)
    local y = 8

    y = panel:makeJobHeader(12, y, IKST.text("IGUI_IKST_Util_ServerTools", "Server tools"))
    panel:makeJobButton(12, y, 100, 24, IKST.text("IGUI_IKST_Save", "Save world"), function()
        IKST.dispatchCommand(p, IKST.CMD.quickSave, {})
    end, true)
    panel:makeJobButton(118, y, 100, 24, IKST.text("IGUI_IKST_Broadcast", "Broadcast"), function()
        local msg = "Admin message"
        if state and state.lastBroadcast and state.lastBroadcast ~= "" then
            msg = state.lastBroadcast
        end
        IKST.dispatchCommand(p, IKST.CMD.quickBroadcast, { message = msg })
    end, false)
    panel:makeJobButton(224, y, 100, 24, IKST.text("IGUI_IKST_Util_AuditTail", "Audit log"), function()
        IKST.dispatchCommand(p, IKST.CMD.auditTail, { count = 25 })
    end, false)
    y = y + 32

    y = panel:makeJobHeader(12, y, IKST.text("IGUI_IKST_Util_Utilities", "Utilities"))
    panel:makeJobButton(12, y, 120, 24, IKST.text("IGUI_IKST_Water", "Water"), function()
        IKST_QuickActions.run(p, "quickWater")
        panel:refreshJobUI()
    end, IKST.isWaterOn())
    panel:makeJobButton(138, y, 120, 24, IKST.text("IGUI_IKST_Power", "Power"), function()
        IKST_QuickActions.run(p, "quickPower")
        panel:refreshJobUI()
    end, IKST.isPowerOn())
    y = y + 28
    panel:makeJobLabel(12, y, IKST.utilityStatusLine(), UIFont.Small)
    y = y + 24

    y = panel:makeJobHeader(12, y, IKST.text("IGUI_IKST_Util_TimeWeather", "Time & weather"))
    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_TimeHour", "Hour (0-23)"), UIFont.Small)
    y = y + 16
    panel.staffHour = ISTextEntryBox:new("12", 12, y, 60, 22)
    panel.staffHour:initialise()
    panel.staffHour:instantiate()
    panel:addJobWidget(panel.staffHour)
    panel:makeJobButton(80, y, 80, 22, IKST.text("IGUI_IKST_SetTime", "Set time"), function()
        IKST_ClientStaff.runSetTime(p, IKST_JobStaff.readNumber(panel.staffHour, 12))
    end, true)
    y = y + 30
    local wx = 12
    for _, preset in ipairs({ "Clear", "Rain", "Storm", "Fog" }) do
        panel:makeJobButton(wx, y, 70, 24, preset, function()
            IKST_ClientStaff.runWeather(p, preset)
        end, false)
        wx = wx + 76
    end
    y = y + 28
    panel:makeJobButton(12, y, 120, 24, IKST.text("IGUI_IKST_ClearWeather", "Clear weather"), function()
        IKST_ClientStaff.runClearWeather(p)
    end, false)
    y = y + 34

    return y
end

-- Utilities "Self" landing page (mockup: ikst-hyperos-panel-pill-toggles.png):
-- rounded section cards of toggle pills, wired to real dispatch commands and
-- vanilla getters. Kick / ban / spectator live in the Admin addon workspace.
IKST_JobUtilities.SELF_TOGGLES = {
    {
        labelKey = "IGUI_IKST_UtilTile_GodMode", label = "God mode",
        isOn = function(p) return type(p.isGodMod) == "function" and p:isGodMod() == true end,
        fire = function(p) IKST.dispatchCommand(p, IKST.CMD.godSelf, {}) end,
    },
    {
        labelKey = "IGUI_IKST_UtilTile_NoClip", label = "No clip",
        isOn = function(p) return type(p.isNoClip) == "function" and p:isNoClip() == true end,
        fire = function(p) IKST.dispatchCommand(p, IKST.CMD.noclipSelf, {}) end,
    },
    {
        labelKey = "IGUI_IKST_UtilTile_Invisible", label = "Invisible",
        isOn = function(p) return type(p.isInvisible) == "function" and p:isInvisible() == true end,
        fire = function(p) IKST.dispatchCommand(p, IKST.CMD.invisSelf, {}) end,
    },
}

-- Vanilla debug cheats (unlimitedEndurance/fastMove) work standalone even
-- when the engine-only God/NoClip/Invisible flags are unavailable (SP w/o
-- -debug), so they stay in Self & Movement regardless of engineStaffModesAvailable.
IKST_JobUtilities.SELF_CHEAT_TOGGLES = {
    { labelKey = "IGUI_IKST_UtilTile_UnlStamina", label = "Unlimited stamina", cheat = "unlimitedEndurance" },
    { labelKey = "IGUI_IKST_UtilTile_SuperSpeed", label = "Super speed", cheat = "fastMove" },
}

IKST_JobUtilities.ITEM_CHEAT_TOGGLES = {
    { labelKey = "IGUI_IKST_UtilTile_UnlAmmo", label = "Unlimited ammo", cheat = "unlimitedAmmo" },
    { labelKey = "IGUI_IKST_UtilTile_NoMaterials", label = "No materials", cheat = "build" },
    { labelKey = "IGUI_IKST_UtilTile_InstantCraft", label = "Instant craft", cheat = "instantActions" },
    { labelKey = "IGUI_IKST_UtilTile_UnlCarry", label = "Unlimited carry", cheat = "unlimitedCarry" },
}

function IKST_JobUtilities.disarmAllSelfTools(panel)
    local p = panel.player
    if not p then
        return
    end
    if IKST.engineStaffModesAvailable and IKST.engineStaffModesAvailable() then
        for _, toggle in ipairs(IKST_JobUtilities.SELF_TOGGLES) do
            if toggle.isOn(p) then
                toggle.fire(p)
            end
        end
    end
    for _, toggle in ipairs(IKST_JobUtilities.SELF_CHEAT_TOGGLES) do
        if IKST_StaffCheats.isActive(p, toggle.cheat) then
            IKST.dispatchCommand(p, IKST.CMD.toggleSelfCheat, { cheat = toggle.cheat })
        end
    end
    for _, toggle in ipairs(IKST_JobUtilities.ITEM_CHEAT_TOGGLES) do
        if IKST_StaffCheats.isActive(p, toggle.cheat) then
            IKST.dispatchCommand(p, IKST.CMD.toggleSelfCheat, { cheat = toggle.cheat })
        end
    end
    panel:refreshJobUI()
end

function IKST_JobUtilities.cycleTarget(panel, dir)
    local list = IKST_JobStaff.onlinePlayers or {}
    if #list == 0 then
        return
    end
    local idx = panel.staffTargetIndex or 1
    idx = idx + dir
    if idx < 1 then
        idx = #list
    elseif idx > #list then
        idx = 1
    end
    panel.staffTargetIndex = idx
    panel:refreshJobUI()
end

-- Pure width math: wraps {label=...} items into rows that fit cardW, without
-- creating any widgets, so callers can size the section's real ISPanel
-- before content exists to measure against.
local function flowLayout(items, cardW, gap)
    local padX = IKST_UI_Layout.s(14)
    local usableW = math.max(40, cardW - (padX * 2))
    local rows = {}
    local curRow = {}
    local curX = 0
    for _, item in ipairs(items) do
        local w = IKST_UI_Layout.buttonWidth(item.label, UIFont.Small, 96)
        if curX > 0 and curX + gap + w > usableW then
            rows[#rows + 1] = curRow
            curRow = {}
            curX = 0
        end
        if curX > 0 then
            curX = curX + gap
        end
        curRow[#curRow + 1] = { item = item, x = padX + curX, w = w }
        curX = curX + w
    end
    if #curRow > 0 then
        rows[#rows + 1] = curRow
    end
    return rows
end

-- Creates the actual toggle-pill / placeholder-chip ISButtons for a
-- pre-computed flowLayout() row set, as children of the section card panel.
local function renderToggleRows(cardPanel, panel, rows, startY, rowH, gap)
    local y = startY
    for _, row in ipairs(rows) do
        for _, cell in ipairs(row) do
            local item = cell.item
            local kind = "chip"
            if not item.placeholder and item.on == true then
                kind = "primary"
            end
            local btn = IKST_Chrome.newActionButton(cell.x, y, cell.w, rowH, item.label, panel, function()
                item.onClick()
                panel:refreshJobUI()
            end, kind)
            cardPanel:addChild(btn)
        end
        y = y + rowH + gap
    end
    return y
end

local function buildToggleSection(panel, x, y, w, icon, titleKey, titleFallback, items)
    local rowH = math.max(26, IKST_UI_Layout.s(30))
    local gap = IKST_UI_Layout.s(8)
    local rows = flowLayout(items, w, gap)
    local headerH = IKST_Chrome.sectionHeaderH()
    local bottomPad = IKST_UI_Layout.s(14)
    local contentH = (#rows * rowH) + (math.max(0, #rows - 1) * gap)
    local cardH = headerH + contentH + bottomPad
    local title = IKST.text(titleKey, titleFallback)
    local card, contentY = IKST_Chrome.newSectionCardPanel(x, y, w, cardH, icon, title)
    panel:addJobWidget(card)
    renderToggleRows(card, panel, rows, contentY, rowH, gap)
    return y + cardH + (IKST_JobLayout.GAP or gap)
end

local function selfMovementItems(p)
    local items = {}
    if IKST.engineStaffModesAvailable and IKST.engineStaffModesAvailable() then
        for _, t in ipairs(IKST_JobUtilities.SELF_TOGGLES) do
            items[#items + 1] = {
                label = IKST.text(t.labelKey, t.label),
                on = t.isOn(p),
                onClick = function() t.fire(p) end,
            }
        end
    end
    for _, t in ipairs(IKST_JobUtilities.SELF_CHEAT_TOGGLES) do
        items[#items + 1] = {
            label = IKST.text(t.labelKey, t.label),
            on = IKST_StaffCheats.isActive(p, t.cheat),
            onClick = function()
                IKST.dispatchCommand(p, IKST.CMD.toggleSelfCheat, { cheat = t.cheat })
            end,
        }
    end
    return items
end

local function itemsInventoryItems(p)
    local items = {}
    for _, t in ipairs(IKST_JobUtilities.ITEM_CHEAT_TOGGLES) do
        items[#items + 1] = {
            label = IKST.text(t.labelKey, t.label),
            on = IKST_StaffCheats.isActive(p, t.cheat),
            onClick = function()
                IKST.dispatchCommand(p, IKST.CMD.toggleSelfCheat, { cheat = t.cheat })
            end,
        }
    end
    items[#items + 1] = {
        label = IKST.text("IGUI_IKST_UtilTile_Duplicate", "Duplicate"),
        onClick = function()
            IKST.dispatchCommand(p, IKST.CMD.duplicateItem, {})
        end,
    }
    return items
end

-- Players & moderation: same selected target as the Players tool
-- (panel.staffTargetId / IKST_JobStaff.onlinePlayers), with a scrolling list.
local function buildPlayersModerationSection(panel, x, y, w, icon, titleKey, titleFallback)
    local p = panel.player
    if IKST.isMultiplayerSession() and #(IKST_JobStaff.onlinePlayers or {}) == 0
        and not panel._utilSelfPlayersRequested then
        panel._utilSelfPlayersRequested = true
        IKST_JobStaff.requestPlayers(p)
    end

    local rowH = math.max(26, IKST_UI_Layout.s(30))
    local gap = IKST_UI_Layout.s(8)
    local noTargetMsg = IKST.text("IGUI_IKST_UtilTile_NoTarget", "No target selected")
    local listH = IKST_JobLayout.selectListHeight(6)
    local filterBlockH = 16 + 6 + 22 + 6 + listH

    local items = {
        {
            label = IKST.text("IGUI_IKST_UtilTile_TpToMe", "Teleport to me"),
            onClick = function()
                local target = IKST_JobStaff.getSelectedTarget(panel)
                if target then
                    IKST.dispatchCommand(p, IKST.CMD.bringTarget, { target = target.id })
                else
                    IKST.notify(p, noTargetMsg, false)
                end
            end,
        },
        {
            label = IKST.text("IGUI_IKST_UtilTile_HealPlayer", "Heal player"),
            onClick = function()
                local target = IKST_JobStaff.getSelectedTarget(panel)
                if target then
                    IKST.dispatchCommand(p, IKST.CMD.healTarget, { target = target.id })
                else
                    IKST.notify(p, noTargetMsg, false)
                end
            end,
        },
    }
    local rows = flowLayout(items, w, gap)
    local headerH = IKST_Chrome.sectionHeaderH()
    local bottomPad = IKST_UI_Layout.s(14)
    local contentH = filterBlockH + gap + (#rows * rowH) + (math.max(0, #rows - 1) * gap)
    local cardH = headerH + contentH + bottomPad
    local title = IKST.text(titleKey, titleFallback)
    local card, contentY = IKST_Chrome.newSectionCardPanel(x, y, w, cardH, icon, title)
    panel:addJobWidget(card)

    local padX = IKST_UI_Layout.s(14)
    local innerW = math.max(80, w - (padX * 2))
    local cc = IKST_Chrome.colors
    local filterLbl = ISLabel:new(padX, contentY, 16, IKST.text("IGUI_IKST_ListFilter", "Filter"),
        cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small, true)
    filterLbl:initialise()
    card:addChild(filterLbl)
    local listBottom = IKST_JobStaff.buildPlayerSelectList(panel, card, padX, contentY + 18, innerW, 6)
    renderToggleRows(card, panel, rows, listBottom + gap, rowH, gap)
    return y + cardH + (IKST_JobLayout.GAP or gap)
end

function IKST_JobUtilities.buildSelfOverview(panel)
    local p = panel.player
    if not p then
        return 8
    end
    local x = panel.contentX or IKST_JobLayout.MARGIN
    local w = math.max(220, panel.contentW or (panel.width - 24))
    local y = 8

    local title = IKST.text("IGUI_IKST_WS_Utilities", "Utilities")
    local titleLabel = ISLabel:new(x, y, 26, title, 1, 1, 1, 1, UIFont.Large, true)
    titleLabel:initialise()
    panel:addJobWidget(titleLabel)

    local disarmLabel = IKST.text("IGUI_IKST_UtilTile_DisarmAll", "Disarm all tools")
    local disarmW = IKST_UI_Layout.buttonWidth(disarmLabel, UIFont.Small, 100)
    local headerBtnH = math.max(24, IKST_UI_Layout.s(28))
    local rightEdge = x + w
    local disarmX = rightEdge - disarmW

    local disarmBtn = IKST_Chrome.newActionButton(disarmX, y, disarmW, headerBtnH, disarmLabel, panel, function()
        IKST_JobUtilities.disarmAllSelfTools(panel)
    end, "outline")
    panel:addJobWidget(disarmBtn)

    y = y + math.max(26, headerBtnH) + (IKST_JobLayout.GAP or IKST_UI_Layout.s(12))

    y = buildToggleSection(panel, x, y, w, "media/ui/ikst/tool_self.png",
        "IGUI_IKST_UtilTile_SectionSelf", "Self & movement", selfMovementItems(p))
    y = buildToggleSection(panel, x, y, w, "media/ui/ikst/tool_items.png",
        "IGUI_IKST_UtilTile_SectionItems", "Items & inventory", itemsInventoryItems(p))
    y = buildPlayersModerationSection(panel, x, y, w, "media/ui/ikst/tool_players.png",
        "IGUI_IKST_UtilTile_SectionPlayers", "Players & moderation")

    return y
end

function IKST_JobUtilities.build(panel)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return 8
    end
    local tool = state.navTool or "self"

    if tool == "zombies" and IKST_JobThreat then
        return IKST_JobThreat.build(panel)
    end
    if tool == "servertools" then
        return IKST_JobUtilities.buildServerTools(panel)
    end

    if tool == "self" then
        return IKST_JobUtilities.buildSelfOverview(panel)
    elseif tool == "items" then
        state.staffMode = "items"
    elseif tool == "players" then
        state.staffMode = "players"
    elseif tool == "teleport" then
        state.staffMode = "waypoints"
    end

    if IKST_JobStaff and IKST_JobStaff.build then
        return IKST_JobStaff.build(panel) or 8
    end
    return 8
end
