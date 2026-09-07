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
require "IKappaID_UI_Framework/IKUI_Chrome"
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
    local vid = panel.selectedVehicleId
    y = IKST_JobLayout.flowRow(panel, y, {
        {
            label = IKST.text("IGUI_IKST_UnlockTrunk", "Unlock trunk"),
            w = 120,
            fn = function()
                IKST.dispatchCommand(panel.player, IKST.CMD.vehicleUnlockTrunk, { vehicleId = vid })
            end,
        },
        {
            label = IKST.text("IGUI_IKST_UnlockDoors", "Unlock doors"),
            w = 120,
            fn = function()
                IKST.dispatchCommand(panel.player, IKST.CMD.vehicleUnlockDoors, { vehicleId = vid })
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
        local cc = IKUI_Chrome.colors
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

local function vehicleNeedId(panel)
    local vid = IKST_JobVehicle.resolveSelectedId(panel)
    if not vid then
        IKST.notify(panel.player, IKST.text("IGUI_IKST_NoVehicle", "No vehicle selected"), false)
    end
    return vid
end

function IKST_JobVehicle.buildOverview(panel)
    if IKST_SoftTool_Vehicle and type(IKST_SoftTool_Vehicle.buildOverview) == "function" then
        return IKST_SoftTool_Vehicle.buildOverview(panel)
    end
    local p = panel.player
    if not p then
        return 8
    end

    local rect = IKST_JobLayout.toolContentRect(panel)
    local gap = 6
    local bands, stackBottom, soft = IKST_JobLayout.toolBands(panel, rect, 3, gap, { 1, 1, 1 })
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

    local function go(toolId)
        if panel and type(panel.enterNav) == "function" then
            panel:enterNav(IKST.VIEW.vehicles, toolId)
        end
    end

    -- Directory only — never dispatch vehicle commands from Overview.
    do
        local card, ax, ay, aw, ah = openBand(bands[1], IKST.text("IGUI_IKST_VehicleTool_Spawn", "Spawn"))
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_VehicleTile_Spawn", "Spawn vehicle"),
                primary = true,
                onClick = function()
                    go("spawn")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_VehicleMove", "Move"),
                onClick = function()
                    go("spawn")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_VehicleDelete", "Delete"),
                onClick = function()
                    go("prune")
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[2], IKST.text("IGUI_IKST_VehicleTool_Repair", "Repair"))
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_VehicleFlip", "Flip upright"),
                primary = true,
                onClick = function()
                    go("repair")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_VehicleRepair", "Repair"),
                onClick = function()
                    go("repair")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_KeyNear", "Give keys nearby"),
                onClick = function()
                    go("repair")
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[3], IKST.text("IGUI_IKST_VehicleTool_Prune", "Prune"))
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_PruneBurnt", "Burnt only"),
                primary = true,
                onClick = function()
                    go("prune")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_VehicleTile_MassPrune", "Mass prune"),
                onClick = function()
                    go("prune")
                end,
            },
            {
                label = IKST.text("IGUI_IKST_UnlockDoors", "Unlock doors"),
                onClick = function()
                    go("prune")
                end,
            },
        })
    end

    panel._ikstToolFit = true
    if soft then
        return stackBottom + gap
    end
    return rect.y + rect.h
end

