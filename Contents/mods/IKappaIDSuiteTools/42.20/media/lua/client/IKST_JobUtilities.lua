if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISTextEntryBox"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "IKST_Shared"
require "IKappaID_UI/IKUI_Chrome"
require "IKST_ActionLog"
require "IKST_JobLayout"
require "IKST_JobStaff"
require "IKST_JobThreat"
require "IKST_QuickActions"
require "IKST_ClientStaff"
require "IKST_StaffCheats"

IKST_JobUtilities = IKST_JobUtilities or {}

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

local function selfMovementItems(p)
    local items = {}
    if IKST.engineStaffModesAvailable and IKST.engineStaffModesAvailable() then
        for _, t in ipairs(IKST_JobUtilities.SELF_TOGGLES) do
            items[#items + 1] = {
                label = IKST.text(t.labelKey, t.label),
                primary = t.isOn(p) == true,
                onClick = function()
                    t.fire(p)
                    -- refresh via JobsPanel after command result; local toggle state needs rebuild
                end,
            }
        end
    end
    for _, t in ipairs(IKST_JobUtilities.SELF_CHEAT_TOGGLES) do
        items[#items + 1] = {
            label = IKST.text(t.labelKey, t.label),
            primary = IKST_StaffCheats.isActive(p, t.cheat) == true,
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
            primary = IKST_StaffCheats.isActive(p, t.cheat) == true,
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

local function wrapRefresh(panel, fn)
    return function()
        fn()
        panel:refreshJobUI()
    end
end

function IKST_JobUtilities.buildServerTools(panel)
    local p = panel.player
    local state = IKST.getPlayerState(p)
    local rect = IKST_JobLayout.toolContentRect(panel)
    local gap = 8
    local bands = IKST_JobLayout.splitBands(rect.y, rect.h, 4, gap)
    local inner = IKST_JobLayout.SECTION_INNER

    local function bandContent(band)
        local card, contentY = IKST_JobLayout.placeSectionCard(
            panel, rect.x, band.y, rect.w, band.h, nil, band.title
        )
        local padY = inner
        local areaY = contentY + padY
        local areaH = math.max(36, band.h - contentY - padY * 2)
        local areaX = inner
        local areaW = math.max(40, rect.w - inner * 2)
        return card, areaX, areaY, areaW, areaH
    end

    -- Server tools
    do
        local band = bands[1]
        band.title = IKST.text("IGUI_IKST_Util_ServerTools", "Server tools")
        local card, ax, ay, aw, ah = bandContent(band)
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_Save", "Save game"),
                primary = true,
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.quickSave, {})
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Broadcast", "Broadcast"),
                onClick = function()
                    local msg = "Admin message"
                    if state and state.lastBroadcast and state.lastBroadcast ~= "" then
                        msg = state.lastBroadcast
                    end
                    IKST.dispatchCommand(p, IKST.CMD.quickBroadcast, { message = msg })
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Util_AuditTail", "Audit log"),
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.auditTail, { count = 25 })
                end,
            },
        })
    end

    -- Utilities (water / power)
    do
        local band = bands[2]
        band.title = IKST.text("IGUI_IKST_Util_Utilities", "Utilities")
        local card, ax, ay, aw, ah = bandContent(band)
        local noteH = 16
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah - noteH, {
            {
                label = IKST.text("IGUI_IKST_Water", "Water"),
                primary = IKST.isWaterOn() == true,
                onClick = wrapRefresh(panel, function()
                    IKST_QuickActions.run(p, "quickWater")
                end),
            },
            {
                label = IKST.text("IGUI_IKST_Power", "Power"),
                primary = IKST.isPowerOn() == true,
                onClick = wrapRefresh(panel, function()
                    IKST_QuickActions.run(p, "quickPower")
                end),
            },
        })
        local note = ISLabel:new(ax, ay + ah - noteH, noteH, IKST.utilityStatusLine(), 1, 1, 1, 1, UIFont.Small, true)
        note:initialise()
        if IKUI_Chrome and IKUI_Chrome.styleHeaderLabel then
            -- muted via chrome if available; else default
        end
        card:addChild(note)
    end

    -- Time: hour top-left, Set time bottom-right (matched side margins)
    do
        local band = bands[3]
        band.title = IKST.text("IGUI_IKST_TimeHour", "Time")
        local card, ax, ay, aw, ah = bandContent(band)
        IKST_JobLayout.placeFieldActionCorner(panel, card, ax, ay, aw, ah, {
            { text = "12", fieldName = "staffHour" },
        }, IKST.text("IGUI_IKST_SetTime", "Set time"), function()
            IKST_ClientStaff.runSetTime(p, IKST_JobStaff.readNumber(panel.staffHour, 12))
        end)
    end

    -- Weather
    do
        local band = bands[4]
        band.title = IKST.text("IGUI_IKST_SectionWeather", "Weather")
        local card, ax, ay, aw, ah = bandContent(band)
        local weatherItems = {}
        for _, preset in ipairs({ "Clear", "Rain", "Storm", "Fog" }) do
            weatherItems[#weatherItems + 1] = {
                label = IKST.text("IGUI_IKST_Weather_" .. preset, preset),
                onClick = function()
                    IKST_ClientStaff.runWeather(p, preset)
                end,
            }
        end
        weatherItems[#weatherItems + 1] = {
            label = IKST.text("IGUI_IKST_ClearWeather", "Clear weather"),
            primary = true,
            onClick = function()
                IKST_ClientStaff.runClearWeather(p)
            end,
        }
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, weatherItems)
    end

    panel._ikstToolFit = true
    return rect.y + rect.h
