-- Server-side vehicle snapshot for admin relocate (serialize → despawn → respawn → apply).
-- Standalone IKST implementation; not shared with other mods.

require "IKST_Shared"

IKST_VehicleSnapshot = IKST_VehicleSnapshot or {}
local VS = IKST_VehicleSnapshot

VS.SCHEMA_VERSION = 1

local function call0(obj, method, default)
    if not obj or not method then
        return default
    end
    if type(obj[method]) ~= "function" then
        return default
    end
    local value = obj[method](obj)
    if value == nil then
        return default
    end
    return value
end

local function listSize(list)
    if not list then
        return 0
    end
    if type(list) == "table" then
        return #list
    end
    return list:size()
end

local function listGet(list, index)
    if not list or index == nil then
        return nil
    end
    if type(list) == "table" then
        return list[index + 1]
    end
    return list:get(index)
end

function VS.createItem(fullType)
    if not fullType or fullType == "" or not instanceItem then
        return nil
    end
    return instanceItem(fullType)
end

local function captureItem(item)
    if not item then
        return nil
    end
    local fullType = call0(item, "getFullType", nil)
    if not fullType or fullType == "" then
        return nil
    end
    return {
        fullType = tostring(fullType),
        condition = call0(item, "getCondition", nil),
        usedDelta = call0(item, "getUsedDelta", nil),
    }
end

