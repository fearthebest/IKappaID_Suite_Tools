-- SoftTool Utilities: soft-shell Utilities workspace painted via IKUI_SoftBody.
-- Dispatch/request helpers stay on JobUtilities / JobStaff / JobThreat.
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISLabel"
require "IKST_Shared"
require "IKappaID_UI_Framework/IKUI_SoftBody"
require "IKST_JobLayout"
require "IKST_JobUtilities"
require "IKST_JobStaff"
require "IKST_JobThreat"
require "IKST_QuickActions"
require "IKST_ClientStaff"
require "IKST_StaffCheats"
require "IKST_Threat"
require "IKST_Catalog"

IKST_SoftTool_Utilities = IKST_SoftTool_Utilities or {}

local function openBand(panel, rect, band, title)
    local inner = IKUI_SoftBody.SECTION_INNER
    local padY = 8
    local btnH = IKUI_SoftBody.STANDARD_BTN_H
    local card, contentY = IKUI_SoftBody.section(panel, rect.x, band.y, rect.w, band.h, title)
    local areaX = inner
    local areaW = math.max(40, rect.w - inner * 2)
    local areaY = contentY + padY
    local areaH = math.max(btnH, band.h - contentY - padY * 2)
    return card, areaX, areaY, areaW, areaH
end

local function openCol(panel, col, title)
    local inner = IKUI_SoftBody.SECTION_INNER
    local padY = 8
    local btnH = IKUI_SoftBody.STANDARD_BTN_H
    local card, contentY = IKUI_SoftBody.section(panel, col.x, col.y, col.w, col.h, title)
    return card, inner, contentY + padY, math.max(40, col.w - inner * 2), math.max(btnH, col.h - contentY - padY * 2)
end

local function wrapRefresh(panel, fn)
    return function()
        fn()
        panel:refreshJobUI()
    end
end

local function selfMovementItems(p)
    local items = {}
    if IKST.engineStaffModesAvailable and IKST.engineStaffModesAvailable() then
        for _, t in ipairs(IKST_JobUtilities.SELF_TOGGLES or {}) do
            items[#items + 1] = {
                label = IKST.text(t.labelKey, t.label),
                primary = t.isOn(p) == true,
                onClick = function()
                    t.fire(p)
                end,
            }
        end
    end
    for _, t in ipairs(IKST_JobUtilities.SELF_CHEAT_TOGGLES or {}) do
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
    for _, t in ipairs(IKST_JobUtilities.ITEM_CHEAT_TOGGLES or {}) do
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

function IKST_SoftTool_Utilities.buildServerTools(panel)
    local p = panel.player
    local state = IKST.getPlayerState(p)
    local rect = IKUI_SoftBody.contentRect(panel)
    local gap = IKUI_SoftBody.BTN_GAP
    local bands, stackBottom = IKUI_SoftBody.stack(rect.y, gap, {
        2, 2, IKUI_SoftBody.fieldActionBandH(1), 2,
    })

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[1], IKST.text("IGUI_IKST_Util_ServerTools", "Server tools"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
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
            {
                label = IKST.text("IGUI_IKST_Guard_Lightbulbs", "Repair lights"),
                onClick = function()
                    if not IKST_JobGuard then
                        require "IKST_JobGuard"
                    end
                    if IKST_JobGuard and type(IKST_JobGuard.dispatchRadius) == "function" then
                        IKST_JobGuard.dispatchRadius(panel, IKST.CMD.lightbulbsArea, nil)
                    end
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[2], IKST.text("IGUI_IKST_Util_Utilities", "Utilities"))
        local noteH = 16
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah - noteH, {
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
        card:addChild(note)
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[3], IKST.text("IGUI_IKST_TimeHour", "Time"))
        IKUI_SoftBody.fieldAction(panel, card, ax, ay, aw, ah, {
            { text = "12", fieldName = "staffHour" },
        }, IKST.text("IGUI_IKST_SetTime", "Set time"), function()
            IKST_ClientStaff.runSetTime(p, IKST_JobStaff.readNumber(panel.staffHour, 12))
        end)
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[4], IKST.text("IGUI_IKST_SectionWeather", "Weather"))
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
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, weatherItems)
    end

    return stackBottom + gap
