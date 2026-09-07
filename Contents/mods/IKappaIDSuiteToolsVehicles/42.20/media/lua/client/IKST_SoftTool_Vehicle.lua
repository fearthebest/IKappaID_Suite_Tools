-- SoftTool Vehicle: soft-shell Vehicles workspace painted via IKUI_SoftBody.
-- List / spawn / prune helpers stay on IKST_JobVehicle.
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISLabel"
require "ISUI/ISScrollingListBox"
require "IKST_Shared"
require "IKappaID_UI_Framework/IKUI_SoftBody"
require "IKappaID_UI_Framework/IKUI_Chrome"
require "IKST_JobLayout"
require "IKST_JobVehicle"
require "IKST_Catalog"
require "IKST_Confirm"

IKST_SoftTool_Vehicle = IKST_SoftTool_Vehicle or {}

local function openBand(panel, rect, band, title)
    local inner = IKUI_SoftBody.SECTION_INNER
    local padY = 8
    local btnH = IKUI_SoftBody.STANDARD_BTN_H
    local card, contentY = IKUI_SoftBody.section(panel, rect.x, band.y, rect.w, band.h, title)
    return card, inner, contentY + padY, math.max(40, rect.w - inner * 2), math.max(btnH, band.h - contentY - padY * 2)
end

local function openCol(panel, col, title)
    local inner = IKUI_SoftBody.SECTION_INNER
    local padY = 8
    local btnH = IKUI_SoftBody.STANDARD_BTN_H
    local card, contentY = IKUI_SoftBody.section(panel, col.x, col.y, col.w, col.h, title)
    return card, inner, contentY + padY, math.max(40, col.w - inner * 2), math.max(btnH, col.h - contentY - padY * 2)
end

local function vehicleNeedId(panel)
    local vid = IKST_JobVehicle.resolveSelectedId(panel)
    if not vid then
        IKST.notify(panel.player, IKST.text("IGUI_IKST_NoVehicle", "No vehicle selected"), false)
    end
    return vid
end

