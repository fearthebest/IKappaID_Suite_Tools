-- Client enforcement for inventory transfer and vehicle claims.
-- Chains vanilla timed-action isValid/perform; rules live in shared IKST_* modules.
-- Maintainer notes: docs/ENFORCEMENT.md (not shipped in Workshop tree).

if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_TransferRules"
require "IKST_VehicleClaim"
require "IKST_VehiclePermissions"

IKST_Enforcement = IKST_Enforcement or {}

function IKST_Enforcement.alreadyWrapped(classTable, key)
    if not classTable then
        return true
    end
    local flag = "IKST_enforcement_" .. key
    if classTable[flag] then
        return true
    end
    classTable[flag] = true
    return false
end

function IKST_Enforcement.notifyVehicleDenied(player)
    if not player then
        return
    end
    IKST.notify(player, IKST.text("IGUI_IKST_Claim_VehicleDenied", "This vehicle is claimed by another player."), false)
end

function IKST_Enforcement.notifySafehouseDenied(player)
    if not player then
        return
    end
    IKST.notify(player, IKST.text("IGUI_IKST_Claim_SafehouseDenied", "This safe area is claimed by another player."), false)
end

function IKST_Enforcement.transferBlocked(self)
    if not self or not self.item or not self.srcContainer or not self.destContainer or not self.character then
        return false
    end
    if not IKST_TransferRules or not IKST_TransferRules.transferAllowed then
        return false
    end
    return not IKST_TransferRules.transferAllowed(self.item, self.srcContainer, self.destContainer, self.character, false)
end

function IKST_Enforcement.grabBlocked(self)
    if not self or not self.item or not self.character then
        return false
    end
    if not IKST_TransferRules or not IKST_TransferRules.transferAllowed then
        return false
    end
    local worldItem = self.item
    local item = worldItem.getItem and worldItem:getItem() or worldItem
    if not item then
        return false
    end
    local src = item.getContainer and item:getContainer() or nil
    local dest = self.character.getInventory and self.character:getInventory() or nil
    return not IKST_TransferRules.transferAllowed(item, src, dest, self.character, false)
end

function IKST_Enforcement.vehicleForAction(self)
    if not self then
        return nil
    end
    if self.vehicle then
        return self.vehicle
    end
    if self.part and self.part.getVehicle then
        return self.part:getVehicle()
    end
    if self.character and self.character.getVehicle then
        return self.character:getVehicle()
    end
    return nil
end

function IKST_Enforcement.vehicleActionBlocked(self, action)
    if not self or not self.character or not action then
        return false
    end
    local vehicle = IKST_Enforcement.vehicleForAction(self)
    if not vehicle then
        return false
    end
    if IKST_VehicleClaim.canUseVehicle(self.character, vehicle, action) then
        return false
    end
    IKST_Enforcement.notifyVehicleDenied(self.character)
    return true
end

function IKST_Enforcement.squareForAction(self)
    if not self then
        return nil
    end
    if self.square then
        return self.square
    end
    if self.object and self.object.getSquare then
        return self.object:getSquare()
    end
    if self.character and self.character.getCurrentSquare then
        return self.character:getCurrentSquare()
    end
    return nil
end

function IKST_Enforcement.safehouseActionBlocked(self, action)
    if not self or not self.character or not action then
        return false
    end
    if not IKST_SafehouseClaim or not IKST_SafehouseClaim.canAtSquare then
        return false
    end
    if IKST_Access and IKST_Access.canUseTools and IKST_Access.canUseTools(self.character) then
        return false
    end
    local sq = IKST_Enforcement.squareForAction(self)
    if not sq then
        return false
    end
    if IKST_SafehouseClaim.canAtSquare(self.character, sq, action) == false then
        IKST_Enforcement.notifySafehouseDenied(self.character)
        return true
    end
    return false
end

function IKST_Enforcement.wrapTransfer()
    if not ISInventoryTransferAction then
        return
    end
    if ISInventoryTransferAction.isValid and not IKST_Enforcement.alreadyWrapped(ISInventoryTransferAction, "transfer_isValid") then
        local vanillaIsValid = ISInventoryTransferAction.isValid
        ISInventoryTransferAction.isValid = function(self)
            if IKST_Enforcement.transferBlocked(self) then
                if self.stop then
                    self:stop()
                end
                return false
            end
            return vanillaIsValid(self)
        end
    end
    if ISInventoryTransferAction.perform and not IKST_Enforcement.alreadyWrapped(ISInventoryTransferAction, "transfer_perform") then
        local vanillaPerform = ISInventoryTransferAction.perform
        ISInventoryTransferAction.perform = function(self)
            if IKST_Enforcement.transferBlocked(self) then
                if self.stop then
                    self:stop()
                end
                return
            end
            return vanillaPerform(self)
        end
    end
