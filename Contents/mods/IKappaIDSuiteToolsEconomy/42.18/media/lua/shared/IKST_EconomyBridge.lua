require "IKST_Shared"
require "IKST_Identity"

IKST_EconomyBridge = IKST_EconomyBridge or {}

local function formatAmount(amount)
    if IKST_Economy and IKST_Economy.formatAmount then
        return IKST_Economy.formatAmount(amount)
    end
    return tostring(math.floor(tonumber(amount) or 0))
end

local function virtualBanking()
    return IKST_Economy and IKST_Economy.idCardBanking and IKST_Economy.idCardBanking() == true
end

function IKST_EconomyBridge.hasCashProvider()
    if virtualBanking() then
        return IKST_Economy and IKST_Economy.getBank ~= nil
    end
    if not PhoneShop then
        return false
    end
    if PhoneShop.getCashOnly and PhoneShop.payCashOnly and PhoneShop.giveCashOnly then
        return true
    end
    return PhoneShop.getMoney ~= nil
        and PhoneShop.canAfford ~= nil
        and PhoneShop.pay ~= nil
        and PhoneShop.give ~= nil
end

function IKST_EconomyBridge.isAvailable()
    return IKST_EconomyBridge.hasCashProvider()
end

function IKST_EconomyBridge.isEconomyRuling()
    if not IKST_Economy or not IKST_Economy.isEconomyActive then
        return false
    end
    return IKST_Economy.isEconomyActive() == true
end

function IKST_EconomyBridge.getCash(player)
    if virtualBanking() then
        return 0
    end
    if not IKST_EconomyBridge.hasCashProvider() then
        return 0
    end
    player = IKST.resolvePlayer(player)
    if not player then
        return 0
    end
    if PhoneShop.getCashOnly then
        return PhoneShop.getCashOnly(player) or 0
    end
    return PhoneShop.getMoney(player) or 0
end

function IKST_EconomyBridge.getBank(player)
    if not IKST_Economy or not IKST_Economy.getBank then
        return 0
    end
    player = IKST.resolvePlayer(player)
    if not player then
        return 0
    end
    return IKST_Economy.getBank(player) or 0
end

function IKST_EconomyBridge.getBalance(player)
    if virtualBanking() then
        return IKST_EconomyBridge.getBank(player)
    end
    return IKST_EconomyBridge.getCash(player) + IKST_EconomyBridge.getBank(player)
end

function IKST_EconomyBridge.canAfford(player, amount)
    return IKST_EconomyBridge.getBalance(player) >= IKST.parseAmount(amount)
end

function IKST_EconomyBridge.payCash(player, amount)
    if virtualBanking() then
        player = IKST.resolvePlayer(player)
        amount = IKST.parseAmount(amount)
        if not player or amount <= 0 or not IKST_Economy.takeBank then
            return false, "invalid amount"
        end
        if IKST_Economy.takeBank(player, amount) then
            return true, nil
        end
        return false, "not enough in bank"
    end
    if not IKST_EconomyBridge.hasCashProvider() then
        return false, "PhoneShop not loaded"
    end
    player = IKST.resolvePlayer(player)
    amount = IKST.parseAmount(amount)
    if not player or amount <= 0 then
        return false, "invalid amount"
    end
    if IKST_EconomyBridge.getCash(player) < amount then
        return false, "not enough cash"
    end
    if PhoneShop.payCashOnly and PhoneShop.payCashOnly(player, amount) then
        return true, nil
    end
    if PhoneShop.pay and (not PhoneShop.economyRules or not PhoneShop.economyRules()) and PhoneShop.pay(player, amount) then
        return true, nil
    end
    return false, "payment failed"
end

function IKST_EconomyBridge.pay(player, amount)
    player = IKST.resolvePlayer(player)
    amount = IKST.parseAmount(amount)
    if not player or amount <= 0 then
        return false, "invalid amount"
    end
    if virtualBanking() then
        if IKST_Economy.takeBank(player, amount) then
            return true, nil
        end
        return false, "not enough in bank"
    end
    local cash = IKST_EconomyBridge.getCash(player)
    if cash >= amount then
        return IKST_EconomyBridge.payCash(player, amount)
    end
    if not IKST_Economy or not IKST_Economy.takeBank then
        return IKST_EconomyBridge.payCash(player, amount)
    end
    local fromBank = amount - cash
    if cash > 0 then
        local okCash = IKST_EconomyBridge.payCash(player, cash)
        if not okCash then
            return false, "payment failed"
        end
    end
    if IKST_Economy.takeBank(player, fromBank) then
        return true, nil
    end
    if cash > 0 then
        IKST_EconomyBridge.giveCash(player, cash)
    end
    return false, "not enough money"
end

function IKST_EconomyBridge.giveCash(player, amount)
    if virtualBanking() then
        player = IKST.resolvePlayer(player)
        amount = IKST.parseAmount(amount)
        if not player or amount <= 0 or not IKST_Economy.addBank then
            return false, "invalid amount"
        end
        IKST_Economy.addBank(player, amount)
        return true, "Credited " .. formatAmount(amount)
    end
    if not IKST_EconomyBridge.hasCashProvider() then
        return false, "PhoneShop not loaded"
    end
    player = IKST.resolvePlayer(player)
    amount = IKST.parseAmount(amount)
    if not player or amount <= 0 then
        return false, "invalid amount"
    end
    if PhoneShop.giveCashOnly and PhoneShop.giveCashOnly(player, amount) then
        return true, "Gave " .. formatAmount(amount) .. " cash"
    end
    if PhoneShop.give and PhoneShop.give(player, amount) then
        return true, "Gave " .. formatAmount(amount) .. " cash"
    end
    return false, "payment failed"
end

function IKST_EconomyBridge.giveMoney(player, amount)
    return IKST_EconomyBridge.giveCash(player, amount)
end

function IKST_EconomyBridge.giveBank(player, amount)
    player = IKST.resolvePlayer(player)
    amount = IKST.parseAmount(amount)
    if not player or amount <= 0 or not IKST_Economy then
        return false, "invalid"
    end
    IKST_Economy.addBank(player, amount)
    return true, "Credited bank " .. formatAmount(amount)
end

function IKST_EconomyBridge.refund(player, amount)
    return IKST_EconomyBridge.giveCash(player, amount)
end