function IKST_JobVehicle.buildSpawnHand(panel)
    if IKST_SoftTool_Vehicle and type(IKST_SoftTool_Vehicle.buildSpawn) == "function" then
        return IKST_SoftTool_Vehicle.buildSpawn(panel)
    end
    local p = panel.player
    if not p then
        return 8
    end
    local state = IKST.getPlayerState(p)
    if state and not state.vehicleCategory then
        state.vehicleCategory = IKST_Catalog.CATEGORY_ALL
    end
    if panel.spawnRepaired == nil then
        panel.spawnRepaired = true
    end
    if panel.spawnWithKey == nil then
        panel.spawnWithKey = true
    end
    if not panel.vehicleScriptFilter then
        panel.vehicleScriptFilter = ""
    end

    local rect = IKST_JobLayout.toolContentRect(panel)
    local gap = 6
    local bands, stackBottom, soft = IKST_JobLayout.toolBands(panel, rect, 4, gap, { 1, 200, 1, 1 })
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
        local card, ax, ay, aw, ah = openBand(bands[1], IKST.text("IGUI_IKST_VehicleScriptSearch", "Search"))
        IKST_JobLayout.placeFieldActionCorner(panel, card, ax, ay, aw, ah, {
            { text = panel.vehicleScriptFilter or "", fieldName = "vehicleFilterEntry" },
        }, IKST.text("IGUI_IKST_RefreshList", "Refresh"), function()
            panel.vehicleScriptFilter = IKST_JobVehicle.readEntryText(panel.vehicleFilterEntry)
            IKST_JobVehicle.scriptList = nil
            IKST_JobVehicle.vehicleCatalog = nil
            panel:refreshJobUI()
        end)
        if panel.vehicleFilterEntry then
            panel.vehicleFilterEntry.onTextChange = function()
                panel.vehicleScriptFilter = IKST_JobVehicle.readEntryText(panel.vehicleFilterEntry)
                IKST_JobVehicle.refreshVehicleList(panel, panel.vehicleScriptFilter)
            end
        end
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[2], IKST.text("IGUI_IKST_Catalog", "Catalog"))
        panel.vehicleListBox = ISScrollingListBox:new(ax, ay, aw, ah)
        panel.vehicleListBox:initialise()
        panel.vehicleListBox:instantiate()
        panel.vehicleListBox.itemheight = IKST_JobLayout.listItemHeight()
        panel.vehicleListBox.font = UIFont.Small
        panel.vehicleListBox.drawBorder = true
        if IKUI_Chrome and type(IKUI_Chrome.styleListBox) == "function" then
            IKUI_Chrome.styleListBox(panel.vehicleListBox)
        end
        panel.vehicleListBox.onmousedown = function(target, mx, my)
            if target and type(target.onMouseDown) == "function" then
                target:onMouseDown(mx, my)
            end
            IKST_JobVehicle.onListSelect(panel)
        end
        card:addChild(panel.vehicleListBox)
        local filterText = IKST_JobVehicle.trim(panel.vehicleScriptFilter or "")
        if panel.vehicleFilterEntry and type(panel.vehicleFilterEntry.getText) == "function" then
            local live = IKST_JobVehicle.readEntryText(panel.vehicleFilterEntry)
            if live ~= "" then
                filterText = live
            end
        end
        IKST_JobVehicle.refreshVehicleList(panel, filterText)
        if panel.vehicleScriptSelected and panel.vehicleScriptSelected ~= "" then
            for i, row in ipairs(panel.vehicleListBox.items or {}) do
                if row.item and row.item.full == panel.vehicleScriptSelected then
                    panel.vehicleListBox.selected = i
                    break
                end
            end
        end
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[3], IKST.text("IGUI_IKST_SpawnOptions", "Options"))
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_SpawnRepaired", "Repaired"),
                primary = panel.spawnRepaired == true,
                onClick = function()
                    panel.spawnRepaired = not panel.spawnRepaired
                    panel:refreshJobUI()
                end,
            },
            {
                label = IKST.text("IGUI_IKST_SpawnKey", "With key"),
                primary = panel.spawnWithKey == true,
                onClick = function()
                    panel.spawnWithKey = not panel.spawnWithKey
                    panel:refreshJobUI()
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(bands[4], IKST.text("IGUI_IKST_VehicleTile_Spawn", "Spawn"))
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_SpawnFeet", "Spawn at feet"),
                primary = true,
                onClick = function()
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
                end,
            },
            {
                label = IKST.text("IGUI_IKST_VehicleMove", "Move here"),
                onClick = function()
                    local list = IKST_JobVehicle.listCache or {}
                    local vid = panel.selectedVehicleId or (list[1] and list[1].id)
                    if not vid then
                        IKST_JobVehicle.requestList(p)
                        IKST.notify(p, IKST.text("IGUI_IKST_VehicleListEmpty", "No vehicles nearby — Refresh list."), false)
                        return
                    end
                    panel.selectedVehicleId = vid
                    IKST_JobVehicle.dispatchMove(panel)
                end,
            },
        })
    end

    panel._ikstToolFit = true
    if soft then
        return stackBottom + gap
    end
    return rect.y + rect.h
end

