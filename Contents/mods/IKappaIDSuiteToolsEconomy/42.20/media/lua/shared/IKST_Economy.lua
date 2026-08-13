-- IKST player economy (bank, wire, vending, valuables) — uses PhoneShop physical cash when loaded.

require "IKST_Shared"
require "IKST_Authority"
require "IKST_Identity"
require "IKST_EconomyIdentity"
require "IKST_EconomyBridge"
require "IKST_Grid"
require "IKST_Access"

IKST_Economy = IKST_Economy or {}
IKST_Economy.STORE_KEY = "IKST_Economy"
IKST_Economy.VEND_TAG = "IKST_vend"
IKST_Economy.VEND_OWNER = "IKST_vendOwner"
IKST_Economy.VEND_PRICE = "IKST_vendPrice"
IKST_Economy.VEND_PRICES = "IKST_vendPrices"
IKST_Economy.VEND_PROTECT = "IKST_vendProtect"
IKST_Economy.ATM_TAG = "IKST_atm"
IKST_Economy.ATM_PLACER = "IKST_atmPlacer"
IKST_Economy.ATM_KIT_TYPE = "IKST.AtmTerminalKit"
IKST_Economy.SHOP_TERMINAL_TAG = "IKST_shopTerminal"
IKST_Economy.SHOP_PLACER = "IKST_shopPlacer"
IKST_Economy.SHOP_KIT_TYPE = "IKST.ShopTerminalKit"
-- Vanilla vending tiles are 20 encumbrance; B42 engine caps world-container setCapacity at 100.
IKST_Economy.SHOP_CAPACITY_ENGINE_MAX = 100
IKST_Economy.SHOP_CAPACITY_DEFAULT = 100
IKST_Economy.SHOP_CONTAINER_UPGRADED = "IKST_shopContainerUpgraded"
-- Vanilla world fixtures only (B42: shop accessories vending + bank ATM props).
-- These sprites are decorative in vanilla — IKST adds economy via modData / coord config.
IKST_Economy.SHOP_TERMINAL_SPRITE = "ikst_economy_01_4"
IKST_Economy.SHOP_TERMINAL_SIGN = "location_shop_generic_01_70"
IKST_Economy.SHOP_SIGN_TAG = "IKST_shopSign"
-- vendingsnack/vendingpop cap setCapacity at 100; IKST shops use fridge (100 cap, slows food spoilage).
IKST_Economy.SHOP_CONTAINER_TYPE = "fridge"
IKST_Economy.SHOP_TERMINAL_SPRITE_FALLBACKS = {
    "ikst_economy_01_5",
    "ikst_economy_01_6",
    "ikst_economy_01_7",
    "location_shop_accessories_01_16",
    "location_shop_accessories_01_17",
    "location_shop_accessories_01_18",
    "location_shop_accessories_01_19",
    "location_shop_accessories_01_28",
    "location_shop_accessories_01_29",
}
IKST_Economy.ATM_TERMINAL_SPRITE = "ikst_economy_01_0"
IKST_Economy.ATM_TERMINAL_SPRITE_FALLBACKS = {
    "ikst_economy_01_1",
    "ikst_economy_01_2",
    "ikst_economy_01_3",
}
IKST_Economy.ATM_VANILLA_SPRITES = {
    "location_business_bank_01_64",
    "location_business_bank_01_65",
    "location_business_bank_01_68",
    "location_business_bank_01_69",
    "location_business_bank_01_70",
    "location_business_bank_01_71",
}
IKST_Economy.HISTORY_MAX = 12

require "IKST_EconomyTiles"

function IKST_Economy.shopTilesRequired()
    return IKST_Economy.sandboxBool("EconomyShopTilesOnly", true)
end

function IKST_Economy.shopProtectEnabled()
    return IKST_Economy.sandboxBool("EconomyShopProtect", true)
end

function IKST_Economy.vendObjectForContainer(container)
    return IKST_Economy.shopObjectForContainer(container)
end

function IKST_Economy.vendTransferAllowed(item, srcContainer, destContainer, player, quiet)
    if not IKST_Economy.shopProtectEnabled() or not player then
        return true
    end
    if IKST_Access and IKST_Access.canUseTools and IKST_Access.canUseTools(player) then
        return true
    end
    local function deny(stocking)
        if not quiet and IKST.notify then
            local key = stocking and "IGUI_IKST_Economy_ShopStockBlock" or "IGUI_IKST_Economy_ShopLootBlock"
            local fallback = stocking and "Only the shop owner can stock this terminal."
                or "Buy from the shop UI — direct loot is blocked."
            IKST.notify(player, IKST.text(key, fallback), false)
        end
        return false
    end
    local function checkVend(vendObj, stocking)
        if not vendObj or not IKST_Economy.isProtectedShopObject(vendObj) then
            return true
        end
        if IKST_Economy.playerMayManageShopStock(vendObj, player) then
            return true
        end
        if stocking and IKST_Economy.shopOwnerStockOnly() then
            return deny(true)
        end
        return deny(stocking)
    end
    if not checkVend(IKST_Economy.shopObjectForContainer(srcContainer), false) then
        return false
    end
    if not checkVend(IKST_Economy.shopObjectForContainer(destContainer), true) then
        return false
    end
    return true
