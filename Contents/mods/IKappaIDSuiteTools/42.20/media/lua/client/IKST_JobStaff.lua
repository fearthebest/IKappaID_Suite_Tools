if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISTextEntryBox"
require "ISUI/ISScrollingListBox"
require "IKST_Shared"
require "IKST_Chrome"
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
        panel.staffItemList:addItem(entry.label .. "  (" .. entry.full .. ")", entry)
    end
    panel.staffItemListTotal = total
    panel.staffItemListShown = #rows
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
        if entry and entry.full and panel.staffItemType then
            panel.staffItemType:setText(entry.full)
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
    local listH = IKST_JobLayout.selectListHeight(visibleRows or 8)
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
        local leftX = panel.contentX or IKST_JobLayout.MARGIN
        local contentW = math.max(160, panel.contentW or (panel.width - 24))
        local btnH = 24
        local gap = 6

        panel:makeJobLabel(leftX, y, IKST.text("IGUI_IKST_Self_Vitals", "Vitals"), UIFont.Medium)
        y = y + 20
        y = IKST_JobLayout.flowRow(panel, y, {
            { label = IKST.text("IGUI_IKST_Heal", "Heal"), w = 88, primary = true, fn = function()
                IKST.dispatchCommand(p, IKST.CMD.healSelf, {})
            end },
            { label = IKST.text("IGUI_IKST_Feed", "Feed"), w = 88, primary = false, fn = function()
                IKST.dispatchCommand(p, IKST.CMD.feedSelf, {})
            end },
            { label = IKST.text("IGUI_IKST_Cure", "Cure"), w = 88, primary = false, fn = function()
                IKST.dispatchCommand(p, IKST.CMD.cureSelf, {})
            end },
        }, gap, btnH)

        if IKST.engineStaffModesAvailable and IKST.engineStaffModesAvailable() then
            panel:makeJobLabel(leftX, y, IKST.text("IGUI_IKST_Self_Modes", "Modes"), UIFont.Medium)
            y = y + 20
            y = IKST_JobLayout.flowRow(panel, y, {
                { label = IKST.text("IGUI_IKST_God", "God"), w = 80, primary = false, fn = function()
                    IKST.dispatchCommand(p, IKST.CMD.godSelf, {})
                end },
                { label = IKST.text("IGUI_IKST_Invis", "Invisible"), w = 88, primary = false, fn = function()
                    IKST.dispatchCommand(p, IKST.CMD.invisSelf, {})
                end },
                { label = IKST.text("IGUI_IKST_Ghost", "Ghost"), w = 80, primary = false, fn = function()
                    IKST.dispatchCommand(p, IKST.CMD.ghostSelf, {})
                end },
                { label = IKST.text("IGUI_IKST_NoClip", "NoClip"), w = 80, primary = true, fn = function()
                    IKST.dispatchCommand(p, IKST.CMD.noclipSelf, {})
                end },
            }, gap, btnH)
        end

        panel:makeJobLabel(leftX, y, IKST.text("IGUI_IKST_TpCoords", "Teleport X,Y,Z"), UIFont.Medium)
        y = y + 20
        local goW = 64
        local fieldW = math.max(48, math.floor((contentW - goW - (gap * 3)) / 3))
        local zW = math.max(40, contentW - goW - (gap * 3) - (fieldW * 2))
        panel.staffTpX = ISTextEntryBox:new(tostring(math.floor(p:getX())), leftX, y, fieldW, 22)
        panel.staffTpX:initialise()
        panel.staffTpX:instantiate()
        panel:addJobWidget(panel.staffTpX)
        panel.staffTpY = ISTextEntryBox:new(tostring(math.floor(p:getY())), leftX + fieldW + gap, y, fieldW, 22)
        panel.staffTpY:initialise()
        panel.staffTpY:instantiate()
        panel:addJobWidget(panel.staffTpY)
        panel.staffTpZ = ISTextEntryBox:new(tostring(p:getZ()), leftX + ((fieldW + gap) * 2), y, zW, 22)
        panel.staffTpZ:initialise()
        panel.staffTpZ:instantiate()
        panel:addJobWidget(panel.staffTpZ)
        local goX = leftX + fieldW + gap + fieldW + gap + zW + gap
        if goX + goW > leftX + contentW then
            goX = leftX + contentW - goW
        end
        panel:makeJobButton(goX, y, goW, 22, IKST.text("IGUI_IKST_Teleport", "Go"), function()
            IKST.dispatchCommand(p, IKST.CMD.tpCoords, {
                x = IKST_JobStaff.readNumber(panel.staffTpX),
                y = IKST_JobStaff.readNumber(panel.staffTpY),
                z = IKST_JobStaff.readNumber(panel.staffTpZ, 0),
            })
        end, true)
        y = y + 34

        if IKST.engineStaffModesAvailable and IKST.engineStaffModesAvailable()
            and IKST_StaffCheats and IKST_StaffCheats.SELF_UI then
            panel:makeJobLabel(leftX, y, IKST.text("IGUI_IKST_Self_Cheats", "Vanilla cheats (toggle)"), UIFont.Medium)
            y = y + 20
            y = IKST_JobStaff.addSelfCheatRow(panel, y, {
                "build", "mechanics", "health", "fastMove",
            }, p)
            y = IKST_JobStaff.addSelfCheatRow(panel, y, {
                "unlimitedCarry", "unlimitedEndurance", "unlimitedAmmo", "instantActions",
            }, p)
            y = IKST_JobStaff.addSelfCheatRow(panel, y, {
                "movables", "farming",
            }, p)
        end

        panel:makeJobLabel(leftX, y, IKST.text("IGUI_IKST_Self_Maint", "Maintenance"), UIFont.Medium)
        y = y + 20
        y = IKST_JobLayout.flowRow(panel, y, {
            { label = IKST.text("IGUI_IKST_RepairGear", "Repair gear"), w = 110, primary = false, fn = function()
                IKST.dispatchCommand(p, IKST.CMD.repairSelfGear, {})
            end },
            { label = IKST.text("IGUI_IKST_ResetMood", "Reset mood"), w = 110, primary = false, fn = function()
                IKST.dispatchCommand(p, IKST.CMD.resetSelfMood, {})
            end },
            { label = IKST.text("IGUI_IKST_ClearZombiesNear", "Clear nearby"), w = 110, primary = true, fn = function()
                IKST.dispatchCommand(p, IKST.CMD.clearZombiesSelf, { radius = 20 })
            end },
        }, gap, btnH)

        panel:makeJobLabel(leftX, y, IKST.text("IGUI_IKST_Clearance_Header", "Clearance tags"), UIFont.Medium)
        y = y + 20
        local zoneW = math.max(80, math.floor(contentW * 0.38))
        local halfW = math.max(64, math.floor((contentW - zoneW - (gap * 2)) / 2))
        panel.staffClearanceZone = ISTextEntryBox:new("armory", leftX, y, zoneW, 22)
        panel.staffClearanceZone:initialise()
        panel.staffClearanceZone:instantiate()
        panel:addJobWidget(panel.staffClearanceZone)
        panel:makeJobButton(leftX + zoneW + gap, y, halfW, 22, IKST.text("IGUI_IKST_Clearance_Issue", "Issue tag"), function()
            local zoneId = IKST_JobStaff.readEntry(panel.staffClearanceZone)
            IKST.dispatchCommand(p, IKST.CMD.clearanceIssueSelf, { zoneId = zoneId })
        end, false)
        panel:makeJobButton(leftX + zoneW + gap + halfW + gap, y, halfW, 22, IKST.text("IGUI_IKST_Clearance_Revoke", "Revoke"), function()
            IKST.dispatchCommand(p, IKST.CMD.clearanceRevokeSelf, {})
        end, false)
        y = y + 30
        panel:makeJobButton(leftX, y, contentW, btnH, IKST.text("IGUI_IKST_Clearance_SetLock", "Set clearance lock here"), function()
            local zoneId = IKST_JobStaff.readEntry(panel.staffClearanceZone)
            local cx, cy, cz = IKST_JobStaff.containerSquareAtPlayer(p)
            if not cx then
                IKST.notify(p, IKST.text("IGUI_IKST_Keypad_NoContainer", "Stand next to a container."), false)
                return
            end
            IKST.dispatchCommand(p, IKST.CMD.clearanceSetLock, { x = cx, y = cy, z = cz, zoneId = zoneId })
        end, true)
        y = y + 34

    elseif state.staffMode == "world" then
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
        local weatherSpecs = {}
        for _, preset in ipairs({ "Clear", "Rain", "Storm", "Fog" }) do
            weatherSpecs[#weatherSpecs + 1] = {
                label = IKST.text("IGUI_IKST_Weather_" .. preset, preset),
                w = 70,
                fn = function()
                    IKST_ClientStaff.runWeather(p, preset)
                end,
            }
        end
        y = IKST_JobLayout.flowRow(panel, y, weatherSpecs, 6, 24)
        panel:makeJobButton(12, y, 120, 24, IKST.text("IGUI_IKST_ClearWeather", "Clear weather"), function()
            IKST_ClientStaff.runClearWeather(p)
        end, false)
        panel:makeJobButton(140, y, 140, 24, IKST.text("IGUI_IKST_ClearZombies", "Clear zombies"), function()
            IKST.dispatchCommand(p, IKST.CMD.clearZombies, { radius = panel.staffZombieRadius or 30 })
        end, true)
        y = y + 28
        panel:makeJobButton(12, y, 160, 24, IKST.text("IGUI_IKST_ZombieRadius", "Zombie radius") .. " " .. tostring(panel.staffZombieRadius or 30), function()
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
        end, false)
        y = y + 34

    elseif state.staffMode == "items" then
        if not state.staffItemCategory then
            state.staffItemCategory = IKST_Catalog.CATEGORY_ALL
        end
        local itemCatalog = IKST_JobStaff.loadItemCatalog()
        local itemCategories = IKST_Catalog.listCategories(itemCatalog, IKST.text("IGUI_IKST_Catalog_All", "All"))
        y = IKST_JobCatalog.buildCategoryRow(panel, y, itemCategories, state.staffItemCategory, function(catId)
            state.staffItemCategory = catId
            panel:refreshJobUI()
        end)

        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_ItemSearch", "Search item"), UIFont.Small)
        y = y + 16
        panel.staffItemFilter = ISTextEntryBox:new("", IKST_JobLayout.MARGIN, y, (panel.contentW or (panel.width - 24)) - 128, 22)
        panel.staffItemFilter:initialise()
        panel.staffItemFilter:instantiate()
        panel:addJobWidget(panel.staffItemFilter)
        panel:makeJobButton(IKST_JobLayout.contentRight(panel) - 108, y, 108, 22, IKST.text("IGUI_IKST_RefreshList", "Refresh"), function()
            IKST_JobStaff.itemCatalog = nil
            IKST_JobStaff.refreshItemList(panel, panel.staffItemFilter:getText())
        end, false)
        y = y + 28
        local listH = math.min(120, math.max(72, math.floor((panel.scrollHeight or 120) * 0.3)))
        panel.staffItemList = ISScrollingListBox:new(IKST_JobLayout.MARGIN, y, panel.contentW or (panel.width - 24), listH)
        panel.staffItemList:initialise()
        panel.staffItemList:instantiate()
        panel.staffItemList.itemheight = 20
        panel.staffItemList.font = UIFont.Small
        panel.staffItemList.drawBorder = true
        panel:addJobWidget(panel.staffItemList)
        panel.staffItemFilter.onTextChange = function()
            IKST_JobStaff.refreshItemList(panel, panel.staffItemFilter:getText())
        end
        panel.staffItemList.onmousedown = function(target, x, y)
            if target and target.onMouseDown then
                target:onMouseDown(x, y)
            end
            IKST_JobStaff.onItemListSelect(panel)
        end
        IKST_JobStaff.refreshItemList(panel, "")
        -- Advance past the list (plus gap) so the type row below doesn't cover its last row.
        y = y + listH + 6
        local trunc = IKST_JobCatalog.truncationNote(panel.staffItemListShown or 0, panel.staffItemListTotal or 0)
        if trunc then
            panel:makeJobLabel(12, y, trunc, UIFont.Small)
            y = y + 16
        end
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_ItemType", "Item type (Base.id)"), UIFont.Small)
        y = y + 16
        panel.staffItemType = ISTextEntryBox:new("Base.Axe", 12, y, 200, 22)
        panel.staffItemType:initialise()
        panel.staffItemType:instantiate()
        panel:addJobWidget(panel.staffItemType)
        panel.staffItemQty = ISTextEntryBox:new("1", 220, y, 40, 22)
        panel.staffItemQty:initialise()
        panel.staffItemQty:instantiate()
        panel:addJobWidget(panel.staffItemQty)
        panel:makeJobButton(270, y, 70, 22, IKST.text("IGUI_IKST_Give", "Give"), function()
            local itemType = IKST_JobStaff.getSelectedItemType(panel)
            if not IKST_Catalog.itemExists(itemType) then
                IKST.notify(p, IKST.text("IGUI_IKST_InvalidItem", "Unknown item type"), false)
                return
            end
            IKST.dispatchCommand(p, IKST.CMD.giveItem, {
                type = itemType,
                count = IKST_JobStaff.readNumber(panel.staffItemQty, 1),
            })
        end, true)
        y = y + 30
        local kitSpecs = {}
        for _, kit in ipairs({ "Tools", "Medical", "Food" }) do
            kitSpecs[#kitSpecs + 1] = {
                label = IKST.text("IGUI_IKST_Kit_" .. kit, kit),
                w = 90,
                fn = function()
                    IKST.dispatchCommand(p, IKST.CMD.giveKit, { kit = kit })
                end,
            }
        end
        y = IKST_JobLayout.flowRow(panel, y, kitSpecs, 6, 24)

    elseif state.staffMode == "players" then
        panel:makeJobButton(12, y, 100, 24, IKST.text("IGUI_IKST_RefreshList", "Refresh"), function()
            IKST_JobStaff.requestPlayers(panel.player)
        end, false)
        y = y + 28
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_ListFilter", "Filter"), UIFont.Small)
        y = y + 16
        y = IKST_JobStaff.buildPlayerSelectList(panel, nil, IKST_JobLayout.MARGIN, y,
            panel.contentW or (panel.width - 24), 8)
        y = y + 8
        local players = IKST_JobStaff.onlinePlayers or {}
        if #players == 0 then
            panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_PlayerListEmpty",
                "No players to list. Refresh, or join multiplayer."), UIFont.Small)
            y = y + 20
        end
        local target = IKST_JobStaff.getSelectedTarget(panel)
        if target then
            y = y + 4
            panel:makeJobButton(12, y, 72, 24, IKST.text("IGUI_IKST_Heal", "Heal"), function()
                IKST.dispatchCommand(p, IKST.CMD.healTarget, { target = target.id })
            end, true)
            panel:makeJobButton(90, y, 72, 24, IKST.text("IGUI_IKST_Bring", "Bring"), function()
                IKST.dispatchCommand(p, IKST.CMD.bringTarget, { target = target.id })
            end, false)
            panel:makeJobButton(168, y, 72, 24, IKST.text("IGUI_IKST_TpTo", "TP to"), function()
                IKST.dispatchCommand(p, IKST.CMD.tpToTarget, { target = target.id })
            end, false)
            panel:makeJobButton(246, y, 72, 24, IKST.text("IGUI_IKST_Give", "Give"), function()
                IKST.dispatchCommand(p, IKST.CMD.giveTarget, {
                    target = target.id,
                    type = "Base.Axe",
                    count = 1,
                })
            end, false)
            y = y + 28
            panel:makeJobButton(12, y, 72, 24, IKST.text("IGUI_IKST_Feed", "Feed"), function()
                IKST.dispatchCommand(p, IKST.CMD.feedTarget, { target = target.id })
            end, false)
            panel:makeJobButton(90, y, 72, 24, IKST.text("IGUI_IKST_Cure", "Cure"), function()
                IKST.dispatchCommand(p, IKST.CMD.cureTarget, { target = target.id })
            end, false)
            if IKST.engineStaffModesAvailable and IKST.engineStaffModesAvailable() then
                panel:makeJobButton(168, y, 72, 24, IKST.text("IGUI_IKST_God", "God"), function()
                    IKST.dispatchCommand(p, IKST.CMD.godTarget, { target = target.id })
                end, false)
            end
            y = y + 28
            if not panel.staffTargetClearanceZone then
                panel.staffTargetClearanceZone = ISTextEntryBox:new("armory", 12, y, 120, 22)
                panel.staffTargetClearanceZone:initialise()
                panel.staffTargetClearanceZone:instantiate()
                panel:addJobWidget(panel.staffTargetClearanceZone)
            else
                panel.staffTargetClearanceZone:setY(y)
                panel.staffTargetClearanceZone:setVisible(true)
            end
            panel:makeJobButton(140, y, 100, 22, IKST.text("IGUI_IKST_Clearance_Issue", "Issue tag"), function()
                IKST.dispatchCommand(p, IKST.CMD.clearanceIssueTarget, {
                    target = target.id,
                    zoneId = IKST_JobStaff.readEntry(panel.staffTargetClearanceZone),
                })
            end, false)
            panel:makeJobButton(248, y, 90, 22, IKST.text("IGUI_IKST_Clearance_Revoke", "Revoke"), function()
                IKST.dispatchCommand(p, IKST.CMD.clearanceRevokeTarget, { target = target.id })
            end, false)
            y = y + 30
        end

    elseif state.staffMode == "batch" then
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_BatchNote", "Affects all online players"), UIFont.Small)
        y = y + 20
        panel:makeJobButton(12, y, 100, 24, IKST.text("IGUI_IKST_HealAll", "Heal all"), function()
            IKST.dispatchCommand(p, IKST.CMD.healAll, {})
        end, true)
        panel:makeJobButton(118, y, 100, 24, IKST.text("IGUI_IKST_FeedAll", "Feed all"), function()
            IKST.dispatchCommand(p, IKST.CMD.feedAll, {})
        end, false)
        panel:makeJobButton(224, y, 100, 24, IKST.text("IGUI_IKST_CureAll", "Cure all"), function()
            IKST.dispatchCommand(p, IKST.CMD.cureAll, {})
        end, false)
        y = y + 28
        panel:makeJobButton(12, y, 160, 24, IKST.text("IGUI_IKST_TpAllToMe", "TP all to me"), function()
            IKST.dispatchCommand(p, IKST.CMD.tpAllToMe, {})
        end, true)
        y = y + 34

    elseif state.staffMode == "moderate" then
        if not IKST_JobGuard then
            require "IKST_JobGuard"
        end
        if IKST_JobGuard and IKST_JobGuard.buildTools then
            y = IKST_JobGuard.buildTools(panel, y)
        end

    elseif state.staffMode == "waypoints" then
        panel:makeJobButton(12, y, 100, 24, IKST.text("IGUI_IKST_RefreshList", "Refresh"), function()
            IKST_JobStaff.requestWaypoints(panel.player)
            IKST.dispatchCommand(panel.player, IKST.CMD.helpList, {})
            IKST.dispatchCommand(panel.player, IKST.CMD.staffHistoryList, { count = 30 })
        end, false)
        y = y + 28
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_WaypointName", "Waypoint name"), UIFont.Small)
        y = y + 16
        panel.staffWpName = ISTextEntryBox:new(panel.staffWaypointName or "Base", 12, y, 160, 22)
        panel.staffWpName:initialise()
        panel.staffWpName:instantiate()
        panel:addJobWidget(panel.staffWpName)
        panel:makeJobButton(180, y, 50, 22, IKST.text("IGUI_IKST_Teleport", "Go"), function()
            IKST.dispatchCommand(p, IKST.CMD.tpWaypoint, { name = IKST_JobStaff.readEntry(panel.staffWpName) })
        end, true)
        panel:makeJobButton(236, y, 70, 22, IKST.text("IGUI_IKST_WaypointSave", "Save here"), function()
            IKST.dispatchCommand(p, IKST.CMD.saveWaypoint, { name = IKST_JobStaff.readEntry(panel.staffWpName) })
        end, false)
        panel:makeJobButton(312, y, 70, 22, IKST.text("IGUI_IKST_WaypointDel", "Delete"), function()
            IKST.dispatchCommand(p, IKST.CMD.delWaypoint, { name = IKST_JobStaff.readEntry(panel.staffWpName) })
        end, false)
        y = y + 30
        local wps = IKST_JobStaff.waypoints or {}
        for i, wp in ipairs(wps) do
            if i > 8 then
                break
            end
            local label = wp.name .. " (" .. math.floor(wp.x) .. "," .. math.floor(wp.y) .. ")"
            panel:makeJobButton(IKST_JobLayout.MARGIN, y, panel.contentW or (panel.width - 24), 22, label, function()
                panel.staffWaypointName = wp.name
                IKST.dispatchCommand(p, IKST.CMD.tpWaypoint, { name = wp.name })
            end, panel.staffWaypointName == wp.name)
            y = y + 24
        end
        if #wps == 0 then
            panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_NoWaypoints", "No waypoints saved yet."), UIFont.Small)
            y = y + 20
        end
        y = y + 8
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_EventStaff", "Event teleport"), UIFont.Small)
        y = y + 18
        panel:makeJobButton(12, y, 140, 22, IKST.text("IGUI_IKST_EventSet", "Set event here"), function()
            IKST.dispatchCommand(p, IKST.CMD.eventSet, { name = IKST_JobStaff.readEntry(panel.staffWpName) })
        end, true)
        panel:makeJobButton(160, y, 120, 22, IKST.text("IGUI_IKST_EventClear", "Clear event"), function()
            IKST.dispatchCommand(p, IKST.CMD.eventClear, {})
        end, false)
        y = y + 30
        if IKST_TicketsUI and type(IKST_TicketsUI.openInbox) == "function" then
            panel:makeJobButton(12, y, 160, 24, IKST.text("IGUI_IKST_SeeTickets", "See tickets"), function()
                IKST_TicketsUI.openInbox(p)
            end, true)
            y = y + 28
        end
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_HelpQueue", "Help requests"), UIFont.Small)
        y = y + 18
        local pending = IKST_JobStaff.helpPending or {}
        if #pending == 0 then
            panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_HelpEmpty", "No open help requests."), UIFont.Small)
            y = y + 20
        else
            for i, row in ipairs(pending) do
                if i > 6 then
                    break
                end
                local line = tostring(row.user) .. ": " .. tostring(row.message or "")
                panel:makeJobButton(12, y, (panel.contentW or (panel.width - 24)) - 80, 22, line, function()
                    IKST.dispatchCommand(p, IKST.CMD.tpCoords, {
                        x = row.x, y = row.y, z = row.z or 0,
                    })
                end, false)
                panel:makeJobButton((panel.contentW or (panel.width - 24)) - 60, y, 70, 22,
                    IKST.text("IGUI_IKST_HelpResolve", "Done"), function()
                        IKST.dispatchCommand(p, IKST.CMD.helpResolve, { id = row.id })
                        IKST.dispatchCommand(p, IKST.CMD.helpList, {})
                    end, false)
                y = y + 24
            end
        end
        y = y + 8
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_StaffHistory", "Staff history"), UIFont.Small)
        y = y + 18
        local hist = IKST_JobStaff.historyEntries or {}
        if #hist == 0 then
            panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_StaffHistoryEmpty", "No history rows yet."), UIFont.Small)
            y = y + 20
        else
            for i = #hist, math.max(1, #hist - 9), -1 do
                local e = hist[i]
                if e then
                    local line = tostring(e.user or "?") .. " " .. tostring(e.cmd or "")
                        .. " " .. tostring(e.reason or "")
                    if #line > 70 then
                        line = string.sub(line, 1, 70) .. "…"
                    end
                    panel:makeJobLabel(12, y, line, UIFont.Small)
                    y = y + 16
                end
            end
        end
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
