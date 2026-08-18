if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISTextEntryBox"
require "ISUI/ISScrollingListBox"
require "IKST_Shared"
require "IKappaID_UI/IKUI_Chrome"
require "IKST_Catalog"
require "IKST_JobCatalog"
require "IKST_JobLayout"
require "IKST_ClientStaff"
require "IKST_StaffCheats"

IKST_JobStaff = IKST_JobStaff or {}
IKST_JobStaff.onlinePlayers = {}
IKST_JobStaff.waypoints = {}
IKST_JobStaff.itemCatalog = nil
IKST_JobStaff.helpPending = {}
IKST_JobStaff.historyEntries = {}

function IKST_JobStaff.requestWaypoints(player)
    IKST.dispatchCommand(player, IKST.CMD.listWaypoints, {})
end

function IKST_JobStaff.readEntry(entry)
    if entry and entry.getText then
        return string.gsub(entry:getText() or "", "^%s*(.-)%s*$", "%1")
    end
    return ""
end

function IKST_JobStaff.readNumber(entry, fallback)
    if IKST and type(IKST.parseNumber) == "function" then
        return IKST.parseNumber(IKST_JobStaff.readEntry(entry), fallback)
    end
    fallback = fallback or 0
    local text = IKST_JobStaff.readEntry(entry)
    if text == nil or text == "" then
        return fallback
    end
    local matched = string.match(tostring(text), "^%s*([%-%+]?%d+%.?%d*)")
    if not matched then
        return fallback
    end
    local n = tonumber(matched)
    if n == nil then
        return fallback
    end
    return n
end

function IKST_JobStaff.addSelfCheatRow(panel, y, cheatIds, player)
    local specs = {}
    for _, cheatId in ipairs(cheatIds) do
        local row = IKST_StaffCheats and IKST_StaffCheats.CHEATS and IKST_StaffCheats.CHEATS[cheatId]
        if row then
            specs[#specs + 1] = {
                label = IKST.text(row.labelKey, row.fallback),
                w = 88,
                primary = false,
                fn = function()
                    IKST.dispatchCommand(player, IKST.CMD.toggleSelfCheat, { cheat = cheatId })
                end,
            }
        end
    end
    if #specs == 0 then
        return y
    end
    return IKST_JobLayout.flowRow(panel, y, specs, 6, 22)
end

function IKST_JobStaff.containerSquareAtPlayer(player)
    if not IKST_Grid or not IKST_Grid.containerNearPlayer then
        return nil
    end
    local _, _, sq = IKST_Grid.containerNearPlayer(player, 1)
    if not sq then
        return nil
    end
    return sq:getX(), sq:getY(), sq:getZ()
end

function IKST_JobStaff.loadItemCatalog()
    if not IKST_JobStaff.itemCatalog then
        IKST_JobStaff.itemCatalog = IKST_Catalog.buildItemCatalog()
    end
    return IKST_JobStaff.itemCatalog
end

function IKST_JobStaff.refreshItemList(panel, filter)
    if not panel.staffItemList then
        return
    end
    panel.staffItemList:clear()
    local state = IKST.getPlayerState(panel.player)
    local categoryId = state and state.staffItemCategory or IKST_Catalog.CATEGORY_ALL
    local rows, total = IKST_Catalog.filterEntries(IKST_JobStaff.loadItemCatalog(), categoryId, filter)
    for _, entry in ipairs(rows) do
        panel.staffItemList:addItem(entry.label or entry.full or "?", entry)
    end
    panel.staffItemListTotal = total
    panel.staffItemListShown = #rows
end

IKST_JobStaff._itemTexCache = IKST_JobStaff._itemTexCache or {}

function IKST_JobStaff.itemTexture(fullType)
    if not fullType or fullType == "" then
        return nil
    end
    local cached = IKST_JobStaff._itemTexCache[fullType]
    if cached ~= nil then
        if cached == false then
            return nil
        end
        return cached
    end
    local tex = nil
    if type(getScriptManager) == "function" then
        local sm = getScriptManager()
        local script = sm and type(sm.FindItem) == "function" and sm:FindItem(fullType) or nil
        if script and type(script.getIcon) == "function" then
            local icon = script:getIcon()
            if icon and icon ~= "" and type(getTexture) == "function" then
                tex = getTexture("media/textures/Item_" .. icon .. ".png")
                if not tex then
                    tex = getTexture("Item_" .. icon)
                end
            end
        end
        if not tex and script and type(script.getNormalTexture) == "function" then
            tex = script:getNormalTexture()
        end
    end
    IKST_JobStaff._itemTexCache[fullType] = tex or false
    return tex
