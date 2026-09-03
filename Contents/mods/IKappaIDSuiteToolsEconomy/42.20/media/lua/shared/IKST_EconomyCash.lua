-- Physical cash helpers — Base.Money in inventory and wallet containers.
require "IKST_Shared"

IKST_EconomyCash = IKST_EconomyCash or {}

local CASH_TYPES = {
    ["Base.Money"] = 1,
    ["Base.MoneyBundle"] = 100,
}

local WALLET_NAME_MARKERS = {
    "Wallet",
}

function IKST_EconomyCash.cashItemTypes()
    return CASH_TYPES
end

function IKST_EconomyCash.isWalletContainer(item)
    if not item or type(item.getType) ~= "function" then
        return false
    end
    local t = item:getType()
    if not t or t == "" then
        return false
    end
    for i = 1, #WALLET_NAME_MARKERS do
        if string.find(t, WALLET_NAME_MARKERS[i], 1, true) then
            return true
        end
    end
    return false
end

function IKST_EconomyCash.itemCashValue(item)
    if not item or type(item.getFullType) ~= "function" then
        return 0
    end
    local mult = CASH_TYPES[item:getFullType()]
    if not mult then
        return 0
    end
    local count = 1
    if type(item.getCount) == "function" then
        count = tonumber(item:getCount()) or 1
    end
    return mult * count
end

function IKST_EconomyCash.sumContainer(inv, walletOnly, inWallet)
    if not inv or type(inv.getItems) ~= "function" then
        return 0
    end
    local items = inv:getItems()
    if not items or type(items.size) ~= "function" then
        return 0
    end
    local total = 0
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            local value = IKST_EconomyCash.itemCashValue(item)
            if value > 0 then
                if walletOnly then
                    if inWallet then
                        total = total + value
                    end
                else
                    total = total + value
                end
            elseif IKST_EconomyCash.isWalletContainer(item) and type(item.getInventory) == "function" then
                local inner = item:getInventory()
                if inner then
                    total = total + IKST_EconomyCash.sumContainer(inner, walletOnly, true)
                end
            end
        end
    end
    return total
end

function IKST_EconomyCash.countPhysicalCash(player, walletOnly)
    player = IKST.resolvePlayer(player)
    if not player or type(player.getInventory) ~= "function" then
        return 0
    end
    local inv = player:getInventory()
    if not inv then
        return 0
    end
    if walletOnly then
        return IKST_EconomyCash.sumContainer(inv, true, false)
    end
    return IKST_EconomyCash.sumContainer(inv, false, false)
end

function IKST_EconomyCash.playerHasWallet(player)
    player = IKST.resolvePlayer(player)
    if not player or type(player.getInventory) ~= "function" then
        return false
    end
    local inv = player:getInventory()
    if not inv or type(inv.getItems) ~= "function" then
        return false
    end
    local items = inv:getItems()
    if not items or type(items.size) ~= "function" then
        return false
    end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if IKST_EconomyCash.isWalletContainer(item) then
            return true
        end
    end
    return false
end