function IKST_SoftTool_Vehicle.buildOverview(panel)
    local p = panel.player
    if not p then
        return 8
    end
    local rect = IKUI_SoftBody.contentRect(panel)
    local gap = IKUI_SoftBody.BTN_GAP
    local bands, stackBottom = IKUI_SoftBody.stack(rect.y, gap, { 1, 1, 1 })

    local function go(toolId)
        if panel and type(panel.enterNav) == "function" then
            panel:enterNav(IKST.VIEW.vehicles, toolId)
        end
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[1], IKST.text("IGUI_IKST_VehicleTool_Spawn", "Spawn"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
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
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[2], IKST.text("IGUI_IKST_VehicleTool_Repair", "Repair"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
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
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[3], IKST.text("IGUI_IKST_VehicleTool_Prune", "Prune"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
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

    return stackBottom + gap
end

function IKST_SoftTool_Vehicle.buildSpawn(panel)
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

    local rect = IKUI_SoftBody.contentRect(panel)
    local gap = IKUI_SoftBody.BTN_GAP
    local searchH = IKUI_SoftBody.fieldActionBandH(1)
    local optionsH = IKUI_SoftBody.compactPillBandH(1)
    local spawnH = IKUI_SoftBody.compactPillBandH(1)
    local catalogH = math.max(80, rect.h - searchH - gap - optionsH - gap - spawnH - gap)
    local bands = {
        { y = rect.y, h = searchH },
        { y = rect.y + searchH + gap, h = catalogH },
        { y = rect.y + searchH + gap + catalogH + gap, h = optionsH },
        { y = rect.y + searchH + gap + catalogH + gap + optionsH + gap, h = spawnH },
    }
    local stackBottom = bands[4].y + bands[4].h

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[1], IKST.text("IGUI_IKST_VehicleScriptSearch", "Search"))
        IKUI_SoftBody.fieldAction(panel, card, ax, ay, aw, ah, {
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
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[2], IKST.text("IGUI_IKST_Catalog", "Catalog"))
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
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[3], IKST.text("IGUI_IKST_SpawnOptions", "Options"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
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
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[4], IKST.text("IGUI_IKST_VehicleTile_Spawn", "Spawn"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
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

    return stackBottom + gap
end

function IKST_SoftTool_Vehicle.buildRepair(panel)
    local p = panel.player
    if not p then
        return 8
    end
    if not panel._vehicleRepairListRequested then
        panel._vehicleRepairListRequested = true
        IKST_JobVehicle.requestList(p)
    end

    local rect = IKUI_SoftBody.contentRect(panel)
    local left, right = IKUI_SoftBody.masterDetail(rect, 280, 12)

    do
        local card, ax, ay, aw, ah = openCol(panel, left, IKST.text("IGUI_IKST_VehiclePick", "Pick"))
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

    do
        local card, ax, ay, aw, ah = openCol(panel, right, IKST.text("IGUI_IKST_VehicleActions", "Actions"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
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

    return rect.y + rect.h
end

function IKST_SoftTool_Vehicle.buildPrune(panel)
    local p = panel.player
    if not p then
        return 8
    end
    IKST_JobVehicle.ensurePruneCondition(panel)
    if panel.pruneBurntOnly == nil then
        panel.pruneBurntOnly = false
    end
    if not panel._vehiclePruneListRequested then
        panel._vehiclePruneListRequested = true
        IKST_JobVehicle.requestList(p)
    end

    local rect = IKUI_SoftBody.contentRect(panel)
    local gap = IKUI_SoftBody.BTN_GAP
    local btnH = IKUI_SoftBody.STANDARD_BTN_H
    local pruneH = IKUI_SoftBody.compactPillBandH(2)
    local actionsH = IKUI_SoftBody.compactPillBandH(2)
    local pickH = math.max(80, rect.h - pruneH - gap - actionsH - gap)
    local bands = {
        { y = rect.y, h = pruneH },
        { y = rect.y + pruneH + gap, h = pickH },
        { y = rect.y + pruneH + gap + pickH + gap, h = actionsH },
    }
    local stackBottom = bands[3].y + bands[3].h

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[1], IKST.text("IGUI_IKST_VehicleTool_Prune", "Prune"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_PruneBurnt", "Burnt only"),
                primary = panel.pruneBurntOnly == true,
                onClick = function()
                    panel.pruneBurntOnly = not panel.pruneBurntOnly
                    panel:refreshJobUI()
                end,
            },
            {
                label = IKST.text("IGUI_IKST_PruneCondition", "Condition") .. " " .. tostring(panel.pruneCondition or 40) .. "%",
                onClick = function()
                    local presets = { 20, 40, 60, 80 }
                    local cur = panel.pruneCondition or 40
                    local idx = 1
                    for i, val in ipairs(presets) do
                        if val == cur then
                            idx = i
                            break
                        end
                    end
                    panel.pruneCondition = presets[(idx % #presets) + 1]
                    panel:refreshJobUI()
                end,
            },
            {
                label = IKST.text("IGUI_IKST_PruneRadius", "Prune nearby"),
                primary = true,
                onClick = function()
                    IKST_JobVehicle.dispatchPrune(p, panel, false)
                end,
            },
            {
                label = IKST.text("IGUI_IKST_VehicleTile_MassPrune", "Mass prune cell"),
                onClick = function()
                    IKST_JobVehicle.confirmMassPrune(p, panel)
                end,
            },
        })
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[2], IKST.text("IGUI_IKST_VehiclePick", "Pick"))
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
            local listH, pillH, gapLP = IKUI_SoftBody.listPillSplit(ah, 1)
            IKST_JobLayout.makeSelectList(panel, card, ax, ay, aw, listH, rows, {
                selectedId = panel.selectedVehicleId,
                onSelect = function(row)
                    panel.selectedVehicleId = row.id
                    panel:refreshJobUI(true)
                end,
            })
            local pillY = ay + listH + gapLP
            local pillH2 = math.max(btnH, pillH)
            IKUI_SoftBody.pillRow(panel, card, ax, pillY, aw, pillH2, {
                {
                    label = IKST.text("IGUI_IKST_RefreshList", "Refresh"),
                    onClick = function()
                        IKST_JobVehicle.requestList(p)
                    end,
                },
                {
                    label = IKST.text("IGUI_IKST_VehicleDelete", "Delete"),
                    onClick = function()
                        IKST_JobVehicle.dispatchDelete(panel, panel.selectedVehicleId)
                    end,
                },
            })
        end
    end

    do
        local card, ax, ay, aw, ah = openBand(panel, rect, bands[3], IKST.text("IGUI_IKST_WipeCell", "Cell"))
        IKUI_SoftBody.pillRow(panel, card, ax, ay, aw, ah, {
            {
                label = IKST.text("IGUI_IKST_WipeCell", "Wipe cell vehicles"),
                onClick = function()
                    IKST_Confirm.showDestructive(IKST.text("IGUI_IKST_Confirm_Wipe", "Wipe all vehicles in this cell?"), function()
                        IKST.dispatchCommand(p, IKST.CMD.vehicleDeleteCell, {
                            cellX = math.floor(p:getX() / 300),
                            cellY = math.floor(p:getY() / 300),
                        })
                        IKST_JobVehicle.requestList(p)
                    end)
                end,
            },
        })
    end

    return stackBottom + gap
end

function IKST_SoftTool_Vehicle.build(panel)
    if not panel then
        return 8
    end
    local state = IKST.getPlayerState(panel.player)
    if not state then
        return 8
    end
    local tool = state.navTool or "overview"
    local bottomY
    if tool == "spawn" then
        bottomY = IKST_SoftTool_Vehicle.buildSpawn(panel)
    elseif tool == "repair" then
        bottomY = IKST_SoftTool_Vehicle.buildRepair(panel)
    elseif tool == "prune" then
        bottomY = IKST_SoftTool_Vehicle.buildPrune(panel)
    else
        bottomY = IKST_SoftTool_Vehicle.buildOverview(panel)
    end
    return bottomY
end