end

function IKST_JobStaff.drawItemListItem(self, y, item, alt)
    local c = IKUI_Chrome and IKUI_Chrome.colors or nil
    local h = self.itemheight or 32
    if self.selected == item.index and c then
        self:drawRect(0, y, self:getWidth(), h, 0.35, c.accentDim.r, c.accentDim.g, c.accentDim.b)
    elseif alt and c then
        self:drawRect(0, y, self:getWidth(), h, 0.10, c.bgCard.r, c.bgCard.g, c.bgCard.b)
    end
    local entry = item.item
    local full = entry and entry.full or nil
    local label = (entry and entry.label) or item.text or ""
    local iconSize = math.min(28, h - 4)
    local tex = full and IKST_JobStaff.itemTexture(full) or nil
    local textX = 6
    if tex and type(self.drawTextureScaled) == "function" then
        local ix = 4
        local iy = y + math.floor((h - iconSize) / 2)
        self:drawTextureScaled(tex, ix, iy, iconSize, iconSize, 1, 1, 1, 1)
        textX = ix + iconSize + 8
    end
    local textY = y + math.floor((h - 14) / 2)
    if c then
        self:drawText(label, textX, textY, c.textPrimary.r, c.textPrimary.g, c.textPrimary.b, 1, self.font)
    else
        self:drawText(label, textX, textY, 1, 1, 1, 1, self.font)
    end
    return y + h
end

function IKST_JobStaff.getSelectedItemType(panel)
    local listBox = panel.staffItemList
    if listBox and listBox.selected and listBox.items[listBox.selected] then
        local entry = listBox.items[listBox.selected].item
        if entry and entry.full then
            return entry.full
        end
    end
    if panel.staffItemType then
        local typed = IKST_JobStaff.readEntry(panel.staffItemType)
        if typed ~= "" then
            return IKST_Catalog.normalizeFullId(typed, "Base")
        end
    end
    return "Base.Axe"
end

function IKST_JobStaff.onItemListSelect(panel)
    local listBox = panel.staffItemList
    if listBox and listBox.selected and listBox.items[listBox.selected] then
        local entry = listBox.items[listBox.selected].item
        if entry and entry.full then
            panel.staffItemTypeText = entry.full
            if panel.staffItemType and type(panel.staffItemType.setText) == "function" then
                panel.staffItemType:setText(entry.full)
            end
        end
    end
end

function IKST_JobStaff.requestPlayers(player)
    if IKST.isMultiplayerSession() then
        IKST.dispatchCommand(player, IKST.CMD.staffListPlayers, {})
    end
end

function IKST_JobStaff.getSelectedTarget(panel)
    local list = IKST_JobStaff.onlinePlayers or {}
    if panel.staffTargetId ~= nil then
        for i = 1, #list do
            local pl = list[i]
            if pl and pl.id == panel.staffTargetId then
                panel.staffTargetIndex = i
                return pl
            end
        end
    end
    local idx = panel.staffTargetIndex or 1
    if idx < 1 or idx > #list then
        return nil
    end
    return list[idx]
end

function IKST_JobStaff.selectPlayerRow(panel, row)
    if not panel or not row then
        return
    end
    local data = row.data or row
    panel.staffTargetId = data.id
    local list = IKST_JobStaff.onlinePlayers or {}
    for i = 1, #list do
        if list[i] and list[i].id == data.id then
            panel.staffTargetIndex = i
            return
        end
    end
end

function IKST_JobStaff.playerListRows()
    local rows = {}
    for _, pl in ipairs(IKST_JobStaff.onlinePlayers or {}) do
        rows[#rows + 1] = {
            id = pl.id,
            label = tostring(pl.name or "?") .. "  #" .. tostring(pl.id),
            data = pl,
        }
    end
    return rows
end

function IKST_JobStaff.refillPlayerSelectList(panel)
    if not panel or not panel.staffPlayerList then
        return
    end
    local rows = IKST_JobLayout.filterRows(IKST_JobStaff.playerListRows(), panel.staffPlayerFilter)
    IKST_JobLayout.refillSelectList(panel.staffPlayerList, rows, panel.staffTargetId)
end

