if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISTextEntryBox"
require "ISUI/ISScrollingListBox"
require "IKST_Shared"
require "IKST_Utility"
require "IKST_Chrome"
require "IKST_Confirm"
require "IKST_Catalog"
require "IKST_JobCatalog"
require "IKST_JobLayout"

IKST_JobVehicle = IKST_JobVehicle or {}
IKST_JobVehicle.listCache = {}
IKST_JobVehicle.scriptList = nil

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

function IKST_JobVehicle.build(panel)
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return
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
            IKST_JobVehicle.onListSelect(panel)
            panel:refreshJobUI()
        end
        panel.vehicleFilterEntry.onTextChange = function()
            IKST_JobVehicle.refreshVehicleList(panel, panel.vehicleFilterEntry:getText())
        end
        IKST_JobVehicle.refreshVehicleList(panel, panel.vehicleScriptFilter or "")
        y = y + listH + 6
        local trunc = IKST_JobCatalog.truncationNote(panel.vehicleListShown or 0, panel.vehicleListTotal or 0)
        if trunc then
            panel:makeJobLabel(12, y, trunc, UIFont.Small)
            y = y + 16
        end

        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_SelectedScript", "Selected") .. ": " .. IKST_JobVehicle.formatSelectedScript(selected), UIFont.Small)
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
        if not panel.pruneCondition then
            panel.pruneCondition = 40
        end
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_Vehicle_cleanup", "Cleanup"), UIFont.Small)
        y = y + 18
        panel:makeJobButton(12, y, 160, 24, IKST.text("IGUI_IKST_PruneCondition", "Condition <=") .. " " .. panel.pruneCondition .. "%", function()
            panel.pruneCondition = panel.pruneCondition - 10
            if panel.pruneCondition < 0 then
                panel.pruneCondition = 100
            end
            panel:refreshJobUI()
        end, false)
        panel:makeJobButton(180, y, 110, 24, IKST.text("IGUI_IKST_PruneBurnt", "Burnt only"), function()
            panel.pruneBurntOnly = not panel.pruneBurntOnly
            panel:refreshJobUI()
        end, panel.pruneBurntOnly == true)
        y = y + 28
        panel:makeJobButton(12, y, 140, 24, IKST.text("IGUI_IKST_RunPrune", "Run prune"), function()
            local pl = panel.player
            IKST.dispatchCommand(pl, IKST.CMD.vehiclePrune, {
                x = math.floor(pl:getX()),
                y = math.floor(pl:getY()),
                z = pl:getZ(),
                radius = IKST.getVehicleListRadius(),
                conditionPct = panel.pruneCondition,
                burntOnly = panel.pruneBurntOnly == true,
            })
        end, true)
        y = y + 34
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_VehicleDeleteNote", "Pick a vehicle below, or delete the nearest."), UIFont.Small)
        y = y + 20
        panel:makeJobButton(12, y, 120, 24, IKST.text("IGUI_IKST_RefreshList", "Refresh list"), function()
            IKST_JobVehicle.requestList(panel.player)
        end, false)
        panel:makeJobButton(138, y, 130, 24, IKST.text("IGUI_IKST_DeleteNearest", "Delete nearest"), function()
            local list = IKST_JobVehicle.listCache or {}
            local vid = panel.selectedVehicleId or (list[1] and list[1].id)
            IKST_JobVehicle.dispatchDelete(panel, vid)
        end, true)
        y = y + 28
        local list = IKST_JobVehicle.listCache or {}
        for i, v in ipairs(list) do
            if i > 6 then
                break
            end
            local label = v.script .. " #" .. v.id .. " (" .. v.distance .. "m)"
            panel:makeJobButton(IKST_JobLayout.MARGIN, y, panel.contentW or (panel.width - 24), 22, label, function()
                panel.selectedVehicleId = v.id
                panel:refreshJobUI()
            end, panel.selectedVehicleId == v.id)
            y = y + 24
        end
        if panel.selectedVehicleId then
            panel:makeJobButton(12, y, 140, 24, IKST.text("IGUI_IKST_DeleteSelected", "Delete selected"), function()
                IKST_JobVehicle.dispatchDelete(panel, panel.selectedVehicleId)
            end, true)
            y = y + 30
        end
    elseif state.vehicleMode == "list" then
        panel:makeJobButton(12, y, 120, 24, IKST.text("IGUI_IKST_RefreshList", "Refresh list"), function()
            IKST_JobVehicle.requestList(panel.player)
        end, false)
        y = y + 28
        local list = IKST_JobVehicle.listCache or {}
        for i, v in ipairs(list) do
            if i > 8 then
                break
            end
            local label = v.script .. " #" .. v.id .. " (" .. v.distance .. "m, " .. tostring(v.condition or "?") .. "%)"
            panel:makeJobButton(IKST_JobLayout.MARGIN, y, panel.contentW or (panel.width - 24), 22, label, function()
                panel.selectedVehicleId = v.id
                panel:refreshJobUI()
            end, panel.selectedVehicleId == v.id)
            y = y + 24
        end
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
        if not panel.pruneCondition then
            panel.pruneCondition = 40
        end
        panel:makeJobButton(12, y, 160, 24, IKST.text("IGUI_IKST_PruneCondition", "Condition <=") .. " " .. panel.pruneCondition .. "%", function()
            panel.pruneCondition = panel.pruneCondition - 10
            if panel.pruneCondition < 0 then
                panel.pruneCondition = 100
            end
            panel:refreshJobUI()
        end, false)
        panel:makeJobButton(180, y, 110, 24, IKST.text("IGUI_IKST_PruneBurnt", "Burnt only"), function()
            panel.pruneBurntOnly = not panel.pruneBurntOnly
            panel:refreshJobUI()
        end, panel.pruneBurntOnly == true)
        y = y + 28
        panel:makeJobButton(12, y, 140, 24, IKST.text("IGUI_IKST_RunPrune", "Run prune"), function()
            local p = panel.player
            IKST.dispatchCommand(p, IKST.CMD.vehiclePrune, {
                x = math.floor(p:getX()),
                y = math.floor(p:getY()),
                z = p:getZ(),
                radius = IKST.getVehicleListRadius(),
                conditionPct = panel.pruneCondition,
                burntOnly = panel.pruneBurntOnly == true,
            })
        end, true)
        y = y + 34
        if vehiclesWorkspace and navTool == "prune" then
            panel:makeJobButton(12, y, 120, 24, IKST.text("IGUI_IKST_UnlockDoors", "Unlock doors"), function()
                IKST.dispatchCommand(panel.player, IKST.CMD.vehicleUnlockDoors, { vehicleId = panel.selectedVehicleId })
            end, false)
            panel:makeJobButton(138, y, 120, 24, IKST.text("IGUI_IKST_UnlockTrunk", "Unlock trunk"), function()
                IKST.dispatchCommand(panel.player, IKST.CMD.vehicleUnlockTrunk, { vehicleId = panel.selectedVehicleId })
            end, false)
            y = y + 34
        end
    elseif state.vehicleMode == "delete" then
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_VehicleDeleteNote", "Pick a vehicle below, or delete the nearest."), UIFont.Small)
        y = y + 20
        panel:makeJobButton(12, y, 120, 24, IKST.text("IGUI_IKST_RefreshList", "Refresh list"), function()
            IKST_JobVehicle.requestList(panel.player)
        end, false)
        panel:makeJobButton(138, y, 130, 24, IKST.text("IGUI_IKST_DeleteNearest", "Delete nearest"), function()
            local list = IKST_JobVehicle.listCache or {}
            local vid = panel.selectedVehicleId or (list[1] and list[1].id)
            IKST_JobVehicle.dispatchDelete(panel, vid)
        end, true)
        y = y + 28
        local list = IKST_JobVehicle.listCache or {}
        for i, v in ipairs(list) do
            if i > 8 then
                break
            end
            local label = v.script .. " #" .. v.id .. " (" .. v.distance .. "m)"
            panel:makeJobButton(IKST_JobLayout.MARGIN, y, panel.contentW or (panel.width - 24), 22, label, function()
                panel.selectedVehicleId = v.id
                panel:refreshJobUI()
            end, panel.selectedVehicleId == v.id)
            y = y + 24
        end
        if panel.selectedVehicleId then
            panel:makeJobButton(12, y, 140, 24, IKST.text("IGUI_IKST_DeleteSelected", "Delete selected"), function()
                IKST_JobVehicle.dispatchDelete(panel, panel.selectedVehicleId)
            end, true)
            y = y + 30
        elseif #list == 0 then
            panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_VehicleListEmpty", "No vehicles nearby — Refresh list."), UIFont.Small)
            y = y + 20
        end
        panel:makeJobLabel(12, y, IKST.text("IGUI_IKST_WipeCellNote", "Wipe cell removes every vehicle in this map cell."), UIFont.Small)
        y = y + 18
        if not vehiclesWorkspace or navTool == "prune" then
            panel:makeJobButton(12, y, 160, 24, IKST.text("IGUI_IKST_WipeCell", "Wipe cell vehicles"), function()
                IKST_Confirm.showDestructive(IKST.text("IGUI_IKST_Confirm_Wipe", "Wipe all vehicles in this cell?"), function()
                    local p = panel.player
                    IKST.dispatchCommand(p, IKST.CMD.vehicleDeleteCell, {
                        cellX = math.floor(p:getX() / 300),
                        cellY = math.floor(p:getY() / 300),
                    })
                    IKST_JobVehicle.requestList(p)
                end)
            end, false)
            y = y + 34
        end
    end

    IKST_ActionLog.dock(panel, panel.player, y)
    return y
end

function IKST_JobVehicle.onListResult(vehicles)
    IKST_JobVehicle.listCache = vehicles or {}
    if IKST_JobsPanel and IKST_JobsPanel.instance then
        IKST_JobsPanel.instance:refreshJobUI()
    end
end
