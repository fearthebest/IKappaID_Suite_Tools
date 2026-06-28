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

IKST_JobStaff = IKST_JobStaff or {}
IKST_JobStaff.onlinePlayers = {}
IKST_JobStaff.waypoints = {}
IKST_JobStaff.itemCatalog = nil

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
    return IKST.parseNumber(IKST_JobStaff.readEntry(entry), fallback)
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
    local idx = panel.staffTargetIndex or 1
    if idx < 1 or idx > #list then
        return nil
    end
    return list[idx]
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
        local x = 12
        for _, mode in ipairs(modes) do
            local label = IKST.text("IGUI_IKST_Staff_" .. mode, mode:sub(1, 1):upper() .. mode:sub(2))
            panel:makeJobButton(x, y, 72, 24, label, function()
                state.staffMode = mode
                if mode == "players" or mode == "moderate" then
                    IKST_JobStaff.requestPlayers(panel.player)
                elseif mode == "waypoints" then
                    IKST_JobStaff.requestWaypoints(panel.player)
                end
                panel:refreshJobUI()
            end, state.staffMode == mode)
            x = x + 76
            if x > IKST_JobLayout.contentRight(panel) - 80 then
                x = 12
                y = y + 28
            end
        end
        y = y + 32
    end

    local p = panel.player

    if state.staffMode == "self" then
        panel:makeJobButton(12, y, 90, 24, IKST.text("IGUI_IKST_Heal", "Heal"), function()
            IKST.dispatchCommand(p, IKST.CMD.healSelf, {})
        end, true)
        panel:makeJobButton(108, y, 90, 24, IKST.text("IGUI_IKST_Feed", "Feed"), function()
            IKST.dispatchCommand(p, IKST.CMD.feedSelf, {})
        end, false)
        panel:makeJobButton(204, y, 90, 24, IKST.text("IGUI_IKST_Cure", "Cure"), function()
            IKST.dispatchCommand(p, IKST.CMD.cureSelf, {})
        end, false)
        y = y + 28
        panel:makeJobButton(12, y, 90, 24, IKST.text("IGUI_IKST_God", "God"), function()
            IKST.dispatchCommand(p, IKST.CMD.godSelf, {})
        end, false)
        panel:makeJobButton(108, y, 90, 24, IKST.text("IGUI_IKST_Invis", "Invisible"), function()
            IKST.dispatchCommand(p, IKST.CMD.invisSelf, {})
        end, false)
        panel:makeJobButton(204, y, 90, 24, IKST.text("IGUI_IKST_Ghost", "Ghost"), function()
            IKST.dispatchCommand(p, IKST.CMD.ghostSelf, {})
        end, false)
        y = y + 32
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_TpCoords", "Teleport X,Y,Z"), UIFont.Small)
        y = y + 16
        panel.staffTpX = ISTextEntryBox:new(tostring(math.floor(p:getX())), 12, y, 70, 22)
        panel.staffTpX:initialise()
        panel.staffTpX:instantiate()
        panel:addJobWidget(panel.staffTpX)
        panel.staffTpY = ISTextEntryBox:new(tostring(math.floor(p:getY())), 88, y, 70, 22)
        panel.staffTpY:initialise()
        panel.staffTpY:instantiate()
        panel:addJobWidget(panel.staffTpY)
        panel.staffTpZ = ISTextEntryBox:new(tostring(p:getZ()), 164, y, 50, 22)
        panel.staffTpZ:initialise()
        panel.staffTpZ:instantiate()
        panel:addJobWidget(panel.staffTpZ)
        panel:makeJobButton(220, y, 80, 22, IKST.text("IGUI_IKST_Teleport", "Go"), function()
            IKST.dispatchCommand(p, IKST.CMD.tpCoords, {
                x = IKST_JobStaff.readNumber(panel.staffTpX),
                y = IKST_JobStaff.readNumber(panel.staffTpY),
                z = IKST_JobStaff.readNumber(panel.staffTpZ, 0),
            })
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
        y = y + 108
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
        local kx = 12
        for _, kit in ipairs({ "Tools", "Medical", "Food" }) do
            panel:makeJobButton(kx, y, 90, 24, kit, function()
                IKST.dispatchCommand(p, IKST.CMD.giveKit, { kit = kit })
            end, false)
            kx = kx + 96
        end
        y = y + 34

    elseif state.staffMode == "players" then
        panel:makeJobButton(12, y, 100, 24, IKST.text("IGUI_IKST_RefreshList", "Refresh"), function()
            IKST_JobStaff.requestPlayers(panel.player)
        end, false)
        y = y + 28
        local players = IKST_JobStaff.onlinePlayers or {}
        for i, pl in ipairs(players) do
            if i > 6 then
                break
            end
            local label = pl.name .. " #" .. pl.id
            panel:makeJobButton(IKST_JobLayout.MARGIN, y, panel.contentW or (panel.width - 24), 22, label, function()
                panel.staffTargetIndex = i
                panel:refreshJobUI()
            end, panel.staffTargetIndex == i)
            y = y + 24
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
            panel:makeJobButton(168, y, 72, 24, IKST.text("IGUI_IKST_God", "God"), function()
                IKST.dispatchCommand(p, IKST.CMD.godTarget, { target = target.id })
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
    end

    IKST_ActionLog.dock(panel, panel.player, y)
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