function IKST_JobStaff.buildPlayerSelectList(panel, parent, x, y, w, visibleRows)
    x = x or IKST_JobLayout.MARGIN
    w = w or (panel.contentW or (panel.width - 24))
    local filter, fy = IKST_JobLayout.makeFilterEntry(panel, parent, x, y, w, "staffPlayerFilter", function()
        IKST_JobStaff.refillPlayerSelectList(panel)
    end)
    panel.staffPlayerFilterBox = filter
    local rows = IKST_JobLayout.filterRows(IKST_JobStaff.playerListRows(), panel.staffPlayerFilter)
    local rowCount = tonumber(visibleRows) or 8
    if rowCount < 1 then
        rowCount = 1
    end
    local listH = IKST_JobLayout.selectListHeight(rowCount)
    local list, ly = IKST_JobLayout.makeSelectList(panel, parent, x, fy, w, listH, rows, {
        selectedId = panel.staffTargetId,
        onSelect = function(row)
            IKST_JobStaff.selectPlayerRow(panel, row)
            if panel.refreshJobUI then
                panel:refreshJobUI(true)
            end
        end,
    })
    panel.staffPlayerList = list
    return ly
end

function IKST_JobStaff.buildItemsHand(panel, contentTop)
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

    local rect = IKST_JobLayout.toolContentRect(panel)
    if contentTop and contentTop > rect.y then
        local shrink = contentTop - rect.y
        rect.y = contentTop
        rect.h = math.max(80, rect.h - shrink)
    end
    local gap = 10
    local inner = IKST_JobLayout.SECTION_INNER
    local padY = IKST_JobLayout.CONTENT_PAD_Y
    local btnH = IKST_JobLayout.STANDARD_BTN_H
    local headerH = IKST_JobLayout.sectionHeaderH()
    -- Minimum height so Give / Search each fit field + action without colliding.
    local bandMin = headerH + (padY * 2) + IKST_JobLayout.FIELD_H + 8 + btnH + 4
    local bottomMin = bandMin * 2 + gap
    local listOuterH = math.floor(rect.h * 0.68)
    local bottomH = rect.h - listOuterH - gap
    if bottomH < bottomMin then
        bottomH = math.min(bottomMin, math.max(bandMin + gap, math.floor(rect.h * 0.38)))
        listOuterH = math.max(120, rect.h - bottomH - gap)
        bottomH = rect.h - listOuterH - gap
    end
    local selectedH = math.max(bandMin, math.floor((bottomH - gap) / 2))
    local searchH = bottomH - selectedH - gap
    if searchH < bandMin then
        searchH = bandMin
        selectedH = math.max(bandMin, bottomH - searchH - gap)
    end
    -- Final clamp so the three cards never spill past the content rect.
    if listOuterH + gap + selectedH + gap + searchH > rect.h then
        local overflow = listOuterH + gap + selectedH + gap + searchH - rect.h
        listOuterH = math.max(100, listOuterH - overflow)
    end

    local function openBand(x, y, w, h, title)
        local card, contentY = IKST_JobLayout.placeSectionCard(panel, x, y, w, h, nil, title)
        local areaX = inner
        local areaW = math.max(40, w - inner * 2)
        local areaY = contentY + padY
        local areaH = math.max(btnH, h - contentY - padY * 2)
        return card, areaX, areaY, areaW, areaH
    end

    -- 1) Item list with icons (dominant)
    do
        local card, ax, ay, aw, ah = openBand(
            rect.x, rect.y, rect.w, listOuterH,
            IKST.text("IGUI_IKST_Catalog_All", "Items")
        )
        panel.staffItemList = ISScrollingListBox:new(ax, ay, aw, ah)
        panel.staffItemList:initialise()
        panel.staffItemList:instantiate()
        panel.staffItemList.itemheight = 32
        panel.staffItemList.font = UIFont.Small
        panel.staffItemList.drawBorder = true
        panel.staffItemList.doDrawItem = IKST_JobStaff.drawItemListItem
        if IKUI_Chrome and type(IKUI_Chrome.styleListBox) == "function" then
            IKUI_Chrome.styleListBox(panel.staffItemList)
        end
        IKST_JobLayout.attachToolWidget(panel, card, panel.staffItemList)
        panel.staffItemList.onmousedown = function(target, mx, my)
            if target and target.onMouseDown then
                target:onMouseDown(mx, my)
            end
            IKST_JobStaff.onItemListSelect(panel)
        end
        if type(panel.staffItemList.setOnMouseDownFunction) == "function" then
            panel.staffItemList:setOnMouseDownFunction(panel, function(_target, _row)
                IKST_JobStaff.onItemListSelect(panel)
            end)
        end
        local q = ""
        if panel.staffItemFilterText and panel.staffItemFilterText ~= "" then
            q = panel.staffItemFilterText
        end
        IKST_JobStaff.refreshItemList(panel, q)
    end

    -- 2) Selected ID + amount + Give
    do
        local y = rect.y + listOuterH + gap
        local card, ax, ay, aw, ah = openBand(
            rect.x, y, rect.w, selectedH,
            IKST.text("IGUI_IKST_Give", "Selected")
        )
        local selectedFull = "Base.Axe"
        if panel.staffItemList and panel.staffItemList.selected
            and panel.staffItemList.items and panel.staffItemList.items[panel.staffItemList.selected] then
            local entry = panel.staffItemList.items[panel.staffItemList.selected].item
            if entry and entry.full then
                selectedFull = entry.full
            end
        elseif panel.staffItemTypeText and panel.staffItemTypeText ~= "" then
            selectedFull = panel.staffItemTypeText
        end
        IKST_JobLayout.placeFieldActionCorner(panel, card, ax, ay, aw, ah, {
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

    -- 3) Search at the bottom
    do
        local y = rect.y + listOuterH + gap + selectedH + gap
        local card, ax, ay, aw, ah = openBand(
            rect.x, y, rect.w, searchH,
            IKST.text("IGUI_IKST_ItemSearch", "Search item")
        )
        IKST_JobLayout.placeFieldActionCorner(panel, card, ax, ay, aw, ah, {
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

    panel._ikstToolFit = true
    return rect.y + rect.h
end

function IKST_JobStaff.buildPlayersHand(panel, contentTop)
    local p = panel.player
    if not p then
        return 8
    end
    local rect = IKST_JobLayout.toolContentRect(panel)
    if contentTop and contentTop > rect.y then
        local shrink = contentTop - rect.y
        rect.y = contentTop
        rect.h = math.max(80, rect.h - shrink)
    end
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
        local card, ax, ay, aw, ah = openBand(bands[1], IKST.text("IGUI_IKST_Util_Players", "Online players"))
        local listH, pillH, gapLP = IKST_JobLayout.listPillSplit(ah, 1, true)
        local rows = IKST_JobLayout.rowsForListHeight(listH)
        local listBottom = IKST_JobStaff.buildPlayerSelectList(panel, card, ax, ay, aw, rows)
        local pillAreaY = listBottom + gapLP
        local pillAreaH = math.max(btnH, pillH)
        if pillAreaY + pillAreaH > ay + ah then
            pillAreaY = math.max(ay, ay + ah - pillAreaH)
        end
        IKST_JobLayout.placePillGroup(panel, card, ax, pillAreaY, aw, pillAreaH, {
            {
                label = IKST.text("IGUI_IKST_RefreshList", "Refresh"),
                onClick = function()
                    IKST_JobStaff.requestPlayers(panel.player)
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[2], IKST.text("IGUI_IKST_Heal", "Care"))
        local target = IKST_JobStaff.getSelectedTarget(panel)
        local items = {}
        if target then
            local tid = target.id
            items = {
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
                            IKST.notify(p, IKST.text("IGUI_IKST_InvalidItem", "Unknown item — pick one on Items first."), false)
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
        end
        if #items > 0 then
            IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, items)
        end
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[3], IKST.text("IGUI_IKST_Clearance_Header", "Clearance"))
        local target = IKST_JobStaff.getSelectedTarget(panel)
        IKST_JobLayout.placeFieldActionCorner(panel, card, ax, ay, aw, ah, {
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
            local btnW, btnH2 = IKST_JobLayout.standardPillSize(panel)
            local ox, gridW = IKST_JobLayout.packFrame(ax, aw, btnW)
            IKST_JobLayout.placePill(panel, card, {
                x = ox,
                y = ay + ah - btnH2,
                w = btnW,
                h = btnH2,
            }, IKST.text("IGUI_IKST_Clearance_Revoke", "Revoke"), function()
                local t = IKST_JobStaff.getSelectedTarget(panel)
                if not t then
                    return
                end
                IKST.dispatchCommand(p, IKST.CMD.clearanceRevokeTarget, { target = t.id })
            end, false)
        end
    end

    panel._ikstToolFit = true
    return rect.y + rect.h
end

function IKST_JobStaff.buildWaypointsHand(panel, contentTop)
    local p = panel.player
    if not p then
        return 8
    end
    local rect = IKST_JobLayout.toolContentRect(panel)
    if contentTop and contentTop > rect.y then
        local shrink = contentTop - rect.y
        rect.y = contentTop
        rect.h = math.max(80, rect.h - shrink)
    end
    local gap = 6
    local bands = IKST_JobLayout.splitBands(rect.y, rect.h, 4, gap)
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
        local card, ax, ay, aw, ah = openBand(bands[1], IKST.text("IGUI_IKST_WaypointName", "Waypoint"))
        IKST_JobLayout.placeFieldActionCorner(panel, card, ax, ay, aw, ah, {
            { text = panel.staffWaypointName or "Base", fieldName = "staffWpName" },
        }, IKST.text("IGUI_IKST_Teleport", "Go"), function()
            IKST.dispatchCommand(p, IKST.CMD.tpWaypoint, { name = IKST_JobStaff.readEntry(panel.staffWpName) })
        end)
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[2], IKST.text("IGUI_IKST_WaypointSave", "Library"))
        local listH, pillH, gapLP = IKST_JobLayout.listPillSplit(ah, 1)
        local list = ISScrollingListBox:new(ax, ay, aw, listH)
        list:initialise()
        list:instantiate()
        list.itemheight = 20
        list.font = UIFont.Small
        list.drawBorder = true
        IKST_JobLayout.attachToolWidget(panel, card, list)
        panel.staffWpList = list
        local wps = IKST_JobStaff.waypoints or {}
        for i, wp in ipairs(wps) do
            if i > 40 then
                break
            end
            local label = wp.name .. " (" .. math.floor(wp.x) .. "," .. math.floor(wp.y) .. ")"
            list:addItem(label, wp)
        end
        list.onmousedown = function(target, mx, my)
            if target and target.onMouseDown then
                target:onMouseDown(mx, my)
            end
            local sel = target and target.items and target.selected and target.items[target.selected]
            if sel and sel.item and sel.item.name then
                panel.staffWaypointName = sel.item.name
                if panel.staffWpName and type(panel.staffWpName.setText) == "function" then
                    panel.staffWpName:setText(sel.item.name)
                end
            end
        end
        local pillY = ay + listH + gapLP
        local pillAreaH = math.max(btnH, pillH)
        IKST_JobLayout.placePillGroup(panel, card, ax, pillY, aw, pillAreaH, {
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
                    IKST.dispatchCommand(panel.player, IKST.CMD.helpList, {})
                    IKST.dispatchCommand(panel.player, IKST.CMD.staffHistoryList, { count = 30 })
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[3], IKST.text("IGUI_IKST_EventStaff", "Event"))
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
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

    do
        local card, ax, ay, aw, ah = openBand(bands[4], IKST.text("IGUI_IKST_HelpQueue", "Help queue"))
        local ticketH = 0
        if IKST_TicketsUI and type(IKST_TicketsUI.openInbox) == "function" then
            ticketH = btnH + 6
            IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, btnH, {
                {
                    label = IKST.text("IGUI_IKST_SeeTickets", "See tickets"),
                    primary = true,
                    onClick = function()
                        IKST_TicketsUI.openInbox(p)
                    end,
                },
            })
        end
        local listY = ay + ticketH
        local listH = math.max(40, ah - ticketH)
        local list = ISScrollingListBox:new(ax, listY, aw, listH)
        list:initialise()
        list:instantiate()
        list.itemheight = 22
        list.font = UIFont.Small
        list.drawBorder = true
        IKST_JobLayout.attachToolWidget(panel, card, list)
        local pending = IKST_JobStaff.helpPending or {}
        for i, row in ipairs(pending) do
            if i > 40 then
                break
            end
            local line = tostring(row.user) .. ": " .. tostring(row.message or "")
            list:addItem(line, row)
        end
        list.onmousedown = function(target, mx, my)
            if target and target.onMouseDown then
                target:onMouseDown(mx, my)
            end
            local sel = target and target.items and target.selected and target.items[target.selected]
            local row = sel and sel.item
            if row and row.x then
                IKST.dispatchCommand(p, IKST.CMD.tpCoords, {
                    x = row.x, y = row.y, z = row.z or 0,
                })
            end
        end
    end

    panel._ikstToolFit = true
    return rect.y + rect.h
end

function IKST_JobStaff.buildWorldHand(panel, contentTop)
    local p = panel.player
    if not p then
        return 8
    end
    local rect = IKST_JobLayout.toolContentRect(panel)
    if contentTop and contentTop > rect.y then
        local shrink = contentTop - rect.y
        rect.y = contentTop
        rect.h = math.max(80, rect.h - shrink)
    end
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
        local card, ax, ay, aw, ah = openBand(bands[1], IKST.text("IGUI_IKST_TimeHour", "Time"))
        IKST_JobLayout.placeFieldActionCorner(panel, card, ax, ay, aw, ah, {
            { text = "12", fieldName = "staffHour" },
        }, IKST.text("IGUI_IKST_SetTime", "Set time"), function()
            IKST_ClientStaff.runSetTime(p, IKST_JobStaff.readNumber(panel.staffHour, 12))
        end)
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[2], IKST.text("IGUI_IKST_SectionWeather", "Weather"))
        local weatherItems = {}
        for _, preset in ipairs({ "Clear", "Rain", "Storm", "Fog" }) do
            local name = preset
            weatherItems[#weatherItems + 1] = {
                label = IKST.text("IGUI_IKST_Weather_" .. name, name),
                onClick = function()
                    IKST_ClientStaff.runWeather(p, name)
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

    do
        local card, ax, ay, aw, ah = openBand(bands[3], IKST.text("IGUI_IKST_ClearZombies", "Zombies"))
        local radius = panel.staffZombieRadius or 30
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_ClearZombies", "Clear zombies"),
                primary = true,
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.clearZombies, { radius = panel.staffZombieRadius or 30 })
                end,
            },
            {
                label = IKST.text("IGUI_IKST_ZombieRadius", "Zombie radius") .. " " .. tostring(radius),
                onClick = function()
                    local presets = { 15, 30, 60, 0 }
                    local cur = panel.staffZombieRadius or 30
                    local idx = 1
                    for i, val in ipairs(presets) do
                        if val == cur then
                            idx = i
                            break
                        end
                    end
                    panel.staffZombieRadius = presets[(idx % #presets) + 1]
                    panel:refreshJobUI()
                end,
            },
        })
    end

    panel._ikstToolFit = true
    return rect.y + rect.h
end

function IKST_JobStaff.buildBatchHand(panel, contentTop)
    local p = panel.player
    if not p then
        return 8
    end
    local rect = IKST_JobLayout.toolContentRect(panel)
    if contentTop and contentTop > rect.y then
        local shrink = contentTop - rect.y
        rect.y = contentTop
        rect.h = math.max(80, rect.h - shrink)
    end
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

    do
        local card, ax, ay, aw, ah = openBand(bands[1], IKST.text("IGUI_IKST_BatchNote", "Batch care"))
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
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
        local card, ax, ay, aw, ah = openBand(bands[2], IKST.text("IGUI_IKST_TpAllToMe", "Teleport"))
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_TpAllToMe", "TP all to me"),
                primary = true,
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.tpAllToMe, {})
                end,
            },
        })
    end

    panel._ikstToolFit = true
    return rect.y + rect.h