local function captureContainer(part)
    if not part then
        return nil
    end
    local container = call0(part, "getItemContainer", nil)
    if not container then
        return nil
    end
    local items = call0(container, "getItems", nil)
    if not items then
        return {}
    end
    local out = {}
    local count = listSize(items)
    for i = 0, count - 1 do
        local rec = captureItem(listGet(items, i))
        if rec then
            out[#out + 1] = rec
        end
    end
    return out
end

local function readScriptName(vehicle)
    if not vehicle then
        return ""
    end
    local script = call0(vehicle, "getScript", nil)
    if script and type(script.getName) == "function" then
        local name = script:getName()
        if name and name ~= "" then
            return tostring(name)
        end
    end
    local direct = call0(vehicle, "getScriptName", nil)
    if direct and direct ~= "" then
        return tostring(direct)
    end
    return ""
end

local function readColor(vehicle)
    if not vehicle or type(vehicle.getColorHue) ~= "function" then
        return nil
    end
    return {
        h = vehicle:getColorHue(),
        s = vehicle.getColorSaturation and vehicle:getColorSaturation() or nil,
        v = vehicle.getColorValue and vehicle:getColorValue() or nil,
    }
end

local function copyPrimitiveModData(source, dest)
    if type(source) ~= "table" or type(dest) ~= "table" then
        return
    end
    for key, value in pairs(source) do
        local t = type(value)
        if t == "string" or t == "number" or t == "boolean" then
            dest[key] = value
        end
    end
end

function VS.capture(vehicle)
    if not vehicle then
        return nil
    end
    local snap = {
        schemaVersion = VS.SCHEMA_VERSION,
        scriptName = readScriptName(vehicle),
        skinIndex = call0(vehicle, "getSkinIndex", -1),
        rust = call0(vehicle, "getRust", nil),
        engineQuality = call0(vehicle, "getEngineQuality", nil),
        enginePower = call0(vehicle, "getEnginePower", nil),
        engineLoudness = call0(vehicle, "getEngineLoudness", nil),
        hotwired = call0(vehicle, "isHotwired", nil),
        color = readColor(vehicle),
        parts = {},
        modData = {},
    }
    if not snap.enginePower and type(vehicle.getScript) == "function" then
        local script = vehicle:getScript()
        if script and type(script.getEngineForce) == "function" then
            snap.enginePower = script:getEngineForce()
        end
    end
    if not snap.engineLoudness and type(vehicle.getScript) == "function" then
        local script = vehicle:getScript()
        if script and type(script.getEngineLoudness) == "function" then
            snap.engineLoudness = script:getEngineLoudness()
        end
    end
    local partCount = call0(vehicle, "getPartCount", 0) or 0
    for i = 0, partCount - 1 do
        local part = vehicle.getPartByIndex and vehicle:getPartByIndex(i) or nil
        if part then
            local partId = call0(part, "getId", nil)
            if partId and partId ~= "" then
                local content = nil
                if part.isContainer and part:isContainer() and type(part.getContainerContentAmount) == "function" then
                    content = part:getContainerContentAmount()
                end
                snap.parts[#snap.parts + 1] = {
                    id = tostring(partId),
                    condition = call0(part, "getCondition", nil),
                    item = captureItem(call0(part, "getInventoryItem", nil)),
                    container = captureContainer(part),
                    content = content,
                }
            end
        end
    end
    if vehicle.getModData then
        copyPrimitiveModData(vehicle:getModData(), snap.modData)
    end
    return snap
end

local function transmitPart(vehicle, part, kind)
    if not vehicle or not part then
        return
    end
    local methodByKind = {
        item = "transmitPartItem",
        condition = "transmitPartCondition",
        modData = "transmitPartModData",
        usedDelta = "transmitPartUsedDelta",
    }
    local method = methodByKind[kind]
    if method and type(vehicle[method]) == "function" then
        vehicle[method](vehicle, part)
    end
end

local function callPartHook(vehicle, part, hookName)
    if not vehicle or not part or not hookName or type(part.getTable) ~= "function" then
        return
    end
    local tbl = part:getTable(hookName)
    if tbl and tbl.complete and VehicleUtils and type(VehicleUtils.callLua) == "function" then
        VehicleUtils.callLua(tbl.complete, vehicle, part)
    end
end

local function restoreContainerItems(container, items)
    if not container or type(items) ~= "table" then
        return
    end
    if container.removeAllItems then
        container:removeAllItems()
    end
    for _, itemRec in ipairs(items) do
        local item = VS.createItem(itemRec.fullType)
        if item then
            if itemRec.condition ~= nil and item.setCondition then
                item:setCondition(itemRec.condition)
            end
            if itemRec.usedDelta ~= nil and item.setUsedDelta then
                item:setUsedDelta(itemRec.usedDelta)
            end
            if container.AddItem then
                container:AddItem(item)
                if sendAddItemToContainer then
                    sendAddItemToContainer(container, item)
                end
            end
        end
    end
end

function VS.apply(vehicle, snap)
    if not vehicle or type(snap) ~= "table" then
        return false
    end
    if snap.skinIndex ~= nil and snap.skinIndex >= 0 and vehicle.setSkinIndex then
        vehicle:setSkinIndex(snap.skinIndex)
    end
    if snap.rust ~= nil and vehicle.setRust then
        vehicle:setRust(snap.rust)
    end
    if snap.engineQuality ~= nil and snap.enginePower ~= nil and vehicle.setEngineFeature then
        vehicle:setEngineFeature(snap.engineQuality or 0, snap.engineLoudness or 0, snap.enginePower or 0)
        if vehicle.transmitEngine then
            vehicle:transmitEngine()
        end
    end
    if snap.color and snap.color.h ~= nil and vehicle.setColorHSV then
        vehicle:setColorHSV(snap.color.h, snap.color.s or 0.5, snap.color.v or 0.5)
        if vehicle.transmitColorHSV then
            vehicle:transmitColorHSV()
        end
    end
    if snap.hotwired ~= nil and vehicle.setHotwired then
        vehicle:setHotwired(snap.hotwired == true)
    end
    if type(snap.parts) == "table" then
        for _, rec in ipairs(snap.parts) do
            local part = vehicle.getPartById and vehicle:getPartById(rec.id) or nil
            if part then
                if rec.condition ~= nil and part.setCondition then
                    part:setCondition(rec.condition)
                    transmitPart(vehicle, part, "condition")
                end
                if rec.item and rec.item.fullType then
                    local newItem = VS.createItem(rec.item.fullType)
                    if newItem and part.setInventoryItem then
                        if rec.item.condition ~= nil and newItem.setCondition then
                            newItem:setCondition(rec.item.condition)
                        end
                        if rec.item.usedDelta ~= nil and newItem.setUsedDelta then
                            newItem:setUsedDelta(rec.item.usedDelta)
                        end
                        if part.getInventoryItem and part:getInventoryItem() then
                            part:setInventoryItem(nil)
                            transmitPart(vehicle, part, "item")
                        end
                        part:setInventoryItem(newItem)
                        callPartHook(vehicle, part, "install")
                        transmitPart(vehicle, part, "item")
                        if rec.item.usedDelta ~= nil then
                            transmitPart(vehicle, part, "usedDelta")
                        end
                    end
                elseif part.getInventoryItem and part.setInventoryItem and part:getInventoryItem() then
                    part:setInventoryItem(nil)
                    callPartHook(vehicle, part, "uninstall")
                    transmitPart(vehicle, part, "item")
                end
                if rec.content ~= nil and part.setContainerContentAmount then
                    part:setContainerContentAmount(rec.content)
                    local wheelIndex = part.getWheelIndex and part:getWheelIndex() or -1
                    if wheelIndex ~= -1 and vehicle.setTireInflation
                        and part.getContainerCapacity and part.getContainerContentAmount
                        and part:getContainerCapacity() > 0 then
                        vehicle:setTireInflation(wheelIndex, part:getContainerContentAmount() / part:getContainerCapacity())
                    end
                end
                if type(rec.container) == "table" then
                    restoreContainerItems(call0(part, "getItemContainer", nil), rec.container)
                end
                transmitPart(vehicle, part, "modData")
            end
        end
    end
    if vehicle.getModData and type(snap.modData) == "table" then
        copyPrimitiveModData(snap.modData, vehicle:getModData())
    end
    if vehicle.transmitModData then
        vehicle:transmitModData()
    end
    return true
end
