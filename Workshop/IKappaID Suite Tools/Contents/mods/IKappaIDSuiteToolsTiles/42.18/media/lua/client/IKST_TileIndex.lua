if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"

IKST_TileIndex = IKST_TileIndex or {}
IKST_TileIndex.cache = IKST_TileIndex.cache or {}
IKST_TileIndex.packNamesCache = nil
IKST_TileIndex.MAX_PACKS = 256
IKST_TileIndex.MAX_SPRITES = 512
IKST_TileIndex.MAX_MISSES = 64
-- mod.info pack= name can differ from .tiles tileset / sprite prefix
IKST_TileIndex.PACK_SPRITE_PREFIXES = {
    ["ikst_suite"] = { "ikst_economy_01", "ikst_suite" },
}

-- Explicit list when pack probing fails (8 economy facings).
IKST_TileIndex.PACK_KNOWN_SPRITES = {
    ["ikst_suite"] = {
        "ikst_economy_01_0",
        "ikst_economy_01_1",
        "ikst_economy_01_2",
        "ikst_economy_01_3",
        "ikst_economy_01_4",
        "ikst_economy_01_5",
        "ikst_economy_01_6",
        "ikst_economy_01_7",
    },
}

function IKST_TileIndex.spriteExists(spriteName)
    if not spriteName or spriteName == "" then
        return false
    end
    if getSprite then
        local spr = getSprite(spriteName)
        if spr then
            return true
        end
    end
    if getTexture then
        return getTexture(spriteName) ~= nil
    end
    return false
end

function IKST_TileIndex.spriteTexture(spriteName)
    if not spriteName or spriteName == "" then
        return nil
    end
    if getSprite then
        local spr = getSprite(spriteName)
        if spr then
            if spr.getTexture then
                local tex = spr:getTexture()
                if tex then
                    return tex
                end
            end
            if spr.getName and getTexture then
                local tex = getTexture(spr:getName())
                if tex then
                    return tex
                end
            end
        end
    end
    if getTexture then
        return getTexture(spriteName)
    end
    return nil
end

function IKST_TileIndex.packSpritePrefixes(packName)
    local prefixes = { packName }
    local extra = IKST_TileIndex.PACK_SPRITE_PREFIXES[packName]
    if extra then
        for i = 1, #extra do
            local prefix = extra[i]
            if prefix ~= packName then
                prefixes[#prefixes + 1] = prefix
            end
        end
    end
    return prefixes
end

function IKST_TileIndex.stripPackExtension(name)
    if not name then
        return ""
    end
    return string.gsub(tostring(name), "%.%w+$", "")
end

function IKST_TileIndex.getPackNames()
    if IKST_TileIndex.packNamesCache then
        return IKST_TileIndex.packNamesCache
    end
    local out = {}
    if getWorld and getWorld().getTileImageNames then
        local names = getWorld():getTileImageNames()
        if names then
            local limit = math.min(names:size(), IKST_TileIndex.MAX_PACKS)
            for i = 0, limit - 1 do
                out[#out + 1] = IKST_TileIndex.stripPackExtension(names:get(i))
            end
        end
    end
    table.sort(out)
    IKST_TileIndex.packNamesCache = out
    return out
end

function IKST_TileIndex.filterPacks(filter)
    filter = string.lower(tostring(filter or ""))
    local out = {}
    for _, name in ipairs(IKST_TileIndex.getPackNames()) do
        if filter == "" or string.find(string.lower(name), filter, 1, true) then
            out[#out + 1] = name
        end
    end
    return out
end

function IKST_TileIndex.scanPack(packName)
    if not packName or packName == "" then
        return {}
    end
    if IKST_TileIndex.cache[packName] then
        return IKST_TileIndex.cache[packName]
    end
    local sprites = {}
    local seen = {}
    local function addSprite(spriteName)
        if not spriteName or seen[spriteName] then
            return
        end
        if IKST_TileIndex.spriteExists(spriteName) then
            sprites[#sprites + 1] = spriteName
            seen[spriteName] = true
        end
    end
    local known = IKST_TileIndex.PACK_KNOWN_SPRITES[packName]
    if known then
        for i = 1, #known do
            addSprite(known[i])
        end
    end
    local prefixes = IKST_TileIndex.packSpritePrefixes(packName)
    for p = 1, #prefixes do
        local prefix = prefixes[p]
        local misses = 0
        local index = 0
        while index < IKST_TileIndex.MAX_SPRITES and misses < IKST_TileIndex.MAX_MISSES do
            local spriteName = prefix .. "_" .. index
            if not seen[spriteName] then
                if IKST_TileIndex.spriteExists(spriteName) then
                    addSprite(spriteName)
                    misses = 0
                else
                    misses = misses + 1
                end
            end
            index = index + 1
        end
    end
    IKST_TileIndex.cache[packName] = sprites
    return sprites
end

function IKST_TileIndex.filterSpriteList(sprites, filter)
    filter = string.lower(tostring(filter or ""))
    if filter == "" then
        return sprites
    end
    local out = {}
    for _, sprite in ipairs(sprites or {}) do
        local name = tostring(sprite)
        if string.find(string.lower(name), filter, 1, true) then
            out[#out + 1] = name
        end
    end
    return out
end

function IKST_TileIndex.isValidSprite(spriteName)
    return IKST_TileIndex.spriteExists(spriteName)
end

function IKST_TileIndex.invalidate()
    IKST_TileIndex.cache = {}
    IKST_TileIndex.packNamesCache = nil
end

if Events and Events.OnGameStart and Events.OnGameStart.Add then
    Events.OnGameStart.Add(function()
        IKST_TileIndex.invalidate()
    end)
end
