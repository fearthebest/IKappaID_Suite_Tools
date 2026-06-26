if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Economy"
require "IKST_Access"
require "TimedActions/ISInventoryTransferAction"
require "TimedActions/ISGrabItemAction"

IKST_EconomyShopHooks = IKST_EconomyShopHooks or {}

function IKST_EconomyShopHooks.wrapTransfer()
    if IKST_EconomyShopHooks.transferWrapped or not ISInventoryTransferAction then
        return false
    end
    if not ISInventoryTransferAction.isValid then
        return false
    end
    IKST_EconomyShopHooks.transferWrapped = true
    local vanillaTransfer = ISInventoryTransferAction.isValid
    ISInventoryTransferAction.isValid = function(self)
        if self and self.item and self.srcContainer and self.destContainer and self.character then
            if IKST_Economy and IKST_Economy.vendTransferAllowed then
                if not IKST_Economy.vendTransferAllowed(self.item, self.srcContainer, self.destContainer, self.character, false) then
                    if self.stop then
                        self:stop()
                    end
                    return false
                end
            end
        end
        return vanillaTransfer(self)
    end

    if ISGrabItemAction and ISGrabItemAction.isValid then
        local vanillaGrab = ISGrabItemAction.isValid
        ISGrabItemAction.isValid = function(self)
            if self and self.item and self.character then
                local worldItem = self.item
                local item = worldItem.getItem and worldItem:getItem() or worldItem
                local src = item and item.getContainer and item:getContainer() or nil
                local dest = self.character.getInventory and self.character:getInventory() or nil
                if item and IKST_Economy and IKST_Economy.vendTransferAllowed then
                    if not IKST_Economy.vendTransferAllowed(item, src, dest, self.character, false) then
                        if self.stop then
                            self:stop()
                        end
                        return false
                    end
                end
            end
            return vanillaGrab(self)
        end
    end
    return true
end

function IKST_EconomyShopHooks.wrapDestroy()
    if IKST_EconomyShopHooks.destroyWrapped or not ISDestroyCursor then
        return false
    end
    IKST_EconomyShopHooks.destroyWrapped = true
    local vanillaCanDestroy = ISDestroyCursor.canDestroy
    if not vanillaCanDestroy then
        return false
    end
    ISDestroyCursor.canDestroy = function(self, object)
        if object and IKST_Economy and IKST_Economy.shopObjectProtected(object, self and self.character) then
            if IKST.notify then
                IKST.notify(self.character, IKST.text("IGUI_IKST_Economy_ShopDestroyBlock", "Shop terminals cannot be destroyed."), false)
            end
            return false
        end
        return vanillaCanDestroy(self, object)
    end
    return true
end

function IKST_EconomyShopHooks.wrapPickup()
    if IKST_EconomyShopHooks.pickupWrapped or not ISMoveableSpriteTool then
        return false
    end
    local vanillaPickup = ISMoveableSpriteTool.walkTo
    if not vanillaPickup then
        return false
    end
    IKST_EconomyShopHooks.pickupWrapped = true
    ISMoveableSpriteTool.walkTo = function(self, obj, ...)
        if obj and IKST_Economy and IKST_Economy.shopObjectProtected(obj, self and self.character) then
            if IKST.notify then
                IKST.notify(self.character, IKST.text("IGUI_IKST_Economy_ShopPickupBlock", "Shop terminals cannot be picked up."), false)
            end
            return false
        end
        return vanillaPickup(self, obj, ...)
    end
    return true
end

function IKST_EconomyShopHooks.init()
    IKST_EconomyShopHooks.wrapTransfer()
    IKST_EconomyShopHooks.wrapDestroy()
    IKST_EconomyShopHooks.wrapPickup()
end

if Events and Events.OnGameBoot then
    Events.OnGameBoot.Add(IKST_EconomyShopHooks.init)
end
if Events and Events.OnGameStart then
    Events.OnGameStart.Add(IKST_EconomyShopHooks.init)
end