end

function IKST_Enforcement.wrapGrab()
    if not ISGrabItemAction or not ISGrabItemAction.isValid then
        return
    end
    if IKST_Enforcement.alreadyWrapped(ISGrabItemAction, "grab_isValid") then
        return
    end
    local vanillaGrab = ISGrabItemAction.isValid
    ISGrabItemAction.isValid = function(self)
        if IKST_Enforcement.grabBlocked(self) then
            if self.stop then
                self:stop()
            end
            return false
        end
        return vanillaGrab(self)
    end
end

function IKST_Enforcement.wrapVehicleIsValid(classTable, actionKey, wrapKey)
    if not classTable or not classTable.isValid then
        return
    end
    if IKST_Enforcement.alreadyWrapped(classTable, wrapKey) then
        return
    end
    local vanilla = classTable.isValid
    classTable.isValid = function(self)
        if IKST_Enforcement.vehicleActionBlocked(self, actionKey) then
            if self.stop then
                self:stop()
            end
            return false
        end
        return vanilla(self)
    end
end

function IKST_Enforcement.wrapVehicleActions()
    if not ISEnterVehicle then
        require "Vehicles/TimedActions/ISEnterVehicle"
    end
    if ISEnterVehicle then
        IKST_Enforcement.wrapVehicleIsValid(ISEnterVehicle, "enter", "ISEnterVehicle")
    end
    if not IKST_VehiclePermissions or not IKST_VehiclePermissions.TIMED_ACTION then
        return
    end
    for className, actionKey in pairs(IKST_VehiclePermissions.TIMED_ACTION) do
        local classTable = _G[className]
        if classTable and className ~= "ISEnterVehicle" then
            IKST_Enforcement.wrapVehicleIsValid(classTable, actionKey, className)
        end
    end
end

function IKST_Enforcement.wrapSafehouseBuild()
    if not IKST_SafehouseClaim then
        require "IKST_SafehouseClaim"
    end
    local buildClasses = {
        "ISBuildAction",
        "ISWoodenWall",
        "ISWoodenDoor",
        "ISWoodenStairs",
        "ISWoodenFloor",
        "ISBarricadeAction",
    }
    for _, className in ipairs(buildClasses) do
        local classTable = _G[className]
        if classTable then
            IKST_Enforcement.wrapSafehouseIsValid(classTable, "build", className .. "_build")
        end
    end
    local doorClasses = {
        "ISOpenCloseDoor",
        "ISOpenCloseWindow",
    }
    for _, className in ipairs(doorClasses) do
        local classTable = _G[className]
        if classTable then
            IKST_Enforcement.wrapSafehouseIsValid(classTable, "doors", className .. "_doors")
        end
    end
end

function IKST_Enforcement.wrapSafehouseIsValid(classTable, actionKey, wrapKey)
    if not classTable or not classTable.isValid then
        return
    end
    if IKST_Enforcement.alreadyWrapped(classTable, wrapKey) then
        return
    end
    local vanilla = classTable.isValid
    classTable.isValid = function(self)
        if IKST_Enforcement.safehouseActionBlocked(self, actionKey) then
            if self.stop then
                self:stop()
            end
            return false
        end
        return vanilla(self)
    end
end

function IKST_Enforcement.init()
    if type(isClient) == "function" and not isClient() then
        return
    end
    if not ISInventoryTransferAction then
        require "TimedActions/ISInventoryTransferAction"
    end
    if not ISGrabItemAction then
        require "TimedActions/ISGrabItemAction"
    end
    IKST_Enforcement.wrapTransfer()
    IKST_Enforcement.wrapGrab()
    IKST_Enforcement.wrapVehicleActions()
    IKST_Enforcement.wrapSafehouseBuild()
end

if Events and Events.OnGameBoot then
    Events.OnGameBoot.Add(IKST_Enforcement.init)
end
if Events and Events.OnGameStart then
    Events.OnGameStart.Add(IKST_Enforcement.init)
end
