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
    if IKST_EconomyShopHooks.transferWrapped then
        return true
    end
    if not ISInventoryTransferAction then
        return false
    end
    if type(ISInventoryTransferAction.isValid) ~= "function" then
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

    if ISGrabItemAction and type(ISGrabItemAction.isValid) == "function" then
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
    if IKST_EconomyShopHooks.destroyWrapped then
        return true
    end
    if not ISDestroyCursor then
        return false
    end
    local vanillaCanDestroy = ISDestroyCursor.canDestroy
    if type(vanillaCanDestroy) ~= "function" then
        return false
    end
    IKST_EconomyShopHooks.destroyWrapped = true
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
    if IKST_EconomyShopHooks.pickupWrapped then
        return true
    end
    if not ISMoveableSpriteTool then
        return false
    end
    local vanillaPickup = ISMoveableSpriteTool.walkTo
    if type(vanillaPickup) ~= "function" then
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

-- B42.20: ISDestroyCursor may not exist at boot on clients. Retry wrap without requiring server paths.
local shopHookRetries = 0
local function retryShopHooks()
    if IKST_EconomyShopHooks.destroyWrapped and IKST_EconomyShopHooks.pickupWrapped and IKST_EconomyShopHooks.transferWrapped then
        if Events and Events.OnTick then
            Events.OnTick.Remove(retryShopHooks)
        end
        return
    end
    shopHookRetries = shopHookRetries + 1
    if shopHookRetries % 30 ~= 0 then
        return
    end
    IKST_EconomyShopHooks.init()
    if shopHookRetries > 1200 then
        if Events and Events.OnTick then
            Events.OnTick.Remove(retryShopHooks)
        end
    end
end

if Events and Events.OnGameBoot then
    Events.OnGameBoot.Add(IKST_EconomyShopHooks.init)
end
if Events and Events.OnGameStart then
    Events.OnGameStart.Add(IKST_EconomyShopHooks.init)
    Events.OnGameStart.Add(function()
        if Events and Events.OnTick and not IKST_EconomyShopHooks.destroyWrapped then
            Events.OnTick.Add(retryShopHooks)
        end
    end)
end