end

function IKST_JobStaff.buildSelfHand(panel, contentTop)
    local p = panel.player
    if not p then
        return 8
    end
    local rect = IKST_JobLayout.toolContentRect(panel)
    if contentTop and contentTop > rect.y then
        local shrink = contentTop - rect.y
        rect.y = contentTop
        rect.h = math.max(80, rect.h - shrink)
    end
    local gap = 6
    local bands = IKST_JobLayout.splitBands(rect.y, rect.h, 5, gap)
    local inner = IKST_JobLayout.SECTION_INNER
    local padY = IKST_JobLayout.CONTENT_PAD_Y
    local btnW, btnH = IKST_JobLayout.standardPillSize(panel)

    local function openBand(band, title)
        local card, contentY = IKST_JobLayout.placeSectionCard(panel, rect.x, band.y, rect.w, band.h, nil, title)
        local areaX = inner
        local areaW = math.max(40, rect.w - inner * 2)
        local areaY = contentY + padY
        local areaH = math.max(btnH, band.h - contentY - padY * 2)
        return card, areaX, areaY, areaW, areaH
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[1], IKST.text("IGUI_IKST_Self_Vitals", "Vitals"))
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_Heal", "Heal"),
                primary = true,
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.healSelf, {})
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Feed", "Feed"),
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.feedSelf, {})
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Cure", "Cure"),
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.cureSelf, {})
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[2], IKST.text("IGUI_IKST_Self_Modes", "Modes"))
        local items = {}
        if IKST.engineStaffModesAvailable and IKST.engineStaffModesAvailable() then
            items = {
                {
                    label = IKST.text("IGUI_IKST_God", "God"),
                    onClick = function()
                        IKST.dispatchCommand(p, IKST.CMD.godSelf, {})
                    end,
                },
                {
                    label = IKST.text("IGUI_IKST_Invis", "Invisible"),
                    onClick = function()
                        IKST.dispatchCommand(p, IKST.CMD.invisSelf, {})
                    end,
                },
                {
                    label = IKST.text("IGUI_IKST_Ghost", "Ghost"),
                    onClick = function()
                        IKST.dispatchCommand(p, IKST.CMD.ghostSelf, {})
                    end,
                },
                {
                    label = IKST.text("IGUI_IKST_NoClip", "NoClip"),
                    primary = true,
                    onClick = function()
                        IKST.dispatchCommand(p, IKST.CMD.noclipSelf, {})
                    end,
                },
            }
        end
        if #items > 0 then
            IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, items)
        end
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[3], IKST.text("IGUI_IKST_TpCoords", "Teleport X,Y,Z"))
        IKST_JobLayout.placeFieldActionCorner(panel, card, ax, ay, aw, ah, {
            { text = tostring(math.floor(p:getX())), fieldName = "staffTpX" },
            { text = tostring(math.floor(p:getY())), fieldName = "staffTpY" },
            { text = tostring(p:getZ()), fieldName = "staffTpZ" },
        }, IKST.text("IGUI_IKST_Teleport", "Go"), function()
            IKST.dispatchCommand(p, IKST.CMD.tpCoords, {
                x = IKST_JobStaff.readNumber(panel.staffTpX),
                y = IKST_JobStaff.readNumber(panel.staffTpY),
                z = IKST_JobStaff.readNumber(panel.staffTpZ, 0),
            })
        end)
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[4], IKST.text("IGUI_IKST_Self_Cheats", "Vanilla cheats (toggle)"))
        local cheatIds = IKST_StaffCheats.SELF_UI or {
            "build", "mechanics", "health", "fastMove",
            "unlimitedCarry", "unlimitedEndurance", "unlimitedAmmo", "instantActions",
            "movables", "farming",
        }
        local items = {}
        if IKST.engineStaffModesAvailable and IKST.engineStaffModesAvailable()
            and IKST_StaffCheats and IKST_StaffCheats.CHEATS then
            for _, cheatId in ipairs(cheatIds) do
                local row = IKST_StaffCheats.CHEATS[cheatId]
                if row then
                    local id = cheatId
                    items[#items + 1] = {
                        label = IKST.text(row.labelKey, row.fallback),
                        primary = IKST_StaffCheats.isActive(p, id) == true,
                        onClick = function()
                            IKST.dispatchCommand(p, IKST.CMD.toggleSelfCheat, { cheat = id })
                            panel:refreshJobUI()
                        end,
                    }
                end
            end
        end
        if #items > 0 then
            IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, items)
        end
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[5], IKST.text("IGUI_IKST_Self_Maint", "Maintenance & clearance"))
        panel.staffClearanceZone = ISTextEntryBox:new("armory", -2000, -2000, 40, 20)
        panel.staffClearanceZone:initialise()
        panel.staffClearanceZone:instantiate()
        panel:addJobWidget(panel.staffClearanceZone)
        if type(panel.staffClearanceZone.setVisible) == "function" then
            panel.staffClearanceZone:setVisible(false)
        end
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_RepairGear", "Repair gear"),
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.repairSelfGear, {})
                end,
            },
            {
                label = IKST.text("IGUI_IKST_ResetMood", "Reset mood"),
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.resetSelfMood, {})
                end,
            },
            {
                label = IKST.text("IGUI_IKST_ClearZombiesNear", "Clear nearby"),
                primary = true,
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.clearZombiesSelf, { radius = 20 })
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Clearance_Issue", "Issue tag"),
                onClick = function()
                    local zoneId = IKST_JobStaff.readEntry(panel.staffClearanceZone)
                    IKST.dispatchCommand(p, IKST.CMD.clearanceIssueSelf, { zoneId = zoneId })
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Clearance_Revoke", "Revoke"),
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.clearanceRevokeSelf, {})
                end,
            },
            {
                label = IKST.text("IGUI_IKST_Clearance_SetLock", "Set clearance lock here"),
                primary = true,
                onClick = function()
                    local zoneId = IKST_JobStaff.readEntry(panel.staffClearanceZone)
                    local cx, cy, cz = IKST_JobStaff.containerSquareAtPlayer(p)
                    if not cx then
                        IKST.notify(p, IKST.text("IGUI_IKST_Keypad_NoContainer", "Stand next to a container."), false)
                        return
                    end
                    IKST.dispatchCommand(p, IKST.CMD.clearanceSetLock, { x = cx, y = cy, z = cz, zoneId = zoneId })
                end,
            },
        })
    end

    panel._ikstToolFit = true
    return rect.y + rect.h
