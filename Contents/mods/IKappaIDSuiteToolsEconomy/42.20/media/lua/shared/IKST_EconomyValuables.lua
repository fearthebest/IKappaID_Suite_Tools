-- ATM valuables sell list — operator-editable text files (PhoneShop-style).

require "IKST_Shared"
require "IKST_EconomyTiles"

IKST_EconomyValuables = IKST_EconomyValuables or {}

local MOD_ID = "IKappaIDSuiteToolsEconomy"
local SELL_PATH = "media/ikst/sell_list.txt"
local JEWELRY_PATH = "media/ikst/valuables_list.txt"

IKST_EconomyValuables.lastLoadStats = IKST_EconomyValuables.lastLoadStats or {}

local function trim(s)
    if not s then
        return nil
    end
    return s:match("^%s*(.-)%s*$")
end

local function readLines(relPath)
    if IKST_Economy and IKST_Economy.readModTextLines then
        return IKST_Economy.readModTextLines(relPath)
    end
    return {}
end

local function parseLine(line)
    line = trim(line)
    if not line or line == "" or line:sub(1, 1) == "#" then
        return nil
    end
    local itemType, label, price, category = line:match("^([^|]+)|([^|]+)|(%d+)|([^|]*)$")
    if not itemType then
        itemType, label, price = line:match("^([^|]+)|([^|]+)|(%d+)$")
        category = nil
    end
    itemType = trim(itemType)
    label = trim(label)
    category = trim(category)
    price = tonumber(price)
    if not itemType or itemType == "" or not price or price <= 0 then
        return nil
    end
    return {
        itemType = itemType,
        label = (label and label ~= "") and label or itemType,
        price = math.floor(price),
        category = category,
    }
end

local function readFile(path, statsKey)
    local list = {}
    local stats = { skipped = 0, lines = 0, loaded = 0 }
    for _, raw in ipairs(readLines(path)) do
        local line = trim(raw)
        if line and line ~= "" and line:sub(1, 1) ~= "#" then
            stats.lines = stats.lines + 1
            local entry = parseLine(line)
            if entry then
                list[#list + 1] = entry
                stats.loaded = stats.loaded + 1
            else
                stats.skipped = stats.skipped + 1
            end
        end
    end
    if statsKey then
        IKST_EconomyValuables.lastLoadStats[statsKey] = stats
    end
    return list
end

local function indexByType(list)
    local byType = {}
    local order = {}
    for _, entry in ipairs(list) do
        if entry and entry.itemType then
            if not byType[entry.itemType] then
                order[#order + 1] = entry.itemType
            end
            byType[entry.itemType] = entry
        end
    end
    return byType, order
end

local function mergeList(baseByType, baseOrder, extraList, overwrite)
    for _, entry in ipairs(extraList) do
        if entry and entry.itemType then
            if overwrite or not baseByType[entry.itemType] then
                if not baseByType[entry.itemType] then
                    baseOrder[#baseOrder + 1] = entry.itemType
                end
                baseByType[entry.itemType] = entry
            end
        end
    end
end

local function listFromIndex(byType, order)
    local list = {}
    for i = 1, #order do
        local entry = byType[order[i]]
        if entry then
            list[#list + 1] = entry
        end
    end
    return list
end

function IKST_EconomyValuables.mirrorPhoneShop()
    if not IKST_Economy or not IKST_Economy.sandboxBool then
        return false
    end
    return IKST_Economy.sandboxBool("EconomyValuablesMirrorPhoneShop", true) == true
end

function IKST_EconomyValuables.phoneShopSellList()
    if not IKST_EconomyValuables.mirrorPhoneShop() then
        return nil
    end
    if not PhoneShopConfig or type(PhoneShopConfig.SellList) ~= "table" then
        return nil
    end
    return PhoneShopConfig.SellList
end

function IKST_EconomyValuables.build()
    local sell = readFile(SELL_PATH, "sell")
    local jewelry = readFile(JEWELRY_PATH, "jewelry")
    local byType, order = indexByType(sell)
    mergeList(byType, order, jewelry, false)

    local phoneSell = IKST_EconomyValuables.phoneShopSellList()
    if phoneSell then
        local phoneEntries = {}
        for _, entry in ipairs(phoneSell) do
            if entry and entry.itemType and tonumber(entry.price) and entry.price > 0 then
                phoneEntries[#phoneEntries + 1] = {
                    itemType = entry.itemType,
                    label = entry.label or entry.itemType,
                    price = math.floor(tonumber(entry.price) or 0),
                    category = entry.category,
                }
            end
        end
        mergeList(byType, order, phoneEntries, true)
        IKST_EconomyValuables.lastLoadStats.phoneshop = {
            loaded = #phoneEntries,
            skipped = 0,
            lines = #phoneEntries,
        }
    end

    local list = listFromIndex(byType, order)
    if #list == 0 then
        list = {
            { itemType = "Base.GoldScrap", label = "Gold fragments", price = 25 },
            { itemType = "Base.SilverScrap", label = "Silver fragments", price = 12 },
            { itemType = "Base.Necklace_Gold", label = "Gold necklace", price = 120 },
        }
        byType = {}
        order = {}
        for _, entry in ipairs(list) do
            byType[entry.itemType] = entry
            order[#order + 1] = entry.itemType
        end
    end

    return { list = list, byType = byType }
end

function IKST_EconomyValuables.reload()
    if IKST_Economy then
        IKST_Economy._valuables = nil
    end
    local data = IKST_EconomyValuables.build()
    if IKST_Economy then
        IKST_Economy._valuables = data
    end
    if print then
        local sellStats = IKST_EconomyValuables.lastLoadStats.sell or {}
        local jewelryStats = IKST_EconomyValuables.lastLoadStats.jewelry or {}
        local phoneStats = IKST_EconomyValuables.lastLoadStats.phoneshop
        local mirror = IKST_EconomyValuables.mirrorPhoneShop()
        print(string.format(
            "[IKST_Economy] valuables loaded sell=%d jewelry_extra=%d total=%d mirror_phone_shop=%s",
            tonumber(sellStats.loaded) or 0,
            tonumber(jewelryStats.loaded) or 0,
            #(data.list or {}),
            mirror and "yes" or "no"
        ))
        if phoneStats then
            print(string.format("[IKST_Economy] PhoneShop sell prices applied: %d entries", phoneStats.loaded or 0))
        end
        local function warnSkipped(key, label)
            local st = IKST_EconomyValuables.lastLoadStats[key]
            if st and st.skipped and st.skipped > 0 then
                print(string.format(
                    "[IKST_Economy] WARN: %s — %d line(s) skipped (bad format)",
                    label, st.skipped
                ))
            end
        end
        warnSkipped("sell", SELL_PATH)
        warnSkipped("jewelry", JEWELRY_PATH)
        if #(data.list or {}) == 0 then
            print("[IKST_Economy] WARN: valuables list is empty — check media/ikst/sell_list.txt")
        end
    end
    return data
end

function IKST_EconomyValuables.load()
    if IKST_Economy and IKST_Economy._valuables then
        return IKST_Economy._valuables
    end
    return IKST_EconomyValuables.reload()
end

if Events and Events.OnGameBoot and Events.OnGameBoot.Add then
    Events.OnGameBoot.Add(function()
        IKST_EconomyValuables.reload()
    end)
end