end

function IKST_Economy.shopObjectProtected(obj, player)
    if not IKST_Economy.shopProtectEnabled() then
        return false
    end
    if player and IKST_Access and IKST_Access.canUseTools and IKST_Access.canUseTools(player) then
        return false
    end
    return IKST_Economy.isProtectedShopObject(obj)
end

function IKST_Economy.getShopPriceTable(shopMd)
    if not shopMd then
        return nil
    end
    local catalog = shopMd[IKST_Economy.VEND_PRICES]
    if type(catalog) ~= "table" then
        catalog = {}
        shopMd[IKST_Economy.VEND_PRICES] = catalog
    end
    return catalog
end

function IKST_Economy.catalogPrice(shopMd, itemType)
    if not shopMd or not itemType then
        return 0
    end
    local catalog = IKST_Economy.getShopPriceTable(shopMd)
    return math.floor(tonumber(catalog[itemType]) or 0)
end

function IKST_Economy.effectiveVendPrice(shopMd, item)
    if not item or not item.getFullType then
        return 0
    end
    if item.getModData then
        local md = item:getModData()
        local perItem = math.floor(tonumber(md and md[IKST_Economy.VEND_PRICE]) or 0)
        if perItem > 0 then
            return perItem
        end
    end
    return IKST_Economy.catalogPrice(shopMd, item:getFullType())
end

function IKST_Economy.itemCount(item)
    if item and item.getCount then
        local n = tonumber(item:getCount()) or 1
        if n < 1 then
            n = 1
        end
        return math.floor(n)
    end
    return 1
end

function IKST_Economy.countPlayerItems(player, itemType)
    player = IKST.resolvePlayer(player)
    if not player or not itemType or itemType == "" then
        return 0
    end
    local inv = type(player.getInventory) == "function" and player:getInventory() or nil
    if not inv then
        return 0
    end
    local n = 0
    local items = nil
    if type(inv.getItemsFromFullType) == "function" then
        items = inv:getItemsFromFullType(itemType, true)
    elseif type(inv.getItemsFromType) == "function" then
        items = inv:getItemsFromType(itemType, true)
    elseif type(inv.getItemsFromTypeRecurse) == "function" then
        items = inv:getItemsFromTypeRecurse(itemType, true)
    end
    if items and items.size then
        for i = 0, items:size() - 1 do
            n = n + IKST_Economy.itemCount(items:get(i))
        end
        return n
    end
    if type(inv.getItems) == "function" then
        items = inv:getItems()
        if items then
            for i = 0, items:size() - 1 do
                local item = items:get(i)
                if item and type(item.getFullType) == "function" and item:getFullType() == itemType then
                    n = n + IKST_Economy.itemCount(item)
                end
            end
        end
    end
    return n
end

function IKST_Economy.isPerishableItem(item)
    if not item then
        return false
    end
    if instanceof and instanceof(item, "Food") then
        return true
    end
    if item.getOffAge then
        local offAge = tonumber(item:getOffAge()) or 0
        if offAge > 0 then
            return true
        end
    end
    return false
end

function IKST_Economy.canSellInShop(item)
    if not item then
        return false
    end
    if instanceof and instanceof(item, "Food") and type(item.isRotten) == "function" and item:isRotten() then
        return false
    end
    return true
end

function IKST_Economy.freshnessSuffix(item)
    if not item or not IKST_Economy.isPerishableItem(item) then
        return ""
    end
    if instanceof and instanceof(item, "Food") and type(item.isRotten) == "function" and item:isRotten() then
        return " (" .. IKST.text("IGUI_IKST_Economy_FreshRotten", "rotten") .. ")"
    end
    if instanceof and instanceof(item, "Food") and type(item.isFresh) == "function" and item:isFresh() then
        return " (" .. IKST.text("IGUI_IKST_Economy_FreshGood", "fresh") .. ")"
    end
    if item.getAge and item.getOffAge then
        local age = tonumber(item:getAge()) or 0
        local offAge = tonumber(item:getOffAge()) or 0
        if offAge > 0 and age >= offAge * 0.5 then
            return " (" .. IKST.text("IGUI_IKST_Economy_FreshAging", "aging") .. ")"
        end
    end
    return ""