end

function IKST_SoftTool_Utilities.buildSelf(panel)
    local p = panel.player
    if not p then
        return 8
    end
    local rect = IKUI_SoftBody.contentRect(panel)
    local gap = IKUI_SoftBody.BTN_GAP
    local btnH = IKUI_SoftBody.STANDARD_BTN_H
    local headerH = 36

    local title = ISLabel:new(rect.x, rect.y, headerH, IKST.text("IGUI_IKST_WS_Utilities", "Utilities"), 1, 1, 1, 1, UIFont.Large, true)
    title:initialise()
    if panel.addJobWidget then
        panel:addJobWidget(title)
    else
        panel:addChild(title)
    end

    local disarmLabel = IKST.text("IGUI_IKST_UtilTile_DisarmAll", "Disarm all tools")
    local btnW = select(1, IKUI_SoftBody.standardPillSize(rect.w))
    IKUI_SoftBody.placePill(panel, panel, {
        x = rect.x + rect.w - btnW,
        y = rect.y + math.floor((headerH - btnH) / 2),
        w = btnW,
        h = btnH,
    }, disarmLabel, function()
        IKST_JobUtilities.disarmAllSelfTools(panel)
    end, false)

    local bandsY = rect.y + headerH + gap
    local bandsH = rect.y + rect.h - bandsY
    local pillBandH = IKUI_SoftBody.compactPillBandH(2)
    local listBandH = math.max(80, bandsH - pillBandH - gap - pillBandH - gap)
    local bands = {
        { y = bandsY, h = pillBandH },
        { y = bandsY + pillBandH + gap, h = pillBandH },
        { y = bandsY + pillBandH + gap + pillBandH + gap, h = listBandH },
    }
    local stackBottom = bands[3].y + bands[3].h

    local function fillPillBand(band, titleKey, titleFallback, items)
        local card, ax, ay, aw, ah = openBand(panel, rect, band, IKST.text(titleKey, titleFallback))
        local wired = {}
        for i = 1, #items do
            local it = items[i]
            wired[i] = {
                label = it.label,
                primary = it.primary,
                onClick = wrapRefresh(panel, it.onClick),
            }
        end
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, wired)
    end

    fillPillBand(bands[1], "IGUI_IKST_UtilTile_SectionSelf", "Self & movement", selfMovementItems(p))
    fillPillBand(bands[2], "IGUI_IKST_UtilTile_SectionItems", "Items & inventory", itemsInventoryItems(p))

    do
        local band = bands[3]
        if IKST.isMultiplayerSession() and #(IKST_JobStaff.onlinePlayers or {}) == 0
            and not panel._utilSelfPlayersRequested then
            panel._utilSelfPlayersRequested = true
            IKST_JobStaff.requestPlayers(p)
        end
        local card, ax, ay, aw, ah = openBand(panel, rect, band,
            IKST.text("IGUI_IKST_UtilTile_SectionPlayers", "Players & moderation"))
        local listH, pillH, gapLP = IKUI_SoftBody.listPillSplit(ah, 1, true)
        local noTargetMsg = IKST.text("IGUI_IKST_UtilTile_NoTarget", "No target selected")
        local listBottom = IKST_JobStaff.buildPlayerSelectList(panel, card, ax, ay, aw, nil, listH)
        local actionY = listBottom + gapLP
        local actionH = math.max(btnH, pillH)
        if actionY + actionH > ay + ah then
            actionY = math.max(ay, ay + ah - actionH)
        end
        IKUI_SoftBody.pillRow(panel, card, ax, actionY, aw, actionH, {
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

    return stackBottom + gap
end

function IKST_SoftTool_Utilities.buildZombies(panel)
    if not panel.threatRadius then
        panel.threatRadius = IKST.RADIUS_PRESETS.M
    end
    local p = panel.player
    local rect = IKUI_SoftBody.contentRect(panel)
    local gap = IKUI_SoftBody.BTN_GAP
    local bands, stackBottom = IKUI_SoftBody.stack(rect.y, gap, { 1, 2 })

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[1], IKST.text("IGUI_IKST_SectionScope", "Scope"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_Scope_Radius", "Radius") .. " " .. tostring(panel.threatRadius),
                onClick = function()
                    local presets = { IKST.RADIUS_PRESETS.S, IKST.RADIUS_PRESETS.M, IKST.RADIUS_PRESETS.L }
                    local idx = 1
                    for i, val in ipairs(presets) do
                        if val == panel.threatRadius then
                            idx = i
                            break
                        end
                    end
                    panel.threatRadius = presets[(idx % #presets) + 1]
                    panel:refreshJobUI()
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Scan", "Scan"),
                onClick = function()
                    if not p then
                        return
                    end
                    IKST_Threat.applyClientPreview(p:getX(), p:getY(), p:getZ(), panel.threatRadius, "warn")
                    IKST.dispatchCommand(p, IKST.CMD.threatPopulation, {
                        x = math.floor(p:getX()),
                        y = math.floor(p:getY()),
                        z = p:getZ(),
                        radius = panel.threatRadius,
                    })
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Cull", "Cull"),
                primary = true,
                onClick = function()
                    if not p then
                        return
                    end
                    IKST_Threat.applyClientPreview(p:getX(), p:getY(), p:getZ(), panel.threatRadius, "warn")
                    IKST.dispatchCommand(p, IKST.CMD.threatCull, {
                        x = math.floor(p:getX()),
                        y = math.floor(p:getY()),
                        z = p:getZ(),
                        radius = panel.threatRadius,
                    })
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[2], IKST.text("IGUI_IKST_SectionPopulation", "Population"))
        local stats = IKST_JobThreat.stats or { total = 0, sprinters = 0 }
        local statsText = "Zombies: " .. tostring(stats.total) .. "  Sprinters: " .. tostring(stats.sprinters)
        local affects = ""
        if IKST_Threat and type(IKST_Threat.affectsLabel) == "function" then
            affects = IKST_Threat.affectsLabel(panel.threatRadius)
        end
        local lineH = 16
        local note = ISLabel:new(ax, ay, lineH, statsText, 1, 1, 1, 1, UIFont.Small, true)
        note:initialise()
        card:addChild(note)
        if affects ~= "" then
            local note2 = ISLabel:new(ax, ay + lineH + 4, lineH, affects, 1, 1, 1, 1, UIFont.Small, true)
            note2:initialise()
            card:addChild(note2)
        end
    end

    if p then
        IKST_Threat.applyClientPreview(p:getX(), p:getY(), p:getZ(), panel.threatRadius, "warn")
    end
    return stackBottom + gap
end

function IKST_SoftTool_Utilities.buildItems(panel)
    local p = panel.player
    if not p then
        return 8
    end
    local state = IKST.getPlayerState(p)
    if not state then
        return 8
    end
    if not state.staffItemCategory then
        state.staffItemCategory = IKST_Catalog.CATEGORY_ALL
    end

    local rect = IKUI_SoftBody.contentRect(panel)
    local gap = IKUI_SoftBody.BTN_GAP
    local btnH = IKUI_SoftBody.STANDARD_BTN_H
    local headerH = IKUI_SoftBody.sectionHeaderH()
    local bandMin = headerH + (IKUI_SoftBody.SECTION_INNER * 2) + IKUI_SoftBody.FIELD_H + 8 + btnH + 4
    local pageBands = IKUI_SoftBody.pageBands(rect.y, rect.h, 160, { bandMin, bandMin }, gap)
    local listOuterH = pageBands[1].h
    local selectedH = pageBands[2].h
    local searchH = pageBands[3].h

    local function openAbs(x, y, w, h, title)
        local card, contentY = IKUI_SoftBody.section(panel, x, y, w, h, title)
        local inner = IKUI_SoftBody.SECTION_INNER
        local padY = 8
        return card, inner, contentY + padY, math.max(40, w - inner * 2), math.max(btnH, h - contentY - padY * 2)
    end

    do
        local card, ax, ay, aw, ah = openAbs(rect.x, rect.y, rect.w, listOuterH, IKST.text("IGUI_IKST_Catalog_All", "Items"))
        local q = panel.staffItemFilterText or ""
        local itemRows, itemTotal = IKST_JobStaff.itemCatalogRows(panel, q)
        panel.staffItemList = IKST_JobLayout.makeSelectList(panel, card, ax, ay, aw, ah, itemRows, {
            selectedId = panel.staffItemTypeText,
            itemHeight = 32,
            doDrawItem = IKST_JobStaff.drawItemListItem,
            onSelect = function(row)
                IKST_JobStaff.onItemListSelect(panel, row)
            end,
        })
        panel.staffItemListTotal = itemTotal
        panel.staffItemListShown = #itemRows
    end

    do
        local y = rect.y + listOuterH + gap
        local card, ax, ay, aw, ah = openAbs(rect.x, y, rect.w, selectedH, IKST.text("IGUI_IKST_Give", "Selected"))
        local selectedFull = "Base.Axe"
        if panel.staffItemList and panel.staffItemList.selected
            and panel.staffItemList.items and panel.staffItemList.items[panel.staffItemList.selected] then
            local entry = IKST_JobStaff.catalogEntryFromListItem(
                panel.staffItemList.items[panel.staffItemList.selected])
            if entry and entry.full then
                selectedFull = entry.full
            end
        elseif panel.staffItemTypeText and panel.staffItemTypeText ~= "" then
            selectedFull = panel.staffItemTypeText
        end
        IKUI_SoftBody.fieldAction(panel, card, ax, ay, aw, ah, {
            { text = selectedFull, fieldName = "staffItemType" },
            { text = tostring(panel.staffItemQtyText or "1"), fieldName = "staffItemQty" },
        }, IKST.text("IGUI_IKST_Give", "Give"), function()
            local itemType = IKST_JobStaff.getSelectedItemType(panel)
            if not IKST_Catalog.itemExists(itemType) then
                IKST.notify(p, IKST.text("IGUI_IKST_InvalidItem", "Unknown item type"), false)
                return
            end
            panel.staffItemTypeText = itemType
            panel.staffItemQtyText = IKST_JobStaff.readEntry(panel.staffItemQty)
            IKST.dispatchCommand(p, IKST.CMD.giveItem, {
                type = itemType,
                count = IKST_JobStaff.readNumber(panel.staffItemQty, 1),
            })
        end)
    end

    do
        local y = rect.y + listOuterH + gap + selectedH + gap
        local card, ax, ay, aw, ah = openAbs(rect.x, y, rect.w, searchH, IKST.text("IGUI_IKST_ItemSearch", "Search item"))
        IKUI_SoftBody.fieldAction(panel, card, ax, ay, aw, ah, {
            { text = tostring(panel.staffItemFilterText or ""), fieldName = "staffItemFilter" },
        }, IKST.text("IGUI_IKST_RefreshList", "Refresh"), function()
            IKST_JobStaff.itemCatalog = nil
            local q = IKST_JobStaff.readEntry(panel.staffItemFilter)
            panel.staffItemFilterText = q
            IKST_JobStaff.refreshItemList(panel, q)
        end)
        if panel.staffItemFilter then
            panel.staffItemFilter.onTextChange = function()
                local q = IKST_JobStaff.readEntry(panel.staffItemFilter)
                panel.staffItemFilterText = q
                IKST_JobStaff.refreshItemList(panel, q)
            end
        end
    end

    return rect.y + rect.h
end

function IKST_SoftTool_Utilities.buildPlayers(panel)
    local p = panel.player
    if not p then
        return 8
    end
    if IKST.isMultiplayerSession() and #(IKST_JobStaff.onlinePlayers or {}) == 0
        and not panel._utilPlayersRequested then
        panel._utilPlayersRequested = true
        IKST_JobStaff.requestPlayers(p)
        IKST_JobStaff.requestHelpList(p)
    end

    local rect = IKUI_SoftBody.contentRect(panel)
    local gap = IKUI_SoftBody.BTN_GAP
    local btnH = IKUI_SoftBody.STANDARD_BTN_H
    local left, right = IKUI_SoftBody.masterDetail(rect, 280, 12)

    local function careItems(target)
        if not target then
            return nil
        end
        local tid = target.id
        local items = {
            {
                label = IKST.text("IGUI_IKST_Heal", "Heal"),
                primary = true,
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.healTarget, { target = tid })
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Bring", "Bring"),
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.bringTarget, { target = tid })
                end,
            },
            {
                label = IKST.text("IGUI_IKST_TpTo", "TP to"),
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.tpToTarget, { target = tid })
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Give", "Give"),
                onClick = function()
                    local itemType = IKST_JobStaff.getSelectedItemType(panel)
                    if not IKST_Catalog.itemExists(itemType) then
                        IKST.notify(p, IKST.text("IGUI_IKST_InvalidItem", "Unknown item - pick one on Items first."), false)
                        return
                    end
                    IKST.dispatchCommand(p, IKST.CMD.giveTarget, {
                        target = tid,
                        type = itemType,
                        count = 1,
                    })
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Feed", "Feed"),
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.feedTarget, { target = tid })
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Cure", "Cure"),
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.cureTarget, { target = tid })
                end,
            },
        }
        if IKST.engineStaffModesAvailable and IKST.engineStaffModesAvailable() then
            items[#items + 1] = {
                label = IKST.text("IGUI_IKST_God", "God"),
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.godTarget, { target = tid })
                end,
            }
        end
        return items
    end

    do
        local card, ax, ay, aw, ah = openCol(panel, left, IKST.text("IGUI_IKST_Util_Players", "Online players"))
        local listH, pillH, gapLP = IKUI_SoftBody.listPillSplit(ah, 1, true)
        local listBottom = IKST_JobStaff.buildPlayerSelectList(panel, card, ax, ay, aw, nil, listH)
        local pillAreaY = listBottom + gapLP
        local pillAreaH = math.max(btnH, pillH)
        if pillAreaY + pillAreaH > ay + ah then
            pillAreaY = math.max(ay, ay + ah - pillAreaH)
        end
        IKUI_SoftBody.pillRow(panel, card, ax, pillAreaY, aw, pillAreaH, {
            {
                label = IKST.text("IGUI_IKST_RefreshList", "Refresh"),
                onClick = function()
                    IKST_JobStaff.requestPlayers(panel.player)
                    IKST_JobStaff.requestHelpList(panel.player)
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Guard_DumpPlayers", "List players"),
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.dumpPlayers, {})
                end,
            },
        })
    end

    local hHelp = IKUI_SoftBody.compactPillBandH(2) + 28
    local clearTarget = IKST_JobStaff.getSelectedTarget(panel)
    local hClear = IKUI_SoftBody.fieldActionBandH(1)
    if clearTarget then
        hClear = hClear + gap + IKUI_SoftBody.STANDARD_BTN_H
    end
    local bands = IKUI_SoftBody.pageBands(right.y, right.h, 160, { hHelp, hClear }, gap)

    local function openRightBand(band, title)
        local card, contentY = IKUI_SoftBody.section(panel, right.x, band.y, right.w, band.h, title)
        local inner = IKUI_SoftBody.SECTION_INNER
        local padY = 8
        return card, inner, contentY + padY, math.max(40, right.w - inner * 2), math.max(btnH, band.h - contentY - padY * 2)
    end

    do
        local card, ax, ay, aw, ah = openRightBand(bands[1], IKST.text("IGUI_IKST_Heal", "Care"))
        local target = IKST_JobStaff.getSelectedTarget(panel)
        local items = careItems(target)
        if not items then
            local tip = ISLabel:new(ax, ay, 16,
                IKST.text("IGUI_IKST_UtilTile_NoTarget", "Select a player"),
                0.75, 0.75, 0.75, 1, UIFont.Small, true)
            tip:initialise()
            card:addChild(tip)
        else
            IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, items)
        end
    end

    do
        local card, ax, ay, aw, ah = openRightBand(bands[2], IKST.text("IGUI_IKST_HelpQueue", "Help requests"))
        IKST_JobStaff.placeHelpQueue(panel, card, ax, ay, aw, ah, p)
    end

    do
        local card, ax, ay, aw, ah = openRightBand(bands[3], IKST.text("IGUI_IKST_Clearance_Header", "Clearance"))
        local target = IKST_JobStaff.getSelectedTarget(panel)
        local revokeStrip = target and btnH or 0
        local revokeGap = target and gap or 0
        local fieldH = math.max(btnH, ah - revokeStrip - revokeGap)
        IKUI_SoftBody.fieldAction(panel, card, ax, ay, aw, fieldH, {
            { text = "armory", fieldName = "staffTargetClearanceZone" },
        }, IKST.text("IGUI_IKST_Clearance_Issue", "Issue tag"), function()
            local t = IKST_JobStaff.getSelectedTarget(panel)
            if not t then
                return
            end
            IKST.dispatchCommand(p, IKST.CMD.clearanceIssueTarget, {
                target = t.id,
                zoneId = IKST_JobStaff.readEntry(panel.staffTargetClearanceZone),
            })
        end)
        if target then
            local revokeW = select(1, IKUI_SoftBody.standardPillSize(aw))
            local revokeY = ay + fieldH + revokeGap
            IKUI_SoftBody.placePill(panel, card, {
                x = ax,
                y = revokeY,
                w = revokeW,
                h = btnH,
            }, IKST.text("IGUI_IKST_Clearance_Revoke", "Revoke"), function()
                local t = IKST_JobStaff.getSelectedTarget(panel)
                if not t then
                    return
                end
                IKST.dispatchCommand(p, IKST.CMD.clearanceRevokeTarget, { target = t.id })
            end, false)
        end
    end

    return rect.y + rect.h
