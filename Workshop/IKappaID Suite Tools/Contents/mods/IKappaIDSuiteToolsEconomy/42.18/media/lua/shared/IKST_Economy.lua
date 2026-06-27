-- IKST player economy (bank, wire, vending, valuables) — uses PhoneShop physical cash when loaded.

require "IKST_Shared"
require "IKST_Identity"
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

function IKST_Economy.shopTilesRequired()
    return IKST_Economy.sandboxBool("EconomyShopTilesOnly", true)
end

function IKST_Economy.shopProtectEnabled()
    return IKST_Economy.sandboxBool("EconomyShopProtect", true)
end

function IKST_Economy.objectSpriteName(obj)
    if not obj then
        return nil
    end
    if obj.getSpriteName then
        local name = obj:getSpriteName()
        if name then
            name = tostring(name)
            if name ~= "" then
                return name
            end
        end
    end
    if obj.getSprite then
        local sprite = obj:getSprite()
        if sprite and sprite.getName then
            local name = sprite:getName()
            if name then
                name = tostring(name)
                if name ~= "" then
                    return name
                end
            end
        end
    end
    return nil
end

function IKST_Economy._trimText(line)
    if line == nil then
        return nil
    end
    line = tostring(line)
    return line:match("^%s*(.-)%s*$") or ""
end

function IKST_Economy._mapHasEntries(map)
    if not map then
        return false
    end
    for _ in pairs(map) do
        return true
    end
    return false
end