end

function IKST_Economy.vendListGroupKey(item, itemType)
    if IKST_Economy.isPerishableItem(item) and item.getID then
        return itemType .. ":" .. tostring(item:getID())
    end
    return itemType
end

function IKST_Economy.sandboxPage()
    if SandboxVars and SandboxVars.IKappaIDSuiteToolsEconomy then
        return SandboxVars.IKappaIDSuiteToolsEconomy
    end
    return SandboxVars and SandboxVars.IKappaIDSuiteTools
end

function IKST_Economy.legacySandboxPage()
    return SandboxVars and SandboxVars.IKappaIDSuiteTools
end

function IKST_Economy.isEconomyActive()
    if not IKST.isModEnabled() then
        return false
    end
    local sv = IKST_Economy.sandboxPage()
    if sv and sv.EconomyEnabled == false then
        return false
    end
    return IKST_EconomyBridge.hasCashProvider()
end

function IKST_Economy.isEnabled()
    return IKST_Economy.isEconomyActive()
end

function IKST_Economy.sandboxBool(key, default)
    local sv = IKST_Economy.sandboxPage()
    local v = sv and sv[key]
    if v == nil then
        local leg = IKST_Economy.legacySandboxPage()
        v = leg and leg[key]
    end
    if v == nil then
        return default
    end
    return v == true
end

function IKST_Economy.sandboxString(key, default, maxLen)
    local sv = IKST_Economy.sandboxPage()
    local name = sv and sv[key]
    if name == nil then
        local leg = IKST_Economy.legacySandboxPage()
        name = leg and leg[key]
    end
    if type(name) ~= "string" then
        name = default or ""
    end
    name = string.gsub(name, "^%s*(.-)%s*$", "%1")
    if name == "" then
        name = default or ""
    end
    maxLen = tonumber(maxLen) or 32
    if #name > maxLen then
        name = name:sub(1, maxLen)
    end
    return name
end

function IKST_Economy.currencyName()
    return IKST_Economy.sandboxString("EconomyCurrencyName", "Credits", 32)
end

function IKST_Economy.formatAmount(amount)
    amount = math.floor(tonumber(amount) or 0)
    return tostring(amount) .. " " .. IKST_Economy.currencyName()
end

function IKST_Economy.zombieBountyEnabled()
    if not IKST_Economy.isEnabled() then
        return false
    end
    return IKST_Economy.sandboxBool("EconomyZombieBounty", false)
end

function IKST_Economy.zombieBountyChance()
    return IKST_Economy.sandboxInt("EconomyZombieBountyChance", 15, 0, 100)
end

function IKST_Economy.zombieBountyMin()
    return IKST_Economy.sandboxInt("EconomyZombieBountyMin", 1, 0, 999999)
end

function IKST_Economy.zombieBountyMax()
    return IKST_Economy.sandboxInt("EconomyZombieBountyMax", 10, 0, 999999)
end

function IKST_Economy.sandboxInt(key, default, minVal, maxVal)
    local sv = IKST_Economy.sandboxPage()
    local v = sv and sv[key]
    if v == nil then
        local leg = IKST_Economy.legacySandboxPage()
        v = leg and leg[key]
    end
    v = tonumber(v)
    if not v then
        v = default
    end
    if minVal and v < minVal then
        v = minVal
    end
    if maxVal and v > maxVal then
        v = maxVal
    end
    return math.floor(v)
end

function IKST_Economy.wireMaxDistance()
    return IKST_Economy.sandboxInt("EconomyWireDistance", 5, 1, 30)
end

function IKST_Economy.wireMinAmount()
    return IKST_Economy.sandboxInt("EconomyMinWireAmount", 1, 0, 999999)
end

function IKST_Economy.wireFeePercent()
    return IKST_Economy.sandboxInt("EconomyWireFeePercent", 0, 0, 50)
end

function IKST_Economy.shopOwnerStockOnly()
    return IKST_Economy.sandboxBool("EconomyShopOwnerStockOnly", false)
end

function IKST_Economy.shopMaxDistance()
    return IKST_Economy.sandboxInt("EconomyShopDistance", 4, 1, 20)
end

function IKST_Economy.shopContainerCapacity()
    local cap = IKST_Economy.sandboxInt("EconomyShopCapacity", IKST_Economy.SHOP_CAPACITY_DEFAULT, 20, 500)
    local maxCap = IKST_Economy.SHOP_CAPACITY_ENGINE_MAX or 100
    if cap > maxCap then
        cap = maxCap
    end
    return cap
end

function IKST_Economy.salesTaxPercent()
    return IKST_Economy.sandboxInt("EconomySalesTax", 5, 0, 50)
end

