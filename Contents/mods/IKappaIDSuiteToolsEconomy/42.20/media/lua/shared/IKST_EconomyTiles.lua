-- Shop/ATM tile helpers (split from IKST_Economy). Same IKST_Economy table.
require "IKST_Shared"
require "IKST_Identity"
require "IKST_Grid"
require "IKST_Access"

IKST_Economy = IKST_Economy or {}

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
            if o and type(o.getContainer) == "function" and o:getContainer() == container and IKST_Economy.isProtectedShopObject(o) then
                return o
            end
        end
    end
    return nil
end
