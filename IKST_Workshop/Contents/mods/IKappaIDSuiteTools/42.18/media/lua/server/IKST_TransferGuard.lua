if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_TransferRules"

IKST_TransferGuard = IKST_TransferGuard or {}

local function transferBlocked(self)
    if not self or not self.item or not self.srcContainer or not self.destContainer or not self.character then
        return false
    end
    if not IKST_TransferRules or not IKST_TransferRules.transferAllowed then
        return false
    end
    return not IKST_TransferRules.transferAllowed(self.item, self.srcContainer, self.destContainer, self.character, true)
end

local function grabBlocked(self)
    if not self or not self.item or not self.character then
        return false
    end
    if not IKST_TransferRules or not IKST_TransferRules.transferAllowed then
        return false
    end
    local worldItem = self.item
    local item = worldItem.getItem and worldItem:getItem() or worldItem
    local src = item and item.getContainer and item:getContainer() or nil
    local dest = self.character.getInventory and self.character:getInventory() or nil
    if not item then
        return false
    end
    return not IKST_TransferRules.transferAllowed(item, src, dest, self.character, true)
end

function IKST_TransferGuard.wrapTransfer()
    if IKST_TransferGuard.transferWrapped or not ISInventoryTransferAction then
        return false
    end
    if not ISInventoryTransferAction.isValid then
        return false
    end
    IKST_TransferGuard.transferWrapped = true
    local vanillaTransfer = ISInventoryTransferAction.isValid
    ISInventoryTransferAction.isValid = function(self)
        if transferBlocked(self) then
            if self.stop then
                self:stop()
            end
            return false
        end
        return vanillaTransfer(self)
    end
    return true
end

function IKST_TransferGuard.wrapTransferPerform()
    if IKST_TransferGuard.performWrapped or not ISInventoryTransferAction then
        return false
    end
    if not ISInventoryTransferAction.perform then
        return false
    end
    IKST_TransferGuard.performWrapped = true
    local vanillaPerform = ISInventoryTransferAction.perform
    ISInventoryTransferAction.perform = function(self)
        if transferBlocked(self) then
            if self.stop then
                self:stop()
            end
            return
        end
        return vanillaPerform(self)
    end
    return true
end

function IKST_TransferGuard.wrapGrab()
    if IKST_TransferGuard.grabWrapped or not ISGrabItemAction then
        return false
    end
    if not ISGrabItemAction.isValid then
        return false
    end
    IKST_TransferGuard.grabWrapped = true
    local vanillaGrab = ISGrabItemAction.isValid
    ISGrabItemAction.isValid = function(self)
        if grabBlocked(self) then
            if self.stop then
                self:stop()
            end
            return false
        end
        return vanillaGrab(self)
    end
    return true
end

function IKST_TransferGuard.init()
    if not ISInventoryTransferAction then
        require "TimedActions/ISInventoryTransferAction"
    end
    if not ISGrabItemAction then
        require "TimedActions/ISGrabItemAction"
    end
    IKST_TransferGuard.wrapTransfer()
    IKST_TransferGuard.wrapTransferPerform()
    IKST_TransferGuard.wrapGrab()
end

if Events and Events.OnGameBoot then
    Events.OnGameBoot.Add(IKST_TransferGuard.init)
end
if Events and Events.OnGameStart then
    Events.OnGameStart.Add(IKST_TransferGuard.init)
end