end

function IKST_SoftTool_Utilities.buildTeleport(panel)
    local p = panel.player
    if not p then
        return 8
    end
    if not panel._utilWpRequested then
        panel._utilWpRequested = true
        IKST_JobStaff.requestWaypoints(p)
    end
    local rect = IKUI_SoftBody.contentRect(panel)
    local gap = IKUI_SoftBody.BTN_GAP
    local btnH = IKUI_SoftBody.STANDARD_BTN_H
    local waypointH = IKUI_SoftBody.fieldActionBandH(1)
    local eventH = IKUI_SoftBody.compactPillBandH(1)
    local listBandH = math.max(80, rect.h - waypointH - gap - eventH - gap)
    local bands = {
        { y = rect.y, h = waypointH },
        { y = rect.y + waypointH + gap, h = listBandH },
        { y = rect.y + waypointH + gap + listBandH + gap, h = eventH },
    }
    local stackBottom = bands[3].y + bands[3].h

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[1], IKST.text("IGUI_IKST_WaypointName", "Waypoint"))
        IKUI_SoftBody.fieldAction(panel, card, ax, ay, aw, ah, {
            { text = panel.staffWaypointName or "Base", fieldName = "staffWpName" },
        }, IKST.text("IGUI_IKST_Teleport", "Go"), function()
            IKST.dispatchCommand(p, IKST.CMD.tpWaypoint, { name = IKST_JobStaff.readEntry(panel.staffWpName) })
        end)
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[2], IKST.text("IGUI_IKST_WaypointSave", "Library"))
        local listH, pillH, gapLP = IKUI_SoftBody.listPillSplit(ah, 1)
        panel.staffWpList = IKST_JobLayout.makeSelectList(panel, card, ax, ay, aw, listH, IKST_JobStaff.waypointRows(), {
            selectedId = panel.staffWaypointName,
            onSelect = function(row)
                if row and row.data and row.data.name then
                    panel.staffWaypointName = row.data.name
                    if panel.staffWpName and type(panel.staffWpName.setText) == "function" then
                        panel.staffWpName:setText(row.data.name)
                    end
                end
            end,
        })
        local pillY = ay + listH + gapLP
        local pillAreaH = math.max(btnH, pillH)
        IKUI_SoftBody.pillRow(panel, card, ax, pillY, aw, pillAreaH, {
            {
                label = IKST.text("IGUI_IKST_WaypointSave", "Save"),
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.saveWaypoint, { name = IKST_JobStaff.readEntry(panel.staffWpName) })
                end,
            },
            {
                label = IKST.text("IGUI_IKST_WaypointDel", "Delete"),
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.delWaypoint, { name = IKST_JobStaff.readEntry(panel.staffWpName) })
                end,
            },
            {
                label = IKST.text("IGUI_IKST_RefreshList", "Refresh"),
                onClick = function()
                    IKST_JobStaff.requestWaypoints(panel.player)
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[3], IKST.text("IGUI_IKST_EventStaff", "Event"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_EventSet", "Set event"),
                primary = true,
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.eventSet, { name = IKST_JobStaff.readEntry(panel.staffWpName) })
                end,
            },
            {
                label = IKST.text("IGUI_IKST_EventClear", "Clear event"),
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.eventClear, {})
                end,
            },
        })
    end

    return stackBottom + gap