function IKST_Economy.taxReceiverKey()
    local name = IKST_Economy.sandboxString("EconomyTaxReceiver", "", 64)
    if name == "" then
        return nil
    end
    if IKST_Identity.isAccountKey(name) then
        return name
    end
    return IKST_Identity.keyForLegacyName(name)
end

function IKST_Economy.taxReceiver()
    return IKST_Economy.taxReceiverKey()
end

function IKST_Economy.atmRequiredForBank()
    return IKST_Economy.sandboxBool("EconomyAtmRequired", false)
end

function IKST_Economy.valuablesEnabled()
    if IKST_Economy.sandboxBool("EconomyValuables", true) == false then
        return false
    end
    return true
end

function IKST_Economy.maxVendPrice()
    return IKST_Economy.sandboxInt("EconomyMaxVendPrice", 100000, 1, 9999999)
end

function IKST_Economy.maxVendSelectedIds()
    return 200
end

function IKST_Economy.idCardBanking()
    return IKST_Economy.sandboxBool("EconomyIdCardBanking", true)
end

function IKST_Economy.idCardPlayerReissue()
    return IKST_Economy.sandboxBool("EconomyIdCardPlayerReissue", true)
end

function IKST_Economy.idCardReissueFee()
    return IKST_Economy.sandboxInt("EconomyIdCardReissueFee", 100, 0, 999999)
end

function IKST_Economy.idCardReissueCooldownHours()
    return IKST_Economy.sandboxInt("EconomyIdCardReissueCooldownHours", 72, 0, 720)
end

function IKST_Economy.idCardReissueCooldownRemainMs(player)
    if not player or not IKST_Identity or not IKST_Economy.getAccountByKey then
        return 0
    end
    local hours = IKST_Economy.idCardReissueCooldownHours()
    if hours <= 0 then
        return 0
    end
    local row = IKST_Economy.getAccountByKey(IKST_Economy.accountKey(player))
    local lastMs = tonumber(row.lastCardReissueMs) or 0
    if lastMs <= 0 or not getTimeInMillis then
        return 0
    end
    local remain = (hours * 3600000) - (getTimeInMillis() - lastMs)
    if remain < 0 then
        return 0
    end
    return remain
end

function IKST_Economy.zombieBountyToBank()
    if IKST_Economy.idCardBanking() then
        return true
    end
    return IKST_Economy.sandboxBool("EconomyZombieBountyToBank", false)
end

function IKST_Economy.accountKey(player)
    if IKST_Identity and IKST_Identity.accountKey then
        return IKST_Identity.accountKey(player)
    end
    return IKST_Economy.accountName(player)
end

function IKST_Economy.accountName(player)
    return IKST_Economy.accountKey(player)
end

function IKST_Economy.legacyAccountName(player)
    if not player then
        return "local"
    end
    if player.getUsername then
        local u = player:getUsername()
        if u and u ~= "" then
            return u
        end
    end
    return "local"
end

function IKST_Economy.getStore()
    if not ModData or not ModData.getOrCreate then
        return nil
    end
    local store = ModData.getOrCreate(IKST_Economy.STORE_KEY)
    if not store.accounts then
        store.accounts = {}
    end
    if not store.atms then
        store.atms = {}
    end
    if not store.taxPool then
        store.taxPool = 0
    end
    return store
end

function IKST_Economy.mayMutateStore()
    if IKST_Authority and IKST_Authority.guardServerMutate then
        return IKST_Authority.guardServerMutate()
    end
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        return true
    end
    return IKST.runsOnServerJvm and IKST.runsOnServerJvm()
end

function IKST_Economy.persistStore()
    if not IKST_Economy.mayMutateStore() then
        return
    end
    if not ModData or type(ModData.getOrCreate) ~= "function" then
        return
    end
    local store = ModData.getOrCreate(IKST_Economy.STORE_KEY)
    if not store then
        return
    end
    if type(ModData.add) == "function" then
        ModData.add(IKST_Economy.STORE_KEY, store)
    end
    -- Do not ModData.transmit the full account store (SECURITY: balances stay server-side).
    -- Dedicated world save keeps getOrCreate tables. Clients get per-player snapshots only.
end

function IKST_Economy.cacheClientBalances(player, bank, pending)
    if not player or not player.getModData then
        return
    end
    local md = player:getModData()
    md.IKST_bank_cache = math.floor(tonumber(bank) or 0)
    md.IKST_pending_cache = math.floor(tonumber(pending) or 0)
end

function IKST_Economy.readClientBank(player)
    if not player or not player.getModData then
        return 0
    end
    local md = player:getModData()
    return math.floor(tonumber(md.IKST_bank_cache) or 0)
end

function IKST_Economy.readClientPending(player)
    if not player or not player.getModData then
        return 0
    end
    local md = player:getModData()
    return math.floor(tonumber(md.IKST_pending_cache) or 0)
