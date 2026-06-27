if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Access"
require "IKST_Economy"
require "IKST_EconomyIcons"

IKST_EconomyShopKit = IKST_EconomyShopKit or {}

function IKST_EconomyShopKit.resolveItem(items)
    if ISInventoryPane and ISInventoryPane.getActualItems then
        local actual = ISInventoryPane.getActualItems(items)
        if actual and actual[1] then
            return actual[1]
        end
    end
    return items and items[1] or nil
end

function IKST_EconomyShopKit.isKitItem(item)
    return item and item.getFullType and item:getFullType() == IKST_Economy.SHOP_KIT_TYPE
end

function IKST_EconomyShopKit.findKitInInventory(player)
    player = IKST.resolvePlayer(player)
    if not player or not player.getInventory then
        return nil
    end
    local inv = player:getInventory()
    if not inv or not inv.getFirstTypeRecurse then
        return nil
    end
    return inv:getFirstTypeRecurse(IKST_Economy.SHOP_KIT_TYPE)
end

function IKST_EconomyShopKit.playerHasKit(player)
    return IKST_EconomyShopKit.findKitInInventory(player) ~= nil
end

function IKST_EconomyShopKit.placeAt(player, x, y, z, item)
    player = IKST.resolvePlayer(player)
    if not player or not IKST_Access.canUseEconomy(player) then
        return
    end
    if not item or not IKST_EconomyShopKit.isKitItem(item) then
        item = IKST_EconomyShopKit.findKitInInventory(player)
    end
    if not item or not item.getID then
        IKST.notify(player, IKST.text("IGUI_IKST_Economy_ShopKitMissing", "You need a Player Shop Terminal Kit."), false)
        return
    end
    IKST.dispatchCommand(player, IKST.CMD.economyShopPlace, {
        x = math.floor(tonumber(x) or player:getX()),
        y = math.floor(tonumber(y) or player:getY()),
        z = math.floor(tonumber(z) or player:getZ()),
        itemId = item:getID(),
    })
end

function IKST_EconomyShopKit.onInventoryMenu(playerNum, context, items)
    if not IKST_Economy.isEnabled() then
        return
    end
    local player = IKST.resolvePlayer(playerNum)
    if not player or not context or not IKST_Access.canUseEconomy(player) then
        return
    end
    local item = IKST_EconomyShopKit.resolveItem(items)
    if not IKST_EconomyShopKit.isKitItem(item) then
        return
    end
    local opt = context:addOption(IKST.text("IGUI_IKST_Economy_PlaceShopKit", "Place shop terminal here"), player, function()
        local sq = player.getCurrentSquare and player:getCurrentSquare()
        if not sq then
            IKST.notify(player, IKST.text("IGUI_IKST_Economy_ShopKitNoSquare", "Stand on a clear tile to place the shop."), false)
            return
        end
        IKST_EconomyShopKit.placeAt(player, sq:getX(), sq:getY(), sq:getZ(), item)
    end)
    if IKST_EconomyIcons then
        IKST_EconomyIcons.applyContextIcon(opt, IKST_EconomyIcons.SHOP)
    end
end

if Events and Events.OnFillInventoryObjectContextMenu then
    Events.OnFillInventoryObjectContextMenu.Add(IKST_EconomyShopKit.onInventoryMenu)
end