function IKST_Economy._appendTileLine(line, exact, prefixes)
    line = IKST_Economy._trimText(line)
    if line == "" or line:sub(1, 1) == "#" then
        return
    end
    if line:sub(-1) == "_" then
        prefixes[#prefixes + 1] = line
    else
        exact[line] = true
    end
end

-- B42.19: getModFileReader may return a handle without Lua-bound readLine/close; guard before calling.
function IKST_Economy.readModTextLines(relPath)
    local lines = {}
    if type(getModFileReader) ~= "function" or not relPath or relPath == "" then
        return lines
    end
    local reader = getModFileReader("IKappaIDSuiteToolsEconomy", relPath, false)
    if not reader then
        return lines
    end
    local readLine = reader.readLine
    if type(readLine) ~= "function" then
        return lines
    end
    while true do
        local line = readLine(reader)
        if line == nil then
            break
        end
        lines[#lines + 1] = tostring(line)
    end
    local closeFn = reader.close
    if type(closeFn) == "function" then
        closeFn(reader)
    end
    return lines
end

function IKST_Economy.loadShopTiles()
    if IKST_Economy._shopTiles then
        return IKST_Economy._shopTiles
    end
    local exact = {}
    local prefixes = {}
    local ordered = {}
    local fileLines = IKST_Economy.readModTextLines("media/ikst/shop_tiles.txt")
    for i = 1, #fileLines do
        local line = IKST_Economy._trimText(fileLines[i])
        if line ~= "" and line:sub(1, 1) ~= "#" then
            if line:sub(-1) == "_" then
                prefixes[#prefixes + 1] = line
            else
                exact[line] = true
                ordered[#ordered + 1] = line
            end
        end
    end
    if #prefixes == 0 and not IKST_Economy._mapHasEntries(exact) then
        prefixes = {
            "location_shop_accessories_01_",
        }
    end
    IKST_Economy._shopTiles = { exact = exact, prefixes = prefixes, ordered = ordered }
    return IKST_Economy._shopTiles
end

function IKST_Economy.loadAtmTiles()
    if IKST_Economy._atmTiles then
        return IKST_Economy._atmTiles
    end
    local exact = {}
    local prefixes = {}
    local ordered = {}
    local fileLines = IKST_Economy.readModTextLines("media/ikst/atm_tiles.txt")
    for i = 1, #fileLines do
        local line = IKST_Economy._trimText(fileLines[i])
        if line ~= "" and line:sub(1, 1) ~= "#" then
            if line:sub(-1) == "_" then
                prefixes[#prefixes + 1] = line
            else
                exact[line] = true
                ordered[#ordered + 1] = line
            end
        end
    end
    if #prefixes == 0 and not IKST_Economy._mapHasEntries(exact) then
        local defaults = IKST_Economy.ATM_VANILLA_SPRITES
        if defaults then
            for i = 1, #defaults do
                exact[defaults[i]] = true
                ordered[#ordered + 1] = defaults[i]
            end
        end
    end
    IKST_Economy._atmTiles = { exact = exact, prefixes = prefixes, ordered = ordered }
    return IKST_Economy._atmTiles
end

function IKST_Economy.spriteSpawnable(spriteName)
    if not spriteName or spriteName == "" then
        return false
    end
    if getSprite then
        return getSprite(spriteName) ~= nil
    end
    return false
end

function IKST_Economy._appendSpawnCandidate(list, seen, spriteName)
    if not spriteName or spriteName == "" or seen[spriteName] then
        return
    end
    if IKST_Economy.spriteSpawnable(spriteName) then
        seen[spriteName] = true
        list[#list + 1] = spriteName
    end
end

-- Spawn candidates: IKST art first. Bank vault tiles stay detect-only unless includeListedVanilla is true.
function IKST_Economy.spawnSpriteCandidates(primary, fallbacks, tileData, spawnPrefix, includeListedVanilla)
    local list = {}
    local seen = {}
    spawnPrefix = spawnPrefix or "ikst_"
    if tileData and tileData.ordered then
        for i = 1, #tileData.ordered do
            local sprite = tileData.ordered[i]
            if string.sub(sprite, 1, #spawnPrefix) == spawnPrefix then
                IKST_Economy._appendSpawnCandidate(list, seen, sprite)
            end
        end
    end
    IKST_Economy._appendSpawnCandidate(list, seen, primary)
    if fallbacks then
        for i = 1, #fallbacks do
            IKST_Economy._appendSpawnCandidate(list, seen, fallbacks[i])
        end
    end
    if includeListedVanilla and tileData and tileData.ordered then
        for i = 1, #tileData.ordered do
            local sprite = tileData.ordered[i]
            if string.sub(sprite, 1, #spawnPrefix) ~= spawnPrefix then
                IKST_Economy._appendSpawnCandidate(list, seen, sprite)
            end
        end
    end
    return list
end

function IKST_Economy.isAtmTileSprite(spriteName)
    if not spriteName or spriteName == "" then
        return false
    end
    spriteName = tostring(spriteName)
    local data = IKST_Economy.loadAtmTiles()
    if data.exact[spriteName] then
        return true
    end
    for _, prefix in ipairs(data.prefixes) do
        if #prefix > 0 and string.sub(spriteName, 1, #prefix) == prefix then
            return true
        end
    end
    return false
end

function IKST_Economy.atmTerminalSprite()
    return IKST_Economy.ATM_TERMINAL_SPRITE
end

function IKST_Economy.atmTerminalSpriteCandidates()
    return IKST_Economy.spawnSpriteCandidates(
        IKST_Economy.atmTerminalSprite(),
        IKST_Economy.ATM_TERMINAL_SPRITE_FALLBACKS,
        IKST_Economy.loadAtmTiles(),
        "ikst_",
        false
    )
end

function IKST_Economy.isAtmEnabledObject(obj)
    if not obj or not obj.getModData then
        return false
    end
    local md = obj:getModData()
    return md and md[IKST_Economy.ATM_TAG] == true
end

-- Vanilla bank ATM prop sprite (decorative in vanilla — not enabled until admin places or marks).
function IKST_Economy.isAtmTileObject(obj)
    return IKST_Economy.isAtmTileSprite(IKST_Economy.objectSpriteName(obj))
end

function IKST_Economy.findAtmObjectOnSquare(sq)
    if not sq or not sq.getObjects then
        return nil
    end
    for i = 0, sq:getObjects():size() - 1 do
        local obj = sq:getObjects():get(i)
        if IKST_Economy.isAtmTileObject(obj) then
            return obj
        end
    end
    return nil
end

function IKST_Economy.shopTerminalSprite()
    return IKST_Economy.SHOP_TERMINAL_SPRITE
end

function IKST_Economy.shopTerminalSignSprite()
    return IKST_Economy.SHOP_TERMINAL_SIGN
end

function IKST_Economy.shopTerminalSpriteCandidates()
    return IKST_Economy.spawnSpriteCandidates(
        IKST_Economy.shopTerminalSprite(),
        IKST_Economy.SHOP_TERMINAL_SPRITE_FALLBACKS,
        IKST_Economy.loadShopTiles(),
        "ikst_",
        true
    )
end

function IKST_Economy.isBuiltShopTerminal(obj)
    if not obj or not obj.getModData then
        return false
    end
    local md = obj:getModData()
    return md and md[IKST_Economy.SHOP_TERMINAL_TAG] == true
end

function IKST_Economy.isShopTileSprite(spriteName)
    if not spriteName or spriteName == "" then
        return false
    end
    spriteName = tostring(spriteName)
    if not IKST_Economy.shopTilesRequired() then
        return true
    end
    local data = IKST_Economy.loadShopTiles()
    if data.exact[spriteName] then
        return true
    end
    for _, prefix in ipairs(data.prefixes) do
        if #prefix > 0 and string.sub(spriteName, 1, #prefix) == prefix then
            return true
        end
    end
    return false
end

function IKST_Economy.isShopTileObject(obj)
    if not obj or not obj.getContainer or not obj:getContainer() then
        return false
    end
    if IKST_Economy.isBuiltShopTerminal(obj) then
        return true
    end
    return IKST_Economy.isShopTileSprite(IKST_Economy.objectSpriteName(obj))
end

function IKST_Economy.isVendObject(obj)
    if not obj or not obj.getModData then
        return false
    end
    local md = obj:getModData()
    return md and md[IKST_Economy.VEND_TAG] == true
end

function IKST_Economy.vendOwnerOfObject(obj)
    if not obj or not obj.getModData then
        return nil
    end
    local md = obj:getModData()
    return md and md[IKST_Economy.VEND_OWNER]
end

function IKST_Economy.containerParentObject(container)
    if container and container.getParent then
        return container:getParent()
    end
    return nil
end

function IKST_Economy.containerShopSquare(container)
    if container and container.getSourceGrid then
        return container:getSourceGrid()
    end
    local parent = IKST_Economy.containerParentObject(container)
    if parent and parent.getSquare then
        return parent:getSquare()
    end
    return nil
end

function IKST_Economy.isProtectedShopObject(obj)
    if not obj then
        return false
    end
    if IKST_Economy.isBuiltShopTerminal(obj) then
        return true
    end
    return IKST_Economy.isVendObject(obj)
end

function IKST_Economy.shopPlacerOfObject(obj)
    if not obj or not obj.getModData then
        return nil
    end
    local md = obj:getModData()
    return md and md[IKST_Economy.SHOP_PLACER]
end

function IKST_Economy.playerMayManageShopStock(obj, player)
    if not obj or not player then
        return false
    end
    local owner = IKST_Economy.vendOwnerOfObject(obj)
    if owner and owner ~= "" and IKST_Identity.playerOwnsKey(player, owner) then
        return true
    end
    local placer = IKST_Economy.shopPlacerOfObject(obj)
    if placer and placer ~= "" and IKST_Identity.playerOwnsKey(player, placer) then
        return true
    end
    return false
end

function IKST_Economy.shopObjectForContainer(container)
    if not container then
        return nil
    end
    local parent = IKST_Economy.containerParentObject(container)
    if parent and IKST_Economy.isProtectedShopObject(parent) then
        if not parent.getContainer or parent:getContainer() == container then
            return parent
        end
    end
    local sq = IKST_Economy.containerShopSquare(container)
    if sq and sq.getObjects then
        local objects = sq:getObjects()
        for i = 0, objects:size() - 1 do
            local o = objects:get(i)
            if o and o.getContainer and o:getContainer() == container and IKST_Economy.isProtectedShopObject(o) then
                return o
            end
        end
    end
    return nil
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
    local inv = player.getInventory and player:getInventory() or nil
    if not inv then
        return 0
    end
    local n = 0
    if inv.getItemsFromTypeRecurse then
        local items = inv:getItemsFromTypeRecurse(itemType, true)
        if items then
            for i = 0, items:size() - 1 do
                n = n + IKST_Economy.itemCount(items:get(i))
            end
        end
        return n
    end
    if inv.getItems then
        local items = inv:getItems()
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if item and item.getFullType and item:getFullType() == itemType then
                n = n + IKST_Economy.itemCount(item)
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
    if instanceof and instanceof(item, "Food") and item.isRotten and item:isRotten() then
        return false
    end
    return true
end

function IKST_Economy.freshnessSuffix(item)
    if not item or not IKST_Economy.isPerishableItem(item) then
        return ""
    end
    if instanceof and instanceof(item, "Food") and item.isRotten and item:isRotten() then
        return " (" .. IKST.text("IGUI_IKST_Economy_FreshRotten", "rotten") .. ")"
    end
    if instanceof and instanceof(item, "Food") and item.isFresh and item:isFresh() then
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
    return IKST_Economy.sandboxBool("EconomyZombieBounty", true)
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
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        return true
    end
    return IKST.runsOnServerJvm and IKST.runsOnServerJvm()
end

function IKST_Economy.persistStore()
    if not IKST_Economy.mayMutateStore() then
        return
    end
    if ModData and ModData.transmit and IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        ModData.transmit(IKST_Economy.STORE_KEY)
    end
end

function IKST_Economy.getAccountByKey(key)
    local store = IKST_Economy.getStore()
    if not store or not key or key == "" then
        return { bank = 0, pending = 0 }
    end
    local row = store.accounts[key]
    if not row then
        row = { bank = 0, pending = 0 }
        store.accounts[key] = row
    end
    return row
end

function IKST_Economy.getAccount(player)
    if not player then
        return { bank = 0, pending = 0 }
    end
    return IKST_Economy.getAccountByKey(IKST_Economy.accountKey(player))
end

function IKST_Economy.getBank(player)
    local row = IKST_Economy.getAccount(player)
    return math.floor(tonumber(row.bank) or 0)
end

function IKST_Economy.getPending(player)
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
        if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
            IKST_Economy.persistStore()
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

IKST_Economy.installModDataReceive()
IKST_Economy.installServerSync()