function IKST_JobVehicle.buildRepairHand(panel)
    if IKST_SoftTool_Vehicle and type(IKST_SoftTool_Vehicle.buildRepair) == "function" then
        return IKST_SoftTool_Vehicle.buildRepair(panel)
    end
    local p = panel.player
    if not p then
        return 8
    end
    if not panel._vehicleRepairListRequested then
        panel._vehicleRepairListRequested = true
        IKST_JobVehicle.requestList(p)
    end

    local rect = IKST_JobLayout.toolContentRect(panel)
    local inner = IKST_JobLayout.SECTION_INNER
    local padY = IKST_JobLayout.CONTENT_PAD_Y
    local btnH = IKST_JobLayout.STANDARD_BTN_H

    local function openCol(col, title)
        local card, contentY = IKST_JobLayout.placeSectionCard(panel, col.x, col.y, col.w, col.h, nil, title)
        local areaX = inner
        local areaW = math.max(40, col.w - inner * 2)
        local areaY = contentY + padY
        local areaH = math.max(btnH, col.h - contentY - padY * 2)
        return card, areaX, areaY, areaW, areaH
    end

    local function fillPick(card, ax, ay, aw, ah)
        local list = IKST_JobVehicle.filteredList(panel)
        local rows = {}
        for i = 1, #list do
            local v = list[i]
            rows[#rows + 1] = {
                id = v.id,
                label = IKST_JobVehicle.vehicleListLabel(v, true),
                data = v,
            }
        end
        if #rows == 0 then
            local empty = ISLabel:new(ax, ay, 16,
                IKST.text("IGUI_IKST_VehicleListEmpty", "No vehicles nearby — Refresh list."),
                1, 1, 1, 1, UIFont.Small, true)
            empty:initialise()
            card:addChild(empty)
        else
            IKST_JobLayout.makeSelectList(panel, card, ax, ay, aw, ah, rows, {
                selectedId = panel.selectedVehicleId,
                onSelect = function(row)
                    panel.selectedVehicleId = row.id
                    panel:refreshJobUI(true)
                end,
            })
        end
    end

    local function fillActions(card, ax, ay, aw, ah)
        IKST_JobLayout.placePillGroup(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_VehicleFlip", "Flip"),
                onClick = function()
                    local vid = vehicleNeedId(panel)
                    if vid then
                        IKST.dispatchCommand(p, IKST.CMD.vehicleFlip, { vehicleId = vid })
                    end
                end,
            },
            {
                label = IKST.text("IGUI_IKST_VehicleRepair", "Repair"),
                primary = true,
                onClick = function()
                    local vid = vehicleNeedId(panel)
                    if vid then
                        IKST.dispatchCommand(p, IKST.CMD.vehicleRepair, { vehicleId = vid })
                    end
                end,
            },
            {
                label = IKST.text("IGUI_IKST_VehicleKey", "Key"),
                onClick = function()
                    local vid = vehicleNeedId(panel)
                    if vid then
                        IKST.dispatchCommand(p, IKST.CMD.vehicleKey, { vehicleId = vid })
                    end
                end,
            },
            {
                label = IKST.text("IGUI_IKST_RepairNear", "Repair near"),
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.vehicleRepairNear, {})
                end,
            },
            {
                label = IKST.text("IGUI_IKST_KeyNear", "Key near"),
                onClick = function()
                    IKST.dispatchCommand(p, IKST.CMD.vehicleKeyNear, {})
                end,
            },
        })
    end

    -- Soft-only: pick | actions (softMasterDetail). Dock splitBands removed.
    local left, right = IKST_JobLayout.softMasterDetail(rect, 280, 12)
    do
        local card, ax, ay, aw, ah = openCol(left, IKST.text("IGUI_IKST_VehiclePick", "Pick"))
        fillPick(card, ax, ay, aw, ah)
    end
    do
        local card, ax, ay, aw, ah = openCol(right, IKST.text("IGUI_IKST_VehicleActions", "Actions"))
        fillActions(card, ax, ay, aw, ah)
    end
    panel._ikstToolFit = true
    return rect.y + rect.h
end

function IKST_JobVehicle.build(panel)
    if IKST_SoftTool_Vehicle and type(IKST_SoftTool_Vehicle.build) == "function" then
        return IKST_SoftTool_Vehicle.build(panel)
    end
    return 8
end

function IKST_JobVehicle.onListResult(vehicles)
    IKST_JobVehicle.listCache = vehicles or {}
    if IKST_Hub and type(IKST_Hub.refreshActive) == "function" then
        IKST_Hub.refreshActive()
    end
end