end

function IKST_Economy.usesClientSnapshot()
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        return false
    end
    if type(isClient) ~= "function" or not isClient() then
        return false
    end
    return (IKST.isRemoteClient and IKST.isRemoteClient())
        or (IKST.isListenHostClient and IKST.isListenHostClient())
end

function IKST_Economy.isMpRemoteClient()
    return IKST_Economy.usesClientSnapshot()
end

function IKST_Economy.peekAccountByKey(key)
    local store = IKST_Economy.getStore()
    if not store or not key or key == "" then
        return nil
    end
    return store.accounts[key]
end

function IKST_Economy.getAccountByKey(key)
    local store = IKST_Economy.getStore()
    if not store or not key or key == "" then
        return { bank = 0, pending = 0 }
    end
    local row = store.accounts[key]
    if row then
        return row
    end
    if not IKST_Economy.mayMutateStore() then
        return { bank = 0, pending = 0 }
    end
    row = { bank = 0, pending = 0 }
    store.accounts[key] = row
    return row
end

function IKST_Economy.getAccount(player)
    if not player then
        return { bank = 0, pending = 0 }
    end
    return IKST_Economy.getAccountByKey(IKST_Economy.accountKey(player))
end

function IKST_Economy.getBank(player)
    if not player then
        return 0
    end
    if IKST_Economy.usesClientSnapshot() then
        return IKST_Economy.readClientBank(player)
    end
    local row = IKST_Economy.getAccount(player)
    return math.floor(tonumber(row.bank) or 0)
end

function IKST_Economy.getPending(player)
    if not player then
        return 0
    end
    if IKST_Economy.usesClientSnapshot() then
        return IKST_Economy.readClientPending(player)
    end
    local row = IKST_Economy.getAccount(player)
    return math.floor(tonumber(row.pending) or 0)
end

