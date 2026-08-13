if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISTextEntryBox"
require "ISUI/ISScrollingListBox"
require "IKST_Shared"
require "IKST_Utility"
require "IKST_Chrome"
require "IKST_UI_Layout"
require "IKST_Confirm"
require "IKST_Catalog"
require "IKST_JobCatalog"
require "IKST_JobLayout"
require "IKST_Vehicles"

IKST_JobVehicle = IKST_JobVehicle or {}
IKST_JobVehicle.listCache = {}
IKST_JobVehicle.backupCache = {}
IKST_JobVehicle.scriptList = nil

function IKST_JobVehicle.ensureListFilters(panel)
    if panel.vehicleListRemoteOnly == nil then
        panel.vehicleListRemoteOnly = false
    end
end

function IKST_JobVehicle.filteredList(panel)
    local list = IKST_JobVehicle.listCache or {}
    if not panel or panel.vehicleListRemoteOnly ~= true then
        return list
    end
    local minDist = IKST_Vehicles and IKST_Vehicles.remoteListMinDistance
        and IKST_Vehicles.remoteListMinDistance() or 10
    local out = {}
    for i = 1, #list do
        local v = list[i]
        local dist = tonumber(v and v.distance) or 0
        if dist > minDist then
            out[#out + 1] = v
        end
    end
    return out
end

function IKST_JobVehicle.requestBackupList(player)
    IKST.dispatchCommand(player, IKST.CMD.vehicleRelocateBackupList, {})
end

function IKST_JobVehicle.onBackupListResult(backups)
    IKST_JobVehicle.backupCache = backups or {}
end

function IKST_JobVehicle.dispatchRestore(panel, backupId, mode)
    if not panel or not panel.player or backupId == nil then
        return
    end
    local payload = {
        backupId = backupId,
        restoreMode = mode or "origin",
    }
    if mode == "here" then
        payload.x = math.floor(panel.player:getX())
        payload.y = math.floor(panel.player:getY())
        payload.z = panel.player:getZ()
    end
    IKST.dispatchCommand(panel.player, IKST.CMD.vehicleRelocateRestore, payload)
end

function IKST_JobVehicle.dispatchDelete(panel, vehicleId)
    if not vehicleId then
        IKST.notify(panel.player, IKST.text("IGUI_IKST_NoVehicle", "No vehicle selected"), false)
        return
    end
    IKST_Confirm.showDestructive(
        IKST.text("IGUI_IKST_Confirm_VehicleDelete", "Delete this vehicle?"),
        function()
            IKST.dispatchCommand(panel.player, IKST.CMD.vehicleDelete, { vehicleId = vehicleId })
            IKST_JobVehicle.requestList(panel.player)
        end
    )
end

function IKST_JobVehicle.ensurePruneCondition(panel)
    if not panel.pruneCondition then
        panel.pruneCondition = 40
    end
end

function IKST_JobVehicle.dispatchPrune(player, panel, cellScope)
    if not player then
        return
    end
    IKST_JobVehicle.ensurePruneCondition(panel)
    local args = {
        x = math.floor(player:getX()),
        y = math.floor(player:getY()),
        z = player:getZ(),
        radius = IKST.getVehicleListRadius(),
        conditionPct = panel.pruneCondition,
        burntOnly = panel.pruneBurntOnly == true,
    }
    if cellScope then
        args.cell = true
    elseif IKST_PreviewOverlay and type(IKST_PreviewOverlay.setJobRadius) == "function" then
        IKST_PreviewOverlay.setJobRadius(args.x, args.y, args.z, args.radius, "warn")
    end
    IKST.dispatchCommand(player, IKST.CMD.vehiclePrune, args)
end

function IKST_JobVehicle.confirmMassPrune(player, panel)
    IKST_Confirm.showDestructive(
        IKST.text("IGUI_IKST_Confirm_MassPrune",
            "Prune wrecked unclaimed vehicles in this map cell? Claimed and protected stay."),
        function()
            IKST_JobVehicle.dispatchPrune(player, panel, true)
        end
    )
end

function IKST_JobVehicle.buildPruneControls(panel, y)
    IKST_JobVehicle.ensurePruneCondition(panel)
    y = IKST_JobLayout.flowRow(panel, y, {
        {
            label = IKST.text("IGUI_IKST_PruneCondition", "Condition <=") .. " " .. panel.pruneCondition .. "%",
            w = 160,
            fn = function()
                panel.pruneCondition = panel.pruneCondition - 10
                if panel.pruneCondition < 0 then
                    panel.pruneCondition = 100
                end
                panel:refreshJobUI()
            end,
        },
        {
            label = IKST.text("IGUI_IKST_PruneBurnt", "Burnt only"),
            w = 110,
            primary = panel.pruneBurntOnly == true,
            fn = function()
                panel.pruneBurntOnly = not panel.pruneBurntOnly
                panel:refreshJobUI()
            end,
        },
    }, 6, 24)
    y = IKST_JobLayout.flowRow(panel, y, {
        {
            label = IKST.text("IGUI_IKST_VehicleTile_PrecisionPrune", "Precision prune"),
            w = 140,
            primary = true,
            fn = function()
                IKST_JobVehicle.dispatchPrune(panel.player, panel, false)
            end,
        },
        {
            label = IKST.text("IGUI_IKST_VehicleTile_MassPrune", "Mass prune (this cell)"),
            w = 160,
            fn = function()
                IKST_JobVehicle.confirmMassPrune(panel.player, panel)
            end,
        },
    }, 6, 24)
    return y
end

function IKST_JobVehicle.vehicleListLabel(v, showCondition)
    if showCondition then
        return v.script .. " #" .. v.id .. " (" .. v.distance .. "m, " .. tostring(v.condition or "?") .. "%)"
    end
    return v.script .. " #" .. v.id .. " (" .. v.distance .. "m)"
end

function IKST_JobVehicle.buildDeleteToolbar(panel, y)
    return IKST_JobLayout.flowRow(panel, y, {
        {
            label = IKST.text("IGUI_IKST_RefreshList", "Refresh list"),
            w = 120,
            fn = function()
                IKST_JobVehicle.requestList(panel.player)
            end,
        },
        {
            label = IKST.text("IGUI_IKST_DeleteNearest", "Delete nearest"),
            w = 130,
            primary = true,
            fn = function()
                local list = IKST_JobVehicle.listCache or {}
                local vid = panel.selectedVehicleId or (list[1] and list[1].id)
                IKST_JobVehicle.dispatchDelete(panel, vid)
            end,
        },
    }, 6, 24)
end

function IKST_JobVehicle.buildVehiclePickList(panel, y, opts)
    opts = opts or {}
    IKST_JobVehicle.ensureListFilters(panel)
    local list = IKST_JobVehicle.filteredList(panel)
    local rows = {}
    for _, v in ipairs(list) do
        rows[#rows + 1] = {
            id = v.id,
            label = IKST_JobVehicle.vehicleListLabel(v, opts.showCondition == true),
            data = v,
        }
    end
    if #rows == 0 then
        if opts.showEmpty then
            panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_VehicleListEmpty", "No vehicles nearby — Refresh list."), UIFont.Small)
            y = y + 20
        end
        return y
    end
    panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_ListFilter", "Filter"), UIFont.Small)
    y = y + 16
    local listW = panel.contentW or (panel.width - 24)
    local _, fy = IKST_JobLayout.makeFilterEntry(panel, nil, IKST_JobLayout.MARGIN, y, listW, "vehiclePickFilter", function()
        local filtered = IKST_JobLayout.filterRows(rows, panel.vehiclePickFilter)
        IKST_JobLayout.refillSelectList(panel.vehiclePickList, filtered, panel.selectedVehicleId)
    end)
    y = fy
    local visible = opts.visibleRows or 8
    local filtered = IKST_JobLayout.filterRows(rows, panel.vehiclePickFilter)
    local pickList, ly = IKST_JobLayout.makeSelectList(panel, nil, IKST_JobLayout.MARGIN, y, listW,
        IKST_JobLayout.selectListHeight(visible), filtered, {
            selectedId = panel.selectedVehicleId,
            onSelect = function(row)
                panel.selectedVehicleId = row.id
                panel:refreshJobUI(true)
            end,
        })
    panel.vehiclePickList = pickList
    y = ly + 8
    if opts.showDelete ~= false and panel.selectedVehicleId then
        y = IKST_JobLayout.flowRow(panel, y, {
            {
                label = IKST.text("IGUI_IKST_DeleteSelected", "Delete selected"),
                w = 140,
                primary = true,
                fn = function()
                    IKST_JobVehicle.dispatchDelete(panel, panel.selectedVehicleId)
                end,
            },
        }, 6, 24)
    end
    return y
end

function IKST_JobVehicle.requestList(player)
    IKST.dispatchCommand(player, IKST.CMD.vehicleList, {
        x = math.floor(player:getX()),
        y = math.floor(player:getY()),
        z = player:getZ(),
        radius = IKST.getVehicleListRadius(),
    })
end

function IKST_JobVehicle.trim(text)
    return string.gsub(tostring(text or ""), "^%s*(.-)%s*$", "%1")
end

function IKST_JobVehicle.readEntryText(entry)
    if entry and entry.getText then
        return IKST_JobVehicle.trim(entry:getText())
    end
    return ""
end

function IKST_JobVehicle.normalizeScriptName(name)
    return IKST_Catalog.normalizeFullId(name, "Base")
end

function IKST_JobVehicle.scriptExists(scriptName)
    return IKST_Catalog.vehicleScriptExists(scriptName)
end

function IKST_JobVehicle.ensureScriptList()
    if IKST_JobVehicle.scriptList then
        return IKST_JobVehicle.scriptList
    end
    local list = {}
    for _, entry in ipairs(IKST_Catalog.buildVehicleCatalog()) do
        list[#list + 1] = entry.full
    end
    IKST_JobVehicle.scriptList = list
    return list
end

function IKST_JobVehicle.getFilterText(panel)
    if panel.vehicleFilterEntry then
        return IKST_JobVehicle.readEntryText(panel.vehicleFilterEntry)
    end
    return IKST_JobVehicle.trim(panel.vehicleScriptFilter)
end

function IKST_JobVehicle.getFilteredScripts(panel)
    local list = IKST_JobVehicle.ensureScriptList()
    local filter = string.lower(IKST_JobVehicle.getFilterText(panel))
    if filter == "" then
        return list
    end
    local out = {}
    for _, name in ipairs(list) do
        if string.find(string.lower(name), filter, 1, true) then
            out[#out + 1] = name
        end
    end
    return out
end

function IKST_JobVehicle.setSelectedScript(panel, scriptName)
    panel.vehicleScriptSelected = scriptName
    panel.vehicleScriptFilter = scriptName or ""
    local filtered = IKST_JobVehicle.getFilteredScripts(panel)
    for i, name in ipairs(filtered) do
        if name == scriptName then
            panel.vehicleScriptIndex = i
            panel.vehicleScriptPage = math.max(1, math.ceil(i / 6))
            return
        end
    end
end

function IKST_JobVehicle.getScriptIndex(panel)
    local list = IKST_JobVehicle.getFilteredScripts(panel)
    if #list == 0 then
        return 1, list
    end
    if not panel.vehicleScriptIndex or panel.vehicleScriptIndex < 1 or panel.vehicleScriptIndex > #list then
        panel.vehicleScriptIndex = 1
        if panel.vehicleScriptSelected then
            for i, name in ipairs(list) do
                if name == panel.vehicleScriptSelected then
                    panel.vehicleScriptIndex = i
                    break
                end
            end
        else
            for i, name in ipairs(list) do
                if name == "Base.CarNormal" then
                    panel.vehicleScriptIndex = i
                    break
                end
            end
        end
    end
    return panel.vehicleScriptIndex, list
end

function IKST_JobVehicle.loadVehicleCatalog()
    if IKST_JobVehicle.vehicleCatalog then
        return IKST_JobVehicle.vehicleCatalog
    end
    IKST_JobVehicle.vehicleCatalog = IKST_Catalog.buildVehicleCatalog()
    return IKST_JobVehicle.vehicleCatalog
end

function IKST_JobVehicle.refreshVehicleList(panel, filter)
    if not panel.vehicleListBox then
        return
    end
    panel.vehicleListBox:clear()
    local state = IKST.getPlayerState(panel.player)
    local categoryId = state and state.vehicleCategory or IKST_Catalog.CATEGORY_ALL
    local rows, total = IKST_Catalog.filterEntries(IKST_JobVehicle.loadVehicleCatalog(), categoryId, filter)
    for _, entry in ipairs(rows) do
        local rowLabel = entry.label .. "  (" .. entry.full .. ")"
        panel.vehicleListBox:addItem(rowLabel, entry)
    end
    panel.vehicleListTotal = total
    panel.vehicleListShown = #rows
end

function IKST_JobVehicle.onListSelect(panel)
    local listBox = panel.vehicleListBox
    if listBox and listBox.selected and listBox.items[listBox.selected] then
        local entry = listBox.items[listBox.selected].item
        if entry and entry.full then
            panel.vehicleScriptSelected = entry.full
            IKST_JobVehicle.setSelectedLabel(panel, entry.full)
        end
    end
end

function IKST_JobVehicle.setSelectedLabel(panel, script)
    if not panel then
        return
    end
    local label = panel.vehicleSelectedLabel
    if not label then
        return
    end
    local text = IKST.text("IGUI_IKST_SelectedScript", "Selected") .. ": " .. IKST_JobVehicle.formatSelectedScript(script)
    label.ikstText = text
    label.ikstFont = label.ikstFont or UIFont.Small
    local w = label.width or (panel.contentW or 280)
    local wrapped = text
    if getTextManager and type(getTextManager) == "function" then
        local tm = getTextManager()
        if tm and type(tm.WrapText) == "function" then
            wrapped = tm:WrapText(label.ikstFont, text, w)
        end
    end
    label.ikstWrapped = wrapped
    label.render = function(p)
        ISPanel.render(p)
        local cc = IKST_Chrome.colors
        local ly = 0
        local lineH = 16
        local font = p.ikstFont or UIFont.Small
        for line in string.gmatch((p.ikstWrapped or "") .. "\n", "(.-)\n") do
            p:drawText(line, 0, ly, cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, font)
            ly = ly + lineH
        end
    end
end

function IKST_JobVehicle.formatSelectedScript(script)
    if not script then
        return "?"
    end
    local short = string.match(script, "%.(.+)$") or script
    local label = IKST_Catalog.vehicleDisplayName(short)
    if label ~= short then
        return label .. " (" .. script .. ")"
    end
    return script
end

function IKST_JobVehicle.getListSelection(panel)
    local listBox = panel.vehicleListBox
    if listBox and listBox.items and #listBox.items > 0 then
        local idx = listBox.selected
        if not idx or idx < 1 or idx > #listBox.items then
            idx = 1
        end
        local row = listBox.items[idx]
        if row and row.item and row.item.full then
            return row.item.full
        end
    end
    return nil
end

function IKST_JobVehicle.getSelectedScript(panel)
    if panel.vehicleScriptSelected and panel.vehicleScriptSelected ~= "" then
        return panel.vehicleScriptSelected
    end
    local fromList = IKST_JobVehicle.getListSelection(panel)
    if fromList then
        return fromList
    end
    local typed = IKST_JobVehicle.getFilterText(panel)
    if typed ~= "" then
        local normalized = IKST_JobVehicle.normalizeScriptName(typed)
        if IKST_JobVehicle.scriptExists(normalized) then
            return normalized
        end
        for _, entry in ipairs(IKST_JobVehicle.loadVehicleCatalog()) do
            if string.lower(entry.label) == string.lower(typed) or entry.full == normalized then
                return entry.full
            end
        end
    end
    local index, list = IKST_JobVehicle.getScriptIndex(panel)
    return list[index]
end

function IKST_JobVehicle.shiftScript(panel, delta)
    local index, list = IKST_JobVehicle.getScriptIndex(panel)
    panel.vehicleScriptIndex = index + delta
    if panel.vehicleScriptIndex < 1 then
        panel.vehicleScriptIndex = #list
    elseif panel.vehicleScriptIndex > #list then
        panel.vehicleScriptIndex = 1
    end
    panel.vehicleScriptSelected = list[panel.vehicleScriptIndex]
    panel.vehicleScriptFilter = panel.vehicleScriptSelected
    panel.vehicleScriptPage = math.max(1, math.ceil(panel.vehicleScriptIndex / 6))
    panel:refreshJobUI()
end

function IKST_JobVehicle.playerAngle(player)
    if player and player.getDirectionAngle then
        return player:getDirectionAngle()
    end
    return nil
end

function IKST_JobVehicle.dispatchMove(panel)
    local p = panel.player
    if not panel.selectedVehicleId then
        IKST.notify(p, IKST.text("IGUI_IKST_SelectVehicle", "Select a vehicle from the list first"), false)
        return
    end
    IKST.dispatchCommand(p, IKST.CMD.vehicleMove, {
        vehicleId = panel.selectedVehicleId,
        x = math.floor(p:getX()),
        y = math.floor(p:getY()),
        z = p:getZ(),
        angle = IKST_JobVehicle.playerAngle(p),
    })
end

function IKST_JobVehicle.onServerResult(panel, args)
    if not panel or not args or args.success ~= true then
        return
    end
    if args.mode == IKST.CMD.vehicleRelocateRestore then
        if panel.player then
            IKST_JobVehicle.requestList(panel.player)
            IKST_JobVehicle.requestBackupList(panel.player)
        end
        return
    end
    if args.mode ~= IKST.CMD.vehicleMove then
        return
    end
    if args.newVehicleId ~= nil then
        panel.selectedVehicleId = tonumber(args.newVehicleId) or args.newVehicleId
    end
    if panel.player then
        IKST_JobVehicle.requestList(panel.player)
    end
end

function IKST_JobVehicle.resolveSelectedId(panel)
    if panel.selectedVehicleId then
        return panel.selectedVehicleId
    end
    local list = IKST_JobVehicle.listCache or {}
    if list[1] then
        return list[1].id
    end
    return nil
end

local function vehicleOverviewBtn(parent, panel, x, y, w, h, label, kind, onClick)
    local btn = IKST_Chrome.newActionButton(x, y, w, h, label, panel, function()
        if onClick then
            onClick()
        end
    end, kind or "chip")
    parent:addChild(btn)
    return btn
end

local function vehicleFlowLayout(items, cardW, gap)
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

local function vehicleBuildPillSection(panel, x, y, w, icon, titleKey, titleFallback, items)
    local rowH = math.max(26, IKST_UI_Layout.s(30))
    local gap = IKST_UI_Layout.s(8)
    local rows = vehicleFlowLayout(items, w, gap)
    local headerH = IKST_Chrome.sectionHeaderH()
    local bottomPad = IKST_UI_Layout.s(14)
    local contentH = (#rows * rowH) + (math.max(0, #rows - 1) * gap)
    if #rows == 0 then
        contentH = rowH
    end
    local cardH = headerH + contentH + bottomPad
    local title = IKST.text(titleKey, titleFallback)
    local card, contentY = IKST_Chrome.newSectionCardPanel(x, y, w, cardH, icon, title)
    panel:addJobWidget(card)
    local cy = contentY
    for _, row in ipairs(rows) do
        for _, cell in ipairs(row) do
            local item = cell.item
            local kind = "chip"
            if item.danger then
                kind = "danger"
            elseif item.primary then
                kind = "primary"
            elseif item.on then
                kind = "primary"
            elseif item.outline then
                kind = "outline"
            end
            vehicleOverviewBtn(card, panel, cell.x, cy, cell.w, rowH, item.label, kind, function()
                if item.onClick then
                    item.onClick()
                end
                panel:refreshJobUI()
            end)
        end
        cy = cy + rowH + gap
    end
    return y + cardH + (IKST_JobLayout.GAP or gap)
end

-- Vehicles landing page (mockup: ikst-page-vehicles.png). Tool pills call
-- existing JobVehicle / CMD handlers.
function IKST_JobVehicle.buildOverview(panel)
    local p = panel.player
    if not p then
        return 8
    end
    if not panel._vehicleOverviewListRequested then
        panel._vehicleOverviewListRequested = true
        IKST_JobVehicle.requestList(p)
    end

    local x = panel.contentX or IKST_JobLayout.MARGIN
    local w = math.max(220, panel.contentW or (panel.width - 24))
    local y = 8
    local gap = IKST_JobLayout.GAP or IKST_UI_Layout.s(12)
    local padX = IKST_UI_Layout.s(14)
    local headerBtnH = math.max(24, IKST_UI_Layout.s(28))
    local cc = IKST_Chrome.colors
    IKST_JobVehicle.ensurePruneCondition(panel)
    IKST_JobVehicle.ensureListFilters(panel)

    local title = IKST.text("IGUI_IKST_WS_Vehicles", "Vehicles")
    local titleLabel = ISLabel:new(x, y, 26, title, 1, 1, 1, 1, UIFont.Large, true)
    titleLabel:initialise()
    panel:addJobWidget(titleLabel)

    local findLabel = IKST.text("IGUI_IKST_VehicleTile_FindNear", "Find near me")
    local findW = IKST_UI_Layout.buttonWidth(findLabel, UIFont.Small, 100)
    local remoteLabel = IKST.text("IGUI_IKST_VehicleTile_RemoteOnly", "Show remote only")
    local remoteW = IKST_UI_Layout.buttonWidth(remoteLabel, UIFont.Small, 120)
    local rightEdge = x + w
    local findX = rightEdge - findW
    local remoteX = findX - IKST_UI_Layout.s(8) - remoteW

    local remoteBtn = IKST_Chrome.newActionButton(remoteX, y, remoteW, headerBtnH, remoteLabel, panel, function()
        panel.vehicleListRemoteOnly = not (panel.vehicleListRemoteOnly == true)
        panel:refreshJobUI()
    end, panel.vehicleListRemoteOnly == true and "primary" or "chip")
    panel:addJobWidget(remoteBtn)

    local findBtn = IKST_Chrome.newActionButton(findX, y, findW, headerBtnH, findLabel, panel, function()
        IKST_JobVehicle.requestList(p)
        IKST.notify(p, IKST.text("IGUI_IKST_VehicleTile_FindDone", "Refreshing nearby vehicles…"), true)
        panel:refreshJobUI()
    end, "primary")
    panel:addJobWidget(findBtn)

    y = y + math.max(26, headerBtnH) + gap

    y = vehicleBuildPillSection(panel, x, y, w, "media/ui/ikst/ws_vehicles.png",
        "IGUI_IKST_VehicleTile_SectionTools", "Tools", {
        {
            label = IKST.text("IGUI_IKST_VehicleTile_Spawn", "Spawn vehicle"),
            primary = true,
            onClick = function()
                if panel.enterNav then
                    panel:enterNav(IKST.VIEW.vehicles, "spawn")
                end
            end,
        },
        {
            label = IKST.text("IGUI_IKST_VehicleTile_Repair", "Repair vehicle"),
            onClick = function()
                local vid = IKST_JobVehicle.resolveSelectedId(panel)
                if vid then
                    IKST.dispatchCommand(p, IKST.CMD.vehicleRepair, { vehicleId = vid })
                else
                    IKST.dispatchCommand(p, IKST.CMD.vehicleRepairNear, {})
                end
            end,
        },
        {
            label = IKST.text("IGUI_IKST_VehicleTile_Refuel", "Refuel"),
            onClick = function()
                local vid = IKST_JobVehicle.resolveSelectedId(panel)
                if vid then
                    IKST.dispatchCommand(p, IKST.CMD.vehicleRefuel, { vehicleId = vid })
                else
                    IKST.dispatchCommand(p, IKST.CMD.vehicleRefuelNear, {})
                end
            end,
        },
        {
            label = IKST.text("IGUI_IKST_VehicleMove", "Move here"),
            onClick = function()
                local vid = IKST_JobVehicle.resolveSelectedId(panel)
                if not vid then
                    IKST.notify(p, IKST.text("IGUI_IKST_NoVehicle", "No vehicle selected"), false)
                    return
                end
                panel.selectedVehicleId = vid
                IKST_JobVehicle.dispatchMove(panel)
            end,
        },
        {
            label = IKST.text("IGUI_IKST_VehicleDelete", "Remove vehicle"),
            danger = true,
            onClick = function()
                local vid = IKST_JobVehicle.resolveSelectedId(panel)
                IKST_JobVehicle.dispatchDelete(panel, vid)
            end,
        },
        {
            label = IKST.text("IGUI_IKST_VehicleTile_Snapshot", "Snapshot backup"),
            primary = true,
            onClick = function()
                if IKST_JobVehicle.requestBackupList then
                    IKST_JobVehicle.requestBackupList(p)
                end
                if panel.enterNav then
                    panel:enterNav(IKST.VIEW.vehicles, "spawn")
                end
            end,
        },
    })

    y = vehicleBuildPillSection(panel, x, y, w, "media/ui/ikst/tool_catch.png",
        "IGUI_IKST_VehicleTile_SectionPrune", "Prune", {
        {
            label = IKST.text("IGUI_IKST_PruneBurnt", "Wrecked only"),
            on = panel.pruneBurntOnly == true,
            onClick = function()
                panel.pruneBurntOnly = not (panel.pruneBurntOnly == true)
            end,
        },
        {
            label = IKST.text("IGUI_IKST_VehicleTile_UnclaimedOnly", "Unclaimed only"),
            on = true,
            onClick = function()
                IKST.notify(p, IKST.text("IGUI_IKST_VehicleTile_UnclaimedHint",
                    "Prune always skips claimed vehicles (server policy)."), true)
            end,
        },
        {
            label = IKST.text("IGUI_IKST_VehicleTile_MassPrune", "Mass prune (this cell)"),
            onClick = function()
                IKST_JobVehicle.confirmMassPrune(p, panel)
            end,
        },
        {
            label = IKST.text("IGUI_IKST_VehicleTile_PrecisionPrune", "Precision prune"),
            outline = true,
            onClick = function()
                IKST_JobVehicle.dispatchPrune(p, panel, false)
            end,
        },
    })

    local list = IKST_JobVehicle.filteredList(panel)
    local rowH = math.max(44, IKST_UI_Layout.s(48))
    local maxRows = math.min(#list, 6)
    local listRows = math.max(1, maxRows)
    local headerH = IKST_Chrome.sectionHeaderH()
    local bottomPad = IKST_UI_Layout.s(14)
    local listCardH = headerH + (listRows * (rowH + IKST_UI_Layout.s(6))) - IKST_UI_Layout.s(6) + bottomPad
    local listCard, listY = IKST_Chrome.newSectionCardPanel(x, y, w, listCardH,
        "media/ui/ikst/ws_vehicles.png",
        IKST.text("IGUI_IKST_VehicleTile_SectionNearby", "Nearby"))
    panel:addJobWidget(listCard)

    if #list == 0 then
        local empty = ISLabel:new(padX, listY + 8, 16,
            IKST.text("IGUI_IKST_VehicleListEmpty", "No vehicles nearby — Refresh list."),
            cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small, true)
        empty:initialise()
        listCard:addChild(empty)
    else
        local ry = listY
        local selectLabel = IKST.text("IGUI_IKST_VehicleTile_Select", "Select")
        local selectW = IKST_UI_Layout.buttonWidth(selectLabel, UIFont.Small, 64)
        local btnH = math.max(26, IKST_UI_Layout.s(30))
        for i, v in ipairs(list) do
            if i > 6 then
                break
            end
            local name = tostring(v.script or "?") .. " #" .. tostring(v.id or "?")
            local nameLbl = ISLabel:new(padX, ry + 4, 16, name,
                cc.textPrimary.r, cc.textPrimary.g, cc.textPrimary.b, 1, UIFont.Small, true)
            nameLbl:initialise()
            listCard:addChild(nameLbl)

            local coords = ""
            if v.x and v.y then
                coords = tostring(v.x) .. ", " .. tostring(v.y)
            elseif v.distance then
                coords = tostring(v.distance) .. "m"
            end
            local subLbl = ISLabel:new(padX, ry + 20, 14, coords,
                cc.textMuted.r, cc.textMuted.g, cc.textMuted.b, 1, UIFont.Small, true)
            subLbl:initialise()
            listCard:addChild(subLbl)

            local cond = tonumber(v.condition) or 0
            if cond < 0 then
                cond = 0
            elseif cond > 100 then
                cond = 100
            end
            local barW = math.max(60, math.floor(w * 0.22))
            local barH = math.max(8, IKST_UI_Layout.s(10))
            local barX = w - padX - selectW - IKST_UI_Layout.s(8) - barW
            local barY = ry + math.floor((rowH - barH) / 2)
            local barPanel = ISPanel:new(barX, barY, barW, barH)
            barPanel:initialise()
            barPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
            barPanel.borderColor = { r = 0, g = 0, b = 0, a = 0 }
            barPanel._cond = cond
            barPanel.render = function(bp)
                local fillW = math.floor(bp.width * (bp._cond / 100))
                bp:drawRect(0, 0, bp.width, bp.height, 0.9, cc.chipOff.r, cc.chipOff.g, cc.chipOff.b)
                if fillW > 0 then
                    bp:drawRect(0, 0, fillW, bp.height, 1, cc.accent.r, cc.accent.g, cc.accent.b)
                end
                local pct = tostring(bp._cond) .. "%"
                local tw, th = IKST_UI_Layout.textSize(pct, UIFont.Small)
                bp:drawText(pct, math.floor((bp.width - tw) / 2), math.floor((bp.height - th) / 2) - 1,
                    cc.textPrimary.r, cc.textPrimary.g, cc.textPrimary.b, 1, UIFont.Small)
            end
            listCard:addChild(barPanel)

            local selected = panel.selectedVehicleId == v.id
            vehicleOverviewBtn(listCard, panel, w - padX - selectW,
                ry + math.floor((rowH - btnH) / 2), selectW, btnH, selectLabel,
                selected and "primary" or "chip", function()
                    panel.selectedVehicleId = v.id
                    panel:refreshJobUI()
                end)
            ry = ry + rowH + IKST_UI_Layout.s(6)
        end
    end
    y = y + listCardH + gap
    return y
end

function IKST_JobVehicle.build(panel)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return
    end
    if state.navTool == "overview" or (panel.view == IKST.VIEW.vehicles and not state.navTool) then
        state.navTool = state.navTool or "overview"
        return IKST_JobVehicle.buildOverview(panel)
    end
    if not state.vehicleMode then
        state.vehicleMode = "list"
    end
    if panel.spawnRepaired == nil then
        panel.spawnRepaired = true
    end
    if panel.spawnWithKey == nil then
        panel.spawnWithKey = true
    end
    if panel.pruneBurntOnly == nil then
        panel.pruneBurntOnly = false
    end
    if not panel.vehicleScriptFilter then
        panel.vehicleScriptFilter = ""
    end
    if not panel.vehicleScriptPage then
        panel.vehicleScriptPage = 1
    end

    local y = 8
    local modes
    local navTool = state.navTool
    local vehiclesWorkspace = panel.view == IKST.VIEW.vehicles

    if vehiclesWorkspace and navTool == "spawn" then
        if state.vehicleMode ~= "list" and state.vehicleMode ~= "spawn" and state.vehicleMode ~= "delete" then
            state.vehicleMode = "list"
        end
        modes = { "list", "spawn", "delete" }
    elseif vehiclesWorkspace and navTool == "repair" then
        state.vehicleMode = "list"
        modes = nil
    elseif vehiclesWorkspace and navTool == "prune" then
        if state.vehicleMode ~= "prune" and state.vehicleMode ~= "delete" then
            state.vehicleMode = "prune"
        end
        modes = { "prune", "delete" }
    elseif panel.view == IKST.VIEW.server and state.navTool == "vehicles" then
        modes = { "list", "spawn", "claims", "cleanup" }
    else
        modes = { "spawn", "list", "extras", "prune", "delete" }
    end

    if modes then
        local x = 12
        for i, mode in ipairs(modes) do
            if i == 4 then
                x = 12
                y = y + 28
            end
            local label = IKST.text("IGUI_IKST_Vehicle_" .. mode, mode)
            panel:makeJobButton(x, y, 72, 24, label, function()
                state.vehicleMode = mode
                if mode == "list" or mode == "delete" or mode == "cleanup" then
                    IKST_JobVehicle.requestList(panel.player)
                end
                panel:refreshJobUI()
            end, state.vehicleMode == mode)
            x = x + 76
        end
        y = y + 36
    end

    local backups = IKST_JobVehicle.backupCache or {}
    if #backups > 0 and vehiclesWorkspace and navTool == "spawn" then
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_VehicleStoredBackups", "Stored vehicles (relocate backup)"), UIFont.Small)
        y = y + 18
        for i, row in ipairs(backups) do
            if i > 2 then
                break
            end
            local label = tostring(row.scriptName or "?") .. " #" .. tostring(row.backupId)
            if row.origin and row.origin.x then
                label = label .. " @ " .. tostring(row.origin.x) .. "," .. tostring(row.origin.y)
            end
            panel:makeJobLabel(12, y, label, UIFont.Small)
            y = y + 16
            panel:makeJobButton(12, y, 84, 22, IKST.text("IGUI_IKST_RestoreOrigin", "At origin"), function()
                IKST_JobVehicle.dispatchRestore(panel, row.backupId, "origin")
            end, false)
            panel:makeJobButton(100, y, 84, 22, IKST.text("IGUI_IKST_RestoreTarget", "At target"), function()
                IKST_JobVehicle.dispatchRestore(panel, row.backupId, "target")
            end, false)
            panel:makeJobButton(188, y, 84, 22, IKST.text("IGUI_IKST_RestoreHere", "Here"), function()
                IKST_JobVehicle.dispatchRestore(panel, row.backupId, "here")
            end, true)
            y = y + 26
        end
        panel:makeJobButton(12, y, 120, 22, IKST.text("IGUI_IKST_RefreshBackups", "Refresh backups"), function()
            IKST_JobVehicle.requestBackupList(panel.player)
        end, false)
        y = y + 28
    end

    if state.vehicleMode == "spawn" then
        if not state.vehicleCategory then
            state.vehicleCategory = IKST_Catalog.CATEGORY_ALL
        end
        local vehicleCatalog = IKST_JobVehicle.loadVehicleCatalog()
        local vehicleCategories = IKST_Catalog.listCategories(vehicleCatalog, IKST.text("IGUI_IKST_Catalog_All", "All"))
        y = IKST_JobCatalog.buildCategoryRow(panel, y, vehicleCategories, state.vehicleCategory, function(catId)
            state.vehicleCategory = catId
            panel:refreshJobUI()
        end)

        local selected = IKST_JobVehicle.getSelectedScript(panel) or "Base.CarNormal"

        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_VehicleScriptSearch", "Search vehicle script"), UIFont.Small)
        y = y + 16

        panel.vehicleFilterEntry = ISTextEntryBox:new(panel.vehicleScriptFilter or "", IKST_JobLayout.MARGIN, y, (panel.contentW or (panel.width - 24)) - 128, 22)
        panel.vehicleFilterEntry:initialise()
        panel.vehicleFilterEntry:instantiate()
        panel:addJobWidget(panel.vehicleFilterEntry)
        IKST_Chrome.styleInput(panel.vehicleFilterEntry, false)

        panel:makeJobButton(IKST_JobLayout.contentRight(panel) - 108, y, 108, 22, IKST.text("IGUI_IKST_RefreshList", "Refresh"), function()
            IKST_JobVehicle.scriptList = nil
            IKST_JobVehicle.vehicleCatalog = nil
            panel:refreshJobUI()
        end, false)
        y = y + 28

        local listH = math.min(160, math.max(90, math.floor((panel.scrollHeight or 160) * 0.38)))
        panel.vehicleListBox = ISScrollingListBox:new(IKST_JobLayout.MARGIN, y, panel.contentW or (panel.width - 24), listH)
        panel.vehicleListBox:initialise()
        panel.vehicleListBox:instantiate()
        panel.vehicleListBox.itemheight = 20
        panel.vehicleListBox.font = UIFont.Small
        panel.vehicleListBox.drawBorder = true
        panel:addJobWidget(panel.vehicleListBox)
        panel.vehicleListBox.onmousedown = function(target, x, y)
            if target and target.onMouseDown then
                target:onMouseDown(x, y)
            end
            -- Select without rebuilding: keeps the filtered list and highlight in place.
            IKST_JobVehicle.onListSelect(panel)
        end
        panel.vehicleFilterEntry.onTextChange = function()
            panel.vehicleScriptFilter = IKST_JobVehicle.readEntryText(panel.vehicleFilterEntry)
            IKST_JobVehicle.refreshVehicleList(panel, panel.vehicleScriptFilter)
        end
        local filterText = IKST_JobVehicle.trim(panel.vehicleScriptFilter or "")
        if panel.vehicleFilterEntry and type(panel.vehicleFilterEntry.getText) == "function" then
            local live = IKST_JobVehicle.readEntryText(panel.vehicleFilterEntry)
            if live ~= "" then
                filterText = live
            end
        end
        IKST_JobVehicle.refreshVehicleList(panel, filterText)
        -- Restore highlight on the already-selected row after a rebuild.
        if panel.vehicleScriptSelected and panel.vehicleScriptSelected ~= "" then
            for i, row in ipairs(panel.vehicleListBox.items or {}) do
                if row.item and row.item.full == panel.vehicleScriptSelected then
                    panel.vehicleListBox.selected = i
                    break
                end
            end
        end
        y = y + listH + 6
        local trunc = IKST_JobCatalog.truncationNote(panel.vehicleListShown or 0, panel.vehicleListTotal or 0)
        if trunc then
            panel:makeJobLabel(12, y, trunc, UIFont.Small)
            y = y + 16
        end

        panel.vehicleSelectedLabel = panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_SelectedScript", "Selected") .. ": " .. IKST_JobVehicle.formatSelectedScript(selected), UIFont.Small)
        IKST_JobVehicle.setSelectedLabel(panel, selected)
        y = y + 18

        panel:makeJobButton(12, y, 100, 24, IKST.text("IGUI_IKST_SpawnRepaired", "Repaired"), function()
            panel.spawnRepaired = not panel.spawnRepaired
            panel:refreshJobUI()
        end, panel.spawnRepaired == true)
        panel:makeJobButton(118, y, 90, 24, IKST.text("IGUI_IKST_SpawnKey", "With key"), function()
            panel.spawnWithKey = not panel.spawnWithKey
            panel:refreshJobUI()
        end, panel.spawnWithKey == true)
        y = y + 28

        panel:makeJobButton(12, y, 140, 24, IKST.text("IGUI_IKST_SpawnFeet", "Spawn at feet"), function()
            local p = panel.player
            local script = IKST_JobVehicle.getSelectedScript(panel)
            if not IKST_JobVehicle.scriptExists(script) then
                IKST.notify(p, IKST.text("IGUI_IKST_InvalidScript", "Unknown vehicle script"), false)
                return
            end
            IKST.dispatchCommand(p, IKST.CMD.vehicleSpawn, {
                script = script,
                x = math.floor(p:getX()),
                y = math.floor(p:getY()),
                z = p:getZ(),
                angle = IKST_JobVehicle.playerAngle(p),
                repaired = panel.spawnRepaired == true,
                withKey = panel.spawnWithKey == true,
            })
        end, true)
        panel:makeJobButton(160, y, 120, 24, IKST.text("IGUI_IKST_RepairNear", "Repair near"), function()
            IKST.dispatchCommand(p, IKST.CMD.vehicleRepairNear, {})
        end, false)
        panel:makeJobButton(286, y, 100, 24, IKST.text("IGUI_IKST_KeyNear", "Key near"), function()
            IKST.dispatchCommand(p, IKST.CMD.vehicleKeyNear, {})
        end, false)
        y = y + 34
    elseif state.vehicleMode == "claims" and IKST_JobGuard then
        y = IKST_JobGuard.buildVehicles(panel, y)
    elseif state.vehicleMode == "cleanup" then
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Vehicle_cleanup", "Cleanup"), UIFont.Small)
        y = y + 18
        y = IKST_JobVehicle.buildPruneControls(panel, y)
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_VehicleDeleteNote", "Pick a vehicle below, or delete the nearest."), UIFont.Small)
        y = y + 20
        y = IKST_JobVehicle.buildDeleteToolbar(panel, y)
        y = IKST_JobVehicle.buildVehiclePickList(panel, y, { visibleRows = 8 })
    elseif state.vehicleMode == "list" then
        panel:makeJobButton(12, y, 120, 24, IKST.text("IGUI_IKST_RefreshList", "Refresh list"), function()
            IKST_JobVehicle.requestList(panel.player)
        end, false)
        y = y + 28
        y = IKST_JobVehicle.buildVehiclePickList(panel, y, {
            showCondition = true,
            showDelete = false,
            showEmpty = true,
            visibleRows = 8,
        })
        if panel.selectedVehicleId then
            if vehiclesWorkspace and navTool == "repair" then
                panel:makeJobButton(12, y, 64, 24, IKST.text("IGUI_IKST_VehicleFlip", "Flip"), function()
                    IKST.dispatchCommand(panel.player, IKST.CMD.vehicleFlip, { vehicleId = panel.selectedVehicleId })
                end, false)
                panel:makeJobButton(82, y, 64, 24, IKST.text("IGUI_IKST_VehicleRepair", "Repair"), function()
                    IKST.dispatchCommand(panel.player, IKST.CMD.vehicleRepair, { vehicleId = panel.selectedVehicleId })
                end, true)
                panel:makeJobButton(152, y, 52, 24, IKST.text("IGUI_IKST_VehicleKey", "Key"), function()
                    IKST.dispatchCommand(panel.player, IKST.CMD.vehicleKey, { vehicleId = panel.selectedVehicleId })
                end, false)
                panel:makeJobButton(210, y, 120, 24, IKST.text("IGUI_IKST_UnlockDoors", "Unlock doors"), function()
                    IKST.dispatchCommand(panel.player, IKST.CMD.vehicleUnlockDoors, { vehicleId = panel.selectedVehicleId })
                end, false)
            else
                panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_VehicleRelocateKeysNote",
                    "Relocate keeps trunk contents and keys when possible. If keys stop working, use Give keys."), UIFont.Small)
                y = y + 18
                panel:makeJobButton(12, y, 88, 24, IKST.text("IGUI_IKST_VehicleMove", "Move here"), function()
                    IKST_JobVehicle.dispatchMove(panel)
                end, true)
                panel:makeJobButton(106, y, 58, 24, IKST.text("IGUI_IKST_VehicleFlip", "Flip"), function()
                    IKST.dispatchCommand(panel.player, IKST.CMD.vehicleFlip, { vehicleId = panel.selectedVehicleId })
                end, false)
                panel:makeJobButton(170, y, 64, 24, IKST.text("IGUI_IKST_VehicleRepair", "Repair"), function()
                    IKST.dispatchCommand(panel.player, IKST.CMD.vehicleRepair, { vehicleId = panel.selectedVehicleId })
                end, false)
                panel:makeJobButton(240, y, 52, 24, IKST.text("IGUI_IKST_VehicleKey", "Key"), function()
                    IKST.dispatchCommand(panel.player, IKST.CMD.vehicleKey, { vehicleId = panel.selectedVehicleId })
                end, false)
                if not vehiclesWorkspace or navTool == "spawn" then
                    panel:makeJobButton(298, y, 64, 24, IKST.text("IGUI_IKST_VehicleDelete", "Delete"), function()
                        IKST_JobVehicle.dispatchDelete(panel, panel.selectedVehicleId)
                    end, false)
                end
            end
            y = y + 30
        end
    elseif state.vehicleMode == "extras" then
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_VehicleExtrasNote", "Skin and unlock on selected or nearest vehicle."), UIFont.Small)
        y = y + 22
        local vid = panel.selectedVehicleId
        panel:makeJobButton(12, y, 90, 24, IKST.text("IGUI_IKST_SkinPrev", "Skin -"), function()
            IKST.dispatchCommand(panel.player, IKST.CMD.vehicleSkinPrev, { vehicleId = vid })
        end, false)
        panel:makeJobButton(108, y, 90, 24, IKST.text("IGUI_IKST_SkinNext", "Skin +"), function()
            IKST.dispatchCommand(panel.player, IKST.CMD.vehicleSkinNext, { vehicleId = vid })
        end, true)
        y = y + 28
        panel:makeJobButton(12, y, 120, 24, IKST.text("IGUI_IKST_UnlockTrunk", "Unlock trunk"), function()
            IKST.dispatchCommand(panel.player, IKST.CMD.vehicleUnlockTrunk, { vehicleId = vid })
        end, true)
        panel:makeJobButton(138, y, 120, 24, IKST.text("IGUI_IKST_UnlockDoors", "Unlock doors"), function()
            IKST.dispatchCommand(panel.player, IKST.CMD.vehicleUnlockDoors, { vehicleId = vid })
        end, false)
        y = y + 34
    elseif state.vehicleMode == "prune" then
        y = IKST_JobVehicle.buildPruneControls(panel, y)
        if vehiclesWorkspace and navTool == "prune" then
            y = IKST_JobLayout.flowRow(panel, y, {
                {
                    label = IKST.text("IGUI_IKST_UnlockDoors", "Unlock doors"),
                    w = 120,
                    fn = function()
                        IKST.dispatchCommand(panel.player, IKST.CMD.vehicleUnlockDoors, { vehicleId = panel.selectedVehicleId })
                    end,
                },
                {
                    label = IKST.text("IGUI_IKST_UnlockTrunk", "Unlock trunk"),
                    w = 120,
                    fn = function()
                        IKST.dispatchCommand(panel.player, IKST.CMD.vehicleUnlockTrunk, { vehicleId = panel.selectedVehicleId })
                    end,
                },
            }, 6, 24)
        end
    elseif state.vehicleMode == "delete" then
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_VehicleDeleteNote", "Pick a vehicle below, or delete the nearest."), UIFont.Small)
        y = y + 20
        y = IKST_JobVehicle.buildDeleteToolbar(panel, y)
        y = IKST_JobVehicle.buildVehiclePickList(panel, y, { maxItems = 8, showEmpty = true })
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_WipeCellNote", "Wipe cell removes every vehicle in this map cell."), UIFont.Small)
        y = y + 18
        if not vehiclesWorkspace or navTool == "prune" then
            y = IKST_JobLayout.flowRow(panel, y, {
                {
                    label = IKST.text("IGUI_IKST_WipeCell", "Wipe cell vehicles"),
                    w = 160,
                    fn = function()
                        IKST_Confirm.showDestructive(IKST.text("IGUI_IKST_Confirm_Wipe", "Wipe all vehicles in this cell?"), function()
                            local p = panel.player
                            IKST.dispatchCommand(p, IKST.CMD.vehicleDeleteCell, {
                                cellX = math.floor(p:getX() / 300),
                                cellY = math.floor(p:getY() / 300),
                            })
                            IKST_JobVehicle.requestList(p)
                        end)
                    end,
                },
            }, 6, 24)
        end
    end

    return y
end

function IKST_JobVehicle.onListResult(vehicles)
    IKST_JobVehicle.listCache = vehicles or {}
    if IKST_JobsPanel and IKST_JobsPanel.instance then
        IKST_JobsPanel.instance:refreshJobUI()
    end
end
