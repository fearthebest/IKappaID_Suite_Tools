if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Access"
require "IKST_Economy"

IKST_EconomyAtmKit = IKST_EconomyAtmKit or {}

function IKST_EconomyAtmKit.resolveItem(items)
    if ISInventoryPane and ISInventoryPane.getActualItems then
        local actual = ISInventoryPane.getActualItems(items)
        if actual and actual[1] then
            return actual[1]
        end
    end
    return items and items[1] or nil
end

function IKST_EconomyAtmKit.isKitItem(item)
    return item and type(item.getFullType) == "function" and item:getFullType() == IKST_Economy.ATM_KIT_TYPE
end

function IKST_EconomyAtmKit.findKitInInventory(player)
    player = IKST.resolvePlayer(player)
    if not player or not player.getInventory then
        return nil
    end
    local inv = player:getInventory()
    if not inv or not inv.getFirstTypeRecurse then
        return nil
    end
    return inv:getFirstTypeRecurse(IKST_Economy.ATM_KIT_TYPE)
end

function IKST_EconomyAtmKit.playerHasKit(player)
    return IKST_EconomyAtmKit.findKitInInventory(player) ~= nil
end

function IKST_EconomyAtmKit.placeAt(player, x, y, z, item)
    player = IKST.resolvePlayer(player)
    if not player or not IKST_Access.canUseTools(player) then
        IKST.notify(player, IKST.text("IGUI_IKST_Economy_AtmAdminOnly", "Only admins can place ATMs."), false)
        return
    end
    if not item or not IKST_EconomyAtmKit.isKitItem(item) then
        item = IKST_EconomyAtmKit.findKitInInventory(player)
    end
    IKST.dispatchCommand(player, IKST.CMD.economyAtmPlace, {
        x = math.floor(tonumber(x) or player:getX()),
        y = math.floor(tonumber(y) or player:getY()),
        z = math.floor(tonumber(z) or player:getZ()),
        itemId = item and type(item.getID) == "function" and item:getID() or nil,
    })
end

function IKST_EconomyAtmKit.armPlacePick(player, item)
    player = IKST.resolvePlayer(player)
    if not player or not item or not item.getID then
        return false
    end
    if not IKST_WorldPick then
        require "IKST_WorldPick"
    end
    if not IKST_WorldPick or not IKST_WorldPick.armCommand then
        IKST.notify(player, IKST.text("IGUI_IKST_Economy_NeedTilesPlugin", "Install IKST Tiles for cursor placement."), false)
        return false
    end
    IKST_WorldPick.armCommand(player, IKST.VIEW.economy, IKST.CMD.economyAtmPlace, {
        itemId = item:getID(),
    }, { notifyKey = "IGUI_IKST_Economy_ClickPlaceAtm" })
    return true
end

function IKST_EconomyAtmKit.onInventoryMenu(playerNum, context, items)
    if not IKST_Access.canUseTools(IKST.resolvePlayer(playerNum)) then
        return
    end
    local player = IKST.resolvePlayer(playerNum)
    if not player or not context then
        return
    end
    local item = IKST_EconomyAtmKit.resolveItem(items)
    if not IKST_EconomyAtmKit.isKitItem(item) then
        return
    end
    context:addOption(IKST.text("IGUI_IKST_Economy_PlaceAtmKit", "Place ATM at click"), player, function()
        IKST_EconomyAtmKit.armPlacePick(player, item)
    end)
end

if Events and Events.OnFillInventoryObjectContextMenu then
    Events.OnFillInventoryObjectContextMenu.Add(IKST_EconomyAtmKit.onInventoryMenu)
end