function IKST_Economy.addBank(player, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or not player or not IKST_Economy.mayMutateStore() then
        return false
    end
    local row = IKST_Economy.getAccount(player)
    row.bank = math.floor((tonumber(row.bank) or 0) + amount)
    IKST_Economy.persistStore()
    return true
end

function IKST_Economy.takeBank(player, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or not player or not IKST_Economy.mayMutateStore() then
        return false
    end
    local row = IKST_Economy.getAccount(player)
    local bal = math.floor(tonumber(row.bank) or 0)
    if bal < amount then
        return false
    end
    row.bank = bal - amount
    IKST_Economy.persistStore()
    return true
end

function IKST_Economy.addPending(accountKey, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or not accountKey or accountKey == "" or not IKST_Economy.mayMutateStore() then
        return
    end
    if not IKST_Identity.isAccountKey(accountKey) then
        accountKey = IKST_Identity.keyForLegacyName(accountKey) or accountKey
    end
    local row = IKST_Economy.getAccountByKey(accountKey)
    row.pending = math.floor((tonumber(row.pending) or 0) + amount)
    IKST_Economy.persistStore()
end

function IKST_Economy.claimPending(player)
    if not player or not IKST_Economy.mayMutateStore() then
        return 0
    end
    local row = IKST_Economy.getAccount(player)
    local pending = math.floor(tonumber(row.pending) or 0)
    if pending > 0 then
        row.bank = math.floor((tonumber(row.bank) or 0) + pending)
        row.pending = 0
    end
    IKST_Economy.persistStore()
    return pending
end

function IKST_Economy.autoAcceptOn(player)
    if not player then
        return true
    end
    local row = IKST_Economy.getAccount(player)
    return row.autoAccept ~= false
end

function IKST_Economy.historyLine(text)
    text = tostring(text or "")
    text = string.gsub(text, "[%c]", " ")
    text = string.gsub(text, "^%s*(.-)%s*$", "%1")
    if #text > 80 then
        text = string.sub(text, 1, 80)
    end
    return text
end

function IKST_Economy.appendHistory(player, line)
    if not player or not IKST_Economy.mayMutateStore() then
        return
    end
    line = IKST_Economy.historyLine(line)
    if line == "" then
        return
    end
    local row = IKST_Economy.getAccount(player)
    if type(row.history) ~= "table" then
        row.history = {}
    end
    table.insert(row.history, 1, line)
    local maxN = IKST_Economy.HISTORY_MAX or 12
    while #row.history > maxN do
        table.remove(row.history)
    end
    IKST_Economy.persistStore()
end

function IKST_Economy.historyCopy(player)
    local out = {}
    if not player then
        return out
    end
    local row = IKST_Economy.getAccount(player)
    local hist = row.history
    if type(hist) ~= "table" then
        return out
    end
    local maxN = IKST_Economy.HISTORY_MAX or 12
    local n = #hist
    if n > maxN then
        n = maxN
    end
    for i = 1, n do
        local line = IKST_Economy.historyLine(hist[i])
        if line ~= "" then
            out[#out + 1] = line
        end
    end
    return out
end

function IKST_Economy.payReqPublic(player)
    if not player then
        return nil
    end
    local row = IKST_Economy.getAccount(player)
    local req = row.payReq
    if type(req) ~= "table" then
        return nil
    end
    local amount = math.floor(tonumber(req.amount) or 0)
    if amount <= 0 then
        return nil
    end
    local fromName = tostring(req.fromName or "player")
    fromName = string.gsub(fromName, "[%c]", " ")
    if #fromName > 32 then
        fromName = string.sub(fromName, 1, 32)
    end
    return { amount = amount, fromName = fromName }
end

function IKST_Economy.coordKey(x, y, z)
    return math.floor(tonumber(x) or 0) .. "," .. math.floor(tonumber(y) or 0) .. "," .. math.floor(tonumber(z) or 0)
end

function IKST_Economy.getAtm(x, y, z)
    local store = IKST_Economy.getStore()
    if not store then
        return nil
    end
    return store.atms[IKST_Economy.coordKey(x, y, z)]
end

function IKST_Economy.setAtm(x, y, z, cfg)
    if not IKST_Economy.mayMutateStore() then
        return
    end
    local store = IKST_Economy.getStore()
    if not store then
        return
    end
    store.atms[IKST_Economy.coordKey(x, y, z)] = cfg or {
        deposit = true,
        withdraw = true,
        valuables = true,
    }
    IKST_Economy.persistStore()
end

function IKST_Economy.clearAtm(x, y, z)
    if not IKST_Economy.mayMutateStore() then
        return
    end
    local store = IKST_Economy.getStore()
    if not store then
        return
    end
    store.atms[IKST_Economy.coordKey(x, y, z)] = nil
    IKST_Economy.persistStore()
end

function IKST_Economy.isAtmSquare(x, y, z)
    if IKST_Economy.getAtm(x, y, z) then
        return true
    end
    local sq = IKST_Grid and IKST_Grid.getSquare(x, y, z)
    if not sq or not sq.getObjects then
        return false
    end
    for i = 0, sq:getObjects():size() - 1 do
        local obj = sq:getObjects():get(i)
        if IKST_Economy.isAtmEnabledObject(obj) then
            return true
        end
    end
    return false
end

function IKST_Economy.atmAllows(x, y, z, action)
    local cfg = IKST_Economy.getAtm(x, y, z)
    if not cfg then
        return true
    end
    if action == "deposit" then
        return cfg.deposit ~= false
    end
    if action == "withdraw" then
        return cfg.withdraw ~= false
    end
    if action == "valuables" then
        return cfg.valuables ~= false
    end
    return true
end

function IKST_Economy.playerNearCoord(player, x, y, z, maxDist)
    if not player then
        return false
    end
    maxDist = tonumber(maxDist) or 4
    local dx = player:getX() - (tonumber(x) or 0)
    local dy = player:getY() - (tonumber(y) or 0)
    return (dx * dx + dy * dy) <= (maxDist * maxDist)
end

function IKST_Economy.snapshot(player)
    IKST_Economy.claimPending(player)
    return {
        cash = IKST_EconomyBridge.getCash(player),
        bank = IKST_Economy.getBank(player),
        pending = IKST_Economy.getPending(player),
        autoAccept = IKST_Economy.autoAcceptOn(player),
        payReq = IKST_Economy.payReqPublic(player),
        history = IKST_Economy.historyCopy(player),
    }
end

function IKST_Economy.loadValuables()
    if IKST_Economy._valuables then
        return IKST_Economy._valuables
    end
    local list = {}
    local fileLines = IKST_Economy.readModTextLines("media/ikst/valuables_list.txt")
    for i = 1, #fileLines do
        local line = IKST_Economy._trimText(fileLines[i])
        if line ~= "" and line:sub(1, 1) ~= "#" then
            local itemType, label, price = line:match("^([^|]+)|([^|]+)|(%d+)$")
            itemType = itemType and IKST_Economy._trimText(itemType)
            label = label and IKST_Economy._trimText(label)
            price = tonumber(price)
            if itemType and price and price > 0 then
                table.insert(list, { itemType = itemType, label = label or itemType, price = price })
            end
        end
    end
    if #list == 0 then
        list = {
            { itemType = "Base.GoldScrap", label = "Gold fragments", price = 25 },
            { itemType = "Base.SilverScrap", label = "Silver fragments", price = 12 },
            { itemType = "Base.Necklace_Gold", label = "Gold necklace", price = 40 },
        }
    end
    local byType = {}
    for _, e in ipairs(list) do
        byType[e.itemType] = e
    end
    IKST_Economy._valuables = { list = list, byType = byType }
    return IKST_Economy._valuables
end

function IKST_Economy.valuableEntry(itemType)
    local data = IKST_Economy.loadValuables()
    return data.byType[itemType]
end

function IKST_Economy.installModDataReceive()
    if IKST_Economy._modDataReceiveInstalled then
        return
    end
    if not Events or not Events.OnReceiveGlobalModData or not Events.OnReceiveGlobalModData.Add then
        return
    end
    Events.OnReceiveGlobalModData.Add(function(key, data)
        if key ~= IKST_Economy.STORE_KEY or not data or data == false then
            return
        end
        if IKST_Economy.isMpRemoteClient() then
            return
        end
        if ModData and ModData.add then
            ModData.add(key, data)
        end
    end)
    IKST_Economy._modDataReceiveInstalled = true
end

function IKST_Economy.installServerSync()
    if IKST_Economy._serverSyncInstalled then
        return
    end
    if not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return
    end
    local function push()
        if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
            return
        end
        if not getOnlinePlayers then
            return
        end
        local list = getOnlinePlayers()
        if not list or not list.size then
            return
        end
        for i = 0, list:size() - 1 do
            local p = list:get(i)
            if p and IKST_EconomyOps and IKST_EconomyOps.sendSnapshot then
                IKST_EconomyOps.sendSnapshot(p)
            end
        end
    end
    if Events and Events.OnGameStart and Events.OnGameStart.Add then
        Events.OnGameStart.Add(push)
    end
    if Events and Events.OnConnected and Events.OnConnected.Add then
        Events.OnConnected.Add(push)
    end
    IKST_Economy._serverSyncInstalled = true
end

function IKST_Economy.formatMsg(key, fallback, ...)
    local fmt = IKST.text(key, fallback)
    local argc = select("#", ...)
    for i = 1, argc do
        local v = select(i, ...)
        fmt = string.gsub(fmt, "%%" .. i, tostring(v or ""))
    end
    return fmt
end

function IKST_Economy.formatResultMessage(code, extra)
    local msg = tostring(code or "")
    extra = extra or {}

    if msg == "use an ATM" or msg == "use an ATM to deposit" or msg == "use an ATM to withdraw" then
        return IKST.text("IGUI_IKST_Economy_UseAtmHint", "Go to an ATM for bank deposit, withdraw, and exchange.")
    end
    if msg == "ATM action disabled" then
        return IKST.text("IGUI_IKST_Economy_AtmActionDisabled", "That ATM action is disabled.")
    end
    if msg == "too far" or msg == "too far to wire cash" then
        return IKST.text("IGUI_IKST_Economy_TooFar", "Too far from that location.")
    end
    if msg == "present your bank ID card" then
        return IKST.text("IGUI_IKST_Economy_PresentIdCard", "Present your bank ID card.")
    end
    if msg == "invalid amount" then
        return IKST.text("IGUI_IKST_Economy_InvalidAmount", "Invalid amount.")
    end
    if msg == "not enough cash" then
        return IKST.text("IGUI_IKST_Economy_NotEnoughCash", "Not enough cash.")
    end
    if msg == "not enough in bank" then
        return IKST.text("IGUI_IKST_Economy_NotEnoughBank", "Not enough in bank.")
    end
    if msg == "funds are already in your bank account" then
        return IKST.text("IGUI_IKST_Economy_FundsInBank", "Funds are already in your bank account.")
    end
    if msg == "withdraw disabled — use wire or shop" then
        return IKST.text("IGUI_IKST_Economy_WithdrawDisabled", "Withdraw disabled — use wire or shop.")
    end
    if msg == "could not give cash" then
        return IKST.text("IGUI_IKST_Economy_CouldNotGiveCash", "Could not give cash.")
    end
    if msg == "amount below minimum" then
        return IKST.text("IGUI_IKST_Economy_AmountBelowMin", "Amount below minimum.")
    end
    if msg == "player not found" then
        return IKST.text("IGUI_IKST_Economy_PlayerNotFound", "Player not found.")
    end
    if msg == "cannot wire yourself" then
        return IKST.text("IGUI_IKST_Economy_CannotWireSelf", "Cannot wire yourself.")
    end
    if msg == "fee exceeds amount" then
        return IKST.text("IGUI_IKST_Economy_FeeExceedsAmount", "Fee exceeds amount.")
    end
    if msg == "wire failed" then
        return IKST.text("IGUI_IKST_Economy_WireFailed", "Wire failed.")
    end
    if msg == "not accepting transfers" then
        return IKST.text("IGUI_IKST_Economy_NotAccepting", "That player is not accepting transfers.")
    end
    if msg == "request pending" then
        return IKST.text("IGUI_IKST_Economy_RequestPending", "That player already has a payment request.")
    end
    if msg == "no payment request" then
        return IKST.text("IGUI_IKST_Economy_NoPayRequest", "No payment request waiting.")
    end
    if msg == "pref_ok" then
        return IKST.text("IGUI_IKST_Economy_PrefOk", "Transfer preference saved.")
    end
    if msg == "pay_request_ok" then
        return IKST.text("IGUI_IKST_Economy_PayRequestOk", "Payment request sent.")
    end
    if msg == "pay_request_in" then
        return IKST.text("IGUI_IKST_Economy_PayRequestIn", "Someone requested a payment from you.")
    end
    if msg == "pay_accepted" then
        return IKST.text("IGUI_IKST_Economy_PayAccepted", "Payment request paid.")
    end
    if msg == "pay_declined" then
        return IKST.text("IGUI_IKST_Economy_PayDeclined", "Payment request declined.")
    end
    if msg == "ticket sent" then
        return IKST.text("IGUI_IKST_TicketSent", "Ticket sent. Staff review it in F1 See Tickets.")
    end
    if msg == "enter a message" then
        return IKST.text("IGUI_IKST_Economy_TicketNeedMsg", "Enter a message.")
    end
    if msg == "multiplayer only" then
        return IKST.text("IGUI_IKST_Economy_TicketMpOnly",
            "Delivery and player bounty tickets need multiplayer. Staff review them in F1 See Tickets.")
    end
    if msg == "not enough money (cash + bank)" then
        return IKST.text("IGUI_IKST_Economy_NotEnoughMoney", "Not enough money (cash + bank).")
    end
    if msg == "not for sale — owner must set a price" then
        return IKST.text("IGUI_IKST_Economy_NotForSale", "That item is not for sale.")
    end
    if msg == "payout failed" then
        return IKST.text("IGUI_IKST_Economy_PayoutFailed", "Payout failed.")
    end

    if msg == "deposit_ok" then
        local amount = extra.resultAmount
        if amount ~= nil then
            return IKST_Economy.formatMsg("IGUI_IKST_Economy_DepositOk", "Deposited %1", IKST_Economy.formatAmount(amount))
        end
        return IKST.text("IGUI_IKST_Economy_DepositOkShort", "Deposit complete.")
    end
    if msg == "withdraw_ok" then
        local amount = extra.resultAmount
        if amount ~= nil then
            return IKST_Economy.formatMsg("IGUI_IKST_Economy_WithdrawOk", "Withdrew %1", IKST_Economy.formatAmount(amount))
        end
        return IKST.text("IGUI_IKST_Economy_WithdrawOkShort", "Withdraw complete.")
    end
    if msg == "wire_ok" then
        local receive = extra.resultReceive
        local target = extra.resultTarget or ""
        local line = IKST_Economy.formatMsg("IGUI_IKST_Economy_WireOk", "Wired %1 to %2",
            receive ~= nil and IKST_Economy.formatAmount(receive) or "", target)
        local fee = extra.resultFee
        if fee ~= nil and tonumber(fee) and tonumber(fee) > 0 then
            line = line .. IKST_Economy.formatMsg("IGUI_IKST_Economy_WireFeeSuffix", " (fee %1)", IKST_Economy.formatAmount(fee))
        end
        return line
    end
    if msg == "purchase_ok" then
        local price = extra.resultPrice
        if price ~= nil then
            return IKST_Economy.formatMsg("IGUI_IKST_Economy_PurchaseOk", "Purchased 1 for %1", IKST_Economy.formatAmount(price))
        end
        return IKST.text("IGUI_IKST_Economy_PurchaseOkShort", "Purchase complete.")
    end
    if msg == "exchange_ok" then
        local payout = extra.resultPayout
        if payout ~= nil then
            return IKST_Economy.formatMsg("IGUI_IKST_Economy_ExchangeOk", "Exchanged for %1", IKST_Economy.formatAmount(payout))
        end
        return IKST.text("IGUI_IKST_Economy_ExchangeOkShort", "Exchange complete.")
    end
    if msg == "exchange_all_ok" then
        local count = extra.resultCount
        local payout = extra.resultPayout
        if count ~= nil and payout ~= nil then
            return IKST_Economy.formatMsg("IGUI_IKST_Economy_ExchangeAllOk", "Sold %1 items for %2",
                tostring(count), IKST_Economy.formatAmount(payout))
        end
        return IKST.text("IGUI_IKST_Economy_ExchangeAllOkShort", "Sold valuables.")
    end

    return msg
end

IKST_Economy.installModDataReceive()
IKST_Economy.installServerSync()