end

function IKST_JobStaff.build(panel)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return
    end
    if not state.staffMode then
        state.staffMode = "self"
    end

    local y = 8
    local showStaffModes = (panel.view == IKST.VIEW.server and state.navTool == "players")
        or (panel.view == IKST.VIEW.players)
    if panel.view == IKST.VIEW.utilities then
        showStaffModes = false
    end
    if showStaffModes then
        local modes = { "self", "world", "items", "waypoints" }
        if IKST.isMultiplayerSession() then
            modes[#modes + 1] = "players"
            modes[#modes + 1] = "batch"
            modes[#modes + 1] = "moderate"
        end
        local modeSpecs = {}
        for _, mode in ipairs(modes) do
            modeSpecs[#modeSpecs + 1] = {
                label = IKST.text("IGUI_IKST_Staff_" .. mode, mode),
                w = 72,
                primary = state.staffMode == mode,
                fn = function()
                    state.staffMode = mode
                    if mode == "players" or mode == "moderate" then
                        IKST_JobStaff.requestPlayers(panel.player)
                    elseif mode == "waypoints" then
                        IKST_JobStaff.requestWaypoints(panel.player)
                    end
                    panel:refreshJobUI()
                end,
            }
        end
        y = IKST_JobLayout.flowRow(panel, y, modeSpecs, 6, 24)
    end

    local p = panel.player

    if state.staffMode == "self" then
        return IKST_JobStaff.buildSelfHand(panel, y)
    elseif state.staffMode == "world" then
        return IKST_JobStaff.buildWorldHand(panel, y)
    elseif state.staffMode == "items" then
        return IKST_JobStaff.buildItemsHand(panel, y)
    elseif state.staffMode == "players" then
        return IKST_JobStaff.buildPlayersHand(panel, y)
    elseif state.staffMode == "batch" then
        return IKST_JobStaff.buildBatchHand(panel, y)

    elseif state.staffMode == "moderate" then
        if not IKST_JobGuard then
            require "IKST_JobGuard"
        end
        if IKST_JobGuard and type(IKST_JobGuard.buildTools) == "function" then
            return IKST_JobGuard.buildTools(panel, y)
        end

    elseif state.staffMode == "waypoints" then
        return IKST_JobStaff.buildWaypointsHand(panel, y)
    end

    return y
end

function IKST_JobStaff.onListResult(players)
    IKST_JobStaff.onlinePlayers = players or {}
    if IKST_JobsPanel and IKST_JobsPanel.instance then
        IKST_JobsPanel.instance:refreshJobUI()
    end
end

function IKST_JobStaff.onWaypointListResult(waypoints)
    IKST_JobStaff.waypoints = waypoints or {}
    if IKST_JobsPanel and IKST_JobsPanel.instance then
        IKST_JobsPanel.instance:refreshJobUI()
    end
end

function IKST_JobStaff.onHelpListResult(args)
    IKST_JobStaff.helpPending = (args and args.pending) or {}
    if IKST_JobsPanel and IKST_JobsPanel.instance then
        IKST_JobsPanel.instance:refreshJobUI()
    end
end

function IKST_JobStaff.onHistoryResult(args)
    IKST_JobStaff.historyEntries = (args and args.entries) or {}
    if IKST_JobsPanel and IKST_JobsPanel.instance then
        IKST_JobsPanel.instance:refreshJobUI()
    end
end