end

function IKST_JobUtilities.buildSelfOverview(panel)
    local p = panel.player
    if not p then
        return 8
    end
    local rect = IKST_JobLayout.toolContentRect(panel)
    local gap = 8
    local headerH = 36
    local btnW, btnH = IKST_JobLayout.standardPillSize(panel)
    local inner = IKST_JobLayout.SECTION_INNER

    -- Title + disarm (standard pill size)
    local title = ISLabel:new(rect.x, rect.y, headerH, IKST.text("IGUI_IKST_WS_Utilities", "Utilities"), 1, 1, 1, 1, UIFont.Large, true)
    title:initialise()
    if IKUI_Chrome and IKUI_Chrome.styleHeaderLabel then
        IKUI_Chrome.styleHeaderLabel(title)
    end
    panel:addJobWidget(title)

    local disarmLabel = IKST.text("IGUI_IKST_UtilTile_DisarmAll", "Disarm all tools")
    local ox, gridW = IKST_JobLayout.packFrame(rect.x, rect.w, btnW)
    IKST_JobLayout.placePill(panel, panel, {
        x = ox + gridW - btnW,
        y = rect.y + math.floor((headerH - btnH) / 2),
        w = btnW,
        h = btnH,
    }, disarmLabel, function()
        IKST_JobUtilities.disarmAllSelfTools(panel)
    end, false)

    local bandsY = rect.y + headerH + gap
    local bandsH = rect.h - headerH - gap
    local bands = IKST_JobLayout.splitCompactFlex(bandsY, bandsH, IKST_JobLayout.compactPillBandH(2), gap)

    local function fillBand(band, titleKey, titleFallback, items, extraFn)
        local card, contentY = IKST_JobLayout.placeSectionCard(
            panel, rect.x, band.y, rect.w, band.h, nil, IKST.text(titleKey, titleFallback)
        )
        local padY = inner
        local areaX = inner
        local areaW = math.max(40, rect.w - inner * 2)
        local areaY = contentY + padY
        local areaH = math.max(36, band.h - contentY - padY * 2)
        if extraFn then
            areaH = extraFn(card, areaX, areaY, areaW, areaH) or areaH
        end
        local wired = {}
        for i = 1, #items do
            local it = items[i]
            wired[i] = {
                label = it.label,
                primary = it.primary,
                onClick = wrapRefresh(panel, it.onClick),
            }
        end
        IKST_JobLayout.placePillGroup(panel, card, areaX, areaY, areaW, areaH, wired)
    end

    fillBand(bands[1],
        "IGUI_IKST_UtilTile_SectionSelf", "Self & movement", selfMovementItems(p))
    fillBand(bands[2],
        "IGUI_IKST_UtilTile_SectionItems", "Items & inventory", itemsInventoryItems(p))

    -- Players band: list on top, action pills on bottom
    do
        local band = bands[3]
        if IKST.isMultiplayerSession() and #(IKST_JobStaff.onlinePlayers or {}) == 0
            and not panel._utilSelfPlayersRequested then
            panel._utilSelfPlayersRequested = true
            IKST_JobStaff.requestPlayers(p)
        end
        local card, contentY = IKST_JobLayout.placeSectionCard(
            panel, rect.x, band.y, rect.w, band.h, nil,
            IKST.text("IGUI_IKST_UtilTile_SectionPlayers", "Players & moderation")
        )
        local areaX = inner
        local areaW = math.max(40, rect.w - inner * 2)
        local areaY = contentY + inner
        local areaH = math.max(36, band.h - contentY - inner * 2)
        local listH, pillH, gapLP = IKST_JobLayout.listPillSplit(areaH, 1, true)
        local noTargetMsg = IKST.text("IGUI_IKST_UtilTile_NoTarget", "No target selected")
        local rows = IKST_JobLayout.rowsForListHeight(listH)
        local listBottom = IKST_JobStaff.buildPlayerSelectList(panel, card, areaX, areaY, areaW, rows)
        local actionY = listBottom + gapLP
        local actionH = math.max(btnH, pillH)
        if actionY + actionH > areaY + areaH then
            actionY = math.max(areaY, areaY + areaH - actionH)
        end
        IKST_JobLayout.placePillGroup(panel, card, areaX, actionY, areaW, actionH, {
            {
                label = IKST.text("IGUI_IKST_UtilTile_TpToMe", "Teleport to me"),
                primary = true,
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
        })
    end

    panel._ikstToolFit = true
    return rect.y + rect.h
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