end

function IKST_SoftTool_Utilities.buildBatch(panel)
    local p = panel.player
    if not p then
        return 8
    end
    local rect = IKUI_SoftBody.contentRect(panel)
    local gap = IKUI_SoftBody.BTN_GAP
    local bands, stackBottom = IKUI_SoftBody.stack(rect.y, gap, { 1, 1 })

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[1], IKST.text("IGUI_IKST_BatchNote", "Batch care"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_HealAll", "Heal all"),
                primary = true,
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.healAll, {})
                end,
            },
            {
                label = IKST.text("IGUI_IKST_FeedAll", "Feed all"),
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.feedAll, {})
                end,
            },
            {
                label = IKST.text("IGUI_IKST_CureAll", "Cure all"),
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.cureAll, {})
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[2], IKST.text("IGUI_IKST_TpAllToMe", "Teleport"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_TpAllToMe", "TP all to me"),
                primary = true,
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.tpAllToMe, {})
                end,
            },
        })
    end

    return stackBottom + gap
end

function IKST_SoftTool_Utilities.build(panel)
    if not panel or not panel.player then
        return 8
    end
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return 8
    end
    local tool = state.navTool or "self"
    local bottomY
    if tool == "zombies" then
        bottomY = IKST_SoftTool_Utilities.buildZombies(panel)
    elseif tool == "servertools" then
        bottomY = IKST_SoftTool_Utilities.buildServerTools(panel)
    elseif tool == "self" then
        bottomY = IKST_SoftTool_Utilities.buildSelf(panel)
    elseif tool == "items" then
        bottomY = IKST_SoftTool_Utilities.buildItems(panel)
    elseif tool == "players" then
        bottomY = IKST_SoftTool_Utilities.buildPlayers(panel)
    elseif tool == "teleport" then
        bottomY = IKST_SoftTool_Utilities.buildTeleport(panel)
    elseif tool == "batch" then
        bottomY = IKST_SoftTool_Utilities.buildBatch(panel)
    else
        bottomY = IKST_SoftTool_Utilities.buildSelf(panel)
    end
    return bottomY
end
