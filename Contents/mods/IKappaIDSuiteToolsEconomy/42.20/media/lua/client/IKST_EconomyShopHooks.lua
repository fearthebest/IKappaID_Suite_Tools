if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Economy"
require "IKST_Access"

IKST_EconomyShopHooks = IKST_EconomyShopHooks or {}

-- Transfer/grab: IKST_TransferRules via IKST_Enforcement (base mod).

function IKST_EconomyShopHooks.wrapDestroy()
    if IKST_EconomyShopHooks.destroyWrapped then
        return true
    end
    if not ISDestroyCursor then
        return false
    end
    if type(ISDestroyCursor.canDestroy) ~= "function" then
        return false
    end
    IKST_EconomyShopHooks.destroyWrapped = true
    local vanillaCanDestroy = ISDestroyCursor.canDestroy
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
    if type(ISMoveableSpriteTool.walkTo) ~= "function" then
        return false
    end
    IKST_EconomyShopHooks.pickupWrapped = true
    local vanillaPickup = ISMoveableSpriteTool.walkTo
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
    IKST_EconomyShopHooks.wrapDestroy()
    IKST_EconomyShopHooks.wrapPickup()
end

local shopHookRetries = 0
local function retryShopHooks()
    if IKST_EconomyShopHooks.destroyWrapped and IKST_EconomyShopHooks.pickupWrapped then
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
