-- Shop/ATM placement helpers (split from IKST_EconomyOps).
if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_Access"
require "IKST_Economy"
require "IKST_Identity"
require "IKST_Grid"
require "IKST_Args"

IKST_EconomyOps = IKST_EconomyOps or {}

function IKST_EconomyOps.findShopTileOnSquare(sq)
    if not sq or not sq.getObjects then
        return nil
    end
    local anyContainer = nil
    for i = 0, sq:getObjects():size() - 1 do
        local obj = sq:getObjects():get(i)
        if obj and type(obj.getContainer) == "function" and obj:getContainer() then
            if not anyContainer then
                anyContainer = obj
            end
            if IKST_Economy.isShopTileObject(obj) then
                return obj
            end
        end
    end
    if IKST_Economy.shopTilesRequired() then
        return nil
    end
    return anyContainer
end

function IKST_EconomyOps.transmitWorldObject(obj)
    if obj and obj.transmitCompleteItemToClients and IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        obj:transmitCompleteItemToClients()
    end
end

local function shopPlaceLog(line)
    print("[IKST Economy] " .. tostring(line))
end

function IKST_EconomyOps.shopPlaceDebug(player, line)
    shopPlaceLog(line)
    if player and IKST.pushLog then
        IKST.pushLog(player, line)
    end
end

function IKST_EconomyOps.objectHasShopContainer(obj)
    return obj and type(obj.getContainer) == "function" and obj:getContainer() ~= nil
end

function IKST_EconomyOps.isVendingContainerType(container)
    if not container or not container.getType then
        return false
    end
    local t = container:getType()
    return t == "vendingsnack" or t == "vendingpop"
end

function IKST_EconomyOps.isLegacyShopContainerType(container)
    if not container or not container.getType then
        return true
    end
    local t = container:getType()
    if t == "fridge" then
        return false
    end
    return t == "vendingsnack" or t == "vendingpop" or t == "crate"
end

function IKST_EconomyOps.shopContainerNeedsUpgrade(container, target)
    if not container then
        return true
    end
    if IKST_EconomyOps.isLegacyShopContainerType(container) then
        return true
    end
    if type(container.getType) == "function" and container:getType() == "fridge" and container.getCapacity then
        local current = tonumber(container:getCapacity()) or 0
        return current < target
    end
    return false
end

function IKST_EconomyOps.migrateContainerItems(oldContainer, newContainer)
    if not oldContainer or not newContainer or not oldContainer.getItems then
        return
    end
    local items = oldContainer:getItems()
    if not items then
        return
    end
    local moved = {}
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            moved[#moved + 1] = item
        end
    end
    for i = 1, #moved do
        local item = moved[i]
        if oldContainer.Remove then
            oldContainer:Remove(item)
        end
        newContainer:AddItem(item)
    end
end

function IKST_EconomyOps.clearContainerItems(container)
    if not container or not container.getItems or not container.Remove then
        return 0
    end
    local items = container:getItems()
    if not items then
        return 0
    end
    local removed = 0
    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)
        if item then
            container:Remove(item)
            IKST_EconomyOps.syncRemove(container, item)
            removed = removed + 1
        end
    end
    if removed > 0 then
        IKST_EconomyOps.markDirty(container)
    end
    return removed
end

function IKST_EconomyOps.replaceShopContainer(obj, targetCap, migrateItems)
    if not obj or not ItemContainer or not ItemContainer.new then
        return false
    end
    local square = type(obj.getSquare) == "function" and obj:getSquare() or nil
    local oldContainer = type(obj.getContainer) == "function" and obj:getContainer() or nil
    if not square then
        return false
    end
    local md = obj:getModData() or {}
    if migrateItems == nil then
        migrateItems = md[IKST_Economy.SHOP_CONTAINER_UPGRADED] == true
    end
    local containerType = IKST_Economy.SHOP_CONTAINER_TYPE or "crate"
    local newContainer = ItemContainer.new(containerType, square, obj, 1, 1)
    if not newContainer then
        newContainer = ItemContainer.new(containerType, square, obj)
    end
    if not newContainer then
        return false
    end
    newContainer:setCapacity(targetCap)
    if newContainer.setExplored then
        newContainer:setExplored(true)
    end
    if migrateItems and oldContainer then
        IKST_EconomyOps.migrateContainerItems(oldContainer, newContainer)
    elseif oldContainer then
        IKST_EconomyOps.clearContainerItems(oldContainer)
    end
    obj:setContainer(newContainer)
    md[IKST_Economy.SHOP_CONTAINER_UPGRADED] = true
    return true
end

function IKST_EconomyOps.ensureShopContainerCapacity(obj)
    if not obj or type(obj.getContainer) ~= "function" then
        return false
    end
    local md = obj:getModData() or {}
    local container = obj:getContainer()
    if not container then
        return false
    end
    if md[IKST_Economy.SHOP_CONTAINER_UPGRADED] then
        if not IKST_EconomyOps.isLegacyShopContainerType(container) then
            return false
        end
    end
    local target = IKST_Economy.shopContainerCapacity()
    if not target or target <= 0 then
        return false
    end
    local replaced = false
    if IKST_EconomyOps.shopContainerNeedsUpgrade(container, target) then
        replaced = IKST_EconomyOps.replaceShopContainer(obj, target)
    else
        md[IKST_Economy.SHOP_CONTAINER_UPGRADED] = true
        obj:transmitModData()
    end
    if replaced then
        IKST_EconomyOps.transmitWorldObject(obj)
        shopPlaceLog("shop container ready cap=" .. tostring(target))
    end
    return replaced
end

function IKST_EconomyOps.hasShopSignOnSquare(square)
    if not square or not square.getObjects then
        return false
    end
    for i = 0, square:getObjects():size() - 1 do
        local obj = square:getObjects():get(i)
        if obj and type(obj.getModData) == "function" then
            local md = obj:getModData()
            if md and md[IKST_Economy.SHOP_SIGN_TAG] then
                return true
            end
        end
    end
    return false
end

function IKST_EconomyOps.findSignSquare(terminalSquare)
    if not terminalSquare or not terminalSquare.getAdjacentSquare or not IsoDirections then
        return nil
    end
    local dirs = {
        IsoDirections.N,
        IsoDirections.E,
        IsoDirections.S,
        IsoDirections.W,
    }
    for i = 1, #dirs do
        local adj = terminalSquare:getAdjacentSquare(dirs[i])
        if adj and type(adj.isSolidFloor) == "function" and adj:isSolidFloor() then
            if not IKST_EconomyOps.findShopTileOnSquare(adj) and not IKST_EconomyOps.hasShopSignOnSquare(adj) then
                return adj
            end
        end
    end
    return nil
end

function IKST_EconomyOps.trySpawnAtmSprite(square, spriteName)
    if not square or not spriteName or spriteName == "" then
        return nil, "empty sprite"
    end
    if IKST_DestroyServer and type(IKST_DestroyServer.allowSquare) == "function"
        and type(square.getX) == "function" then
        IKST_DestroyServer.allowSquare(square:getX(), square:getY(), square:getZ() or 0)
    end
    local tileSprite = getSprite and getSprite(spriteName) or nil
    if not tileSprite then
        return nil, "sprite not in tile defs: " .. spriteName
    end
    local obj = nil
    if square.addTileObject then
        obj = square:addTileObject(spriteName)
    end
    if not obj and IsoObject and IsoObject.new then
        obj = IsoObject.new(square, spriteName, nil, false)
        if obj and square.AddSpecialObject then
            square:AddSpecialObject(obj)
        end
    end
    if not obj then
        return nil, "could not instantiate: " .. spriteName
    end
    return obj, spriteName
end

function IKST_EconomyOps.enableAtmAt(player, x, y, z, cfg)
    cfg = cfg or {}
    IKST_Economy.setAtm(x, y, z, {
        deposit = cfg.deposit ~= false,
        withdraw = cfg.withdraw ~= false,
        valuables = cfg.valuables ~= false,
    })
    local sq = IKST_Grid.getSquare(x, y, z)
    if sq and sq.getObjects then
        for i = 0, sq:getObjects():size() - 1 do
            local obj = sq:getObjects():get(i)
            if obj and IKST_Economy.isAtmTileObject(obj) and type(obj.getModData) == "function" then
                local md = obj:getModData()
                md[IKST_Economy.ATM_TAG] = true
                if type(obj.transmitModData) == "function" then
                    obj:transmitModData()
                end
            end
        end
    end
    return true, "ATM enabled"
end

function IKST_EconomyOps.spawnAtmFixtureObject(square, placerName, player)
    if not square then
        return nil
    end
    local candidates = IKST_Economy.atmTerminalSpriteCandidates()
    local obj = nil
    local usedSprite = nil
    for i = 1, #candidates do
        local sprite = candidates[i]
        local reason = nil
        obj, reason = IKST_EconomyOps.trySpawnAtmSprite(square, sprite)
        if obj then
            usedSprite = reason
            break
        end
        IKST_EconomyOps.shopPlaceDebug(player, "atm place: " .. tostring(reason))
    end
    if not obj then
        IKST_EconomyOps.shopPlaceDebug(player,
            "atm place: failed — could not spawn vanilla ATM sprite")
        return nil
    end
    local md = obj:getModData()
    md[IKST_Economy.ATM_TAG] = true
    if placerName and placerName ~= "" then
        md[IKST_Economy.ATM_PLACER] = placerName
    end
    if obj.transmitModData then
        obj:transmitModData()
    end
    IKST_EconomyOps.transmitWorldObject(obj)
    local x = type(square.getX) == "function" and square:getX() or "?"
    local y = type(square.getY) == "function" and square:getY() or "?"
    local z = type(square.getZ) == "function" and square:getZ() or "?"
    IKST_EconomyOps.shopPlaceDebug(player,
        "atm place: fixture @" .. x .. "," .. y .. "," .. z .. " sprite=" .. tostring(usedSprite))
    return obj
end

function IKST_EconomyOps.findAtmKitItem(player, itemId)
    local inv = player and type(player.getInventory) == "function" and player:getInventory()
    if not inv then
        return nil
    end
    if itemId and inv.getItemById then
        local item = inv:getItemById(itemId)
        if item and type(item.getFullType) == "function" and item:getFullType() == IKST_Economy.ATM_KIT_TYPE then
            return item
        end
    end
    if inv.getFirstTypeRecurse then
        return inv:getFirstTypeRecurse(IKST_Economy.ATM_KIT_TYPE)
    end
    return nil
end

function IKST_EconomyOps.placeAtmTerminal(player, x, y, z, itemId)
    if not IKST_Access.canUseTools(player) then
        return false, "admin only"
    end
    if not IKST_Economy.playerNearCoord(player, x, y, z, IKST_Economy.shopMaxDistance() + 2) then
        return false, "too far"
    end
    local sq = IKST_Grid.getSquare(x, y, z)
    if not sq then
        return false, "bad square"
    end
    local blocked, reason = IKST_EconomyOps.placementBlocked(player, x, y, z)
    if blocked then
        return false, reason or "square protected"
    end
    if IKST_Economy.isAtmSquare(x, y, z) then
        return false, "ATM already enabled here"
    end
    if IKST_Economy.findAtmObjectOnSquare(sq) then
        return false, "use Enable ATM on the existing bank fixture"
    end
    local kit = IKST_EconomyOps.findAtmKitItem(player, itemId)
    if itemId and not kit then
        return false, "need ATM terminal kit"
    end
    local obj = IKST_EconomyOps.spawnAtmFixtureObject(sq, IKST_Economy.accountName(player), player)
    if not obj then
        return false, "could not place ATM"
    end
    IKST_EconomyOps.enableAtmAt(player, x, y, z, {
        deposit = true,
        withdraw = true,
        valuables = true,
    })
    if kit then
        local inv = player:getInventory()
        if inv and inv.Remove then
            inv:Remove(kit)
            IKST_EconomyOps.syncRemove(inv, kit)
            IKST_EconomyOps.markDirty(inv)
        end
    end
    return true, "ATM placed"
end

function IKST_EconomyOps.spawnDecorSprite(square, spriteName)
    if not square or not spriteName or spriteName == "" or not IsoObject or not IsoObject.new then
        return nil
    end
    local sign = IsoObject.new(square, spriteName, nil, false)
    if not sign then
        return nil
    end
    local md = sign:getModData()
    md[IKST_Economy.SHOP_SIGN_TAG] = true
    if sign.transmitModData then
        sign:transmitModData()
    end
    if square.AddSpecialObject then
        square:AddSpecialObject(sign)
    end
    IKST_EconomyOps.transmitWorldObject(sign)
    return sign
end

function IKST_EconomyOps.trySpawnTerminalSprite(square, spriteName)
    if not square or not spriteName or spriteName == "" then
        return nil, "empty sprite"
    end
    if IKST_DestroyServer and type(IKST_DestroyServer.allowSquare) == "function"
        and type(square.getX) == "function" then
        IKST_DestroyServer.allowSquare(square:getX(), square:getY(), square:getZ() or 0)
    end
    local tileSprite = getSprite and getSprite(spriteName) or nil
    if not tileSprite then
        return nil, "sprite not in tile defs: " .. spriteName
    end
    local obj = nil
    if square.addTileObject then
        obj = square:addTileObject(spriteName)
    end
    if not obj and IsoObject and IsoObject.new then
        obj = IsoObject.new(square, spriteName, nil, false)
        if obj and square.AddSpecialObject then
            square:AddSpecialObject(obj)
        end
    end
    if not obj then
        return nil, "could not instantiate: " .. spriteName
    end
    if not IKST_EconomyOps.objectHasShopContainer(obj) and obj.createContainersFromSpriteProperties then
        obj:createContainersFromSpriteProperties()
    end
    if not IKST_EconomyOps.objectHasShopContainer(obj) then
        if IKST_DestroyServer and type(IKST_DestroyServer.allowSquare) == "function"
            and type(square.getX) == "function" then
            IKST_DestroyServer.allowSquare(square:getX(), square:getY(), square:getZ() or 0)
        end
        if square.RemoveTileObject then
            square:RemoveTileObject(obj)
        elseif square.transmitRemoveItemFromSquare then
            square:transmitRemoveItemFromSquare(obj)
        end
        return nil, "no container after spawn: " .. spriteName
    end
    return obj, spriteName
end

function IKST_EconomyOps.spawnShopTerminalObject(square, placerName, player)
    if not square then
        IKST_EconomyOps.shopPlaceDebug(player, "shop place: missing square")
        return nil
    end
    local candidates = IKST_Economy.shopTerminalSpriteCandidates()
    local obj = nil
    local usedSprite = nil
    for i = 1, #candidates do
        local sprite = candidates[i]
        local reason = nil
        obj, reason = IKST_EconomyOps.trySpawnTerminalSprite(square, sprite)
        if obj then
            usedSprite = reason
            break
        end
        IKST_EconomyOps.shopPlaceDebug(player, "shop place: " .. tostring(reason))
    end
    if not obj then
        IKST_EconomyOps.shopPlaceDebug(player, "shop place: all terminal sprites failed")
        return nil
    end
    local md = obj:getModData()
    md[IKST_Economy.SHOP_TERMINAL_TAG] = true
    if placerName and placerName ~= "" then
        md[IKST_Economy.SHOP_PLACER] = placerName
    end
    if IKST_Economy.shopProtectEnabled() then
        md[IKST_Economy.VEND_PROTECT] = true
    end
    if obj.transmitModData then
        obj:transmitModData()
    end
    IKST_EconomyOps.ensureShopContainerCapacity(obj)
    local container = type(obj.getContainer) == "function" and obj:getContainer() or nil
    local cleared = IKST_EconomyOps.clearContainerItems(container)
    if cleared > 0 then
        IKST_EconomyOps.shopPlaceDebug(player, "shop place: cleared " .. tostring(cleared) .. " procedural item(s)")
    end
    IKST_EconomyOps.transmitWorldObject(obj)
    local signSquare = IKST_EconomyOps.findSignSquare(square) or square
    IKST_EconomyOps.spawnDecorSprite(signSquare, IKST_Economy.shopTerminalSignSprite())
    local x = type(square.getX) == "function" and square:getX() or "?"
    local y = type(square.getY) == "function" and square:getY() or "?"
    local z = type(square.getZ) == "function" and square:getZ() or "?"
    local cap = IKST_Economy.shopContainerCapacity()
    IKST_EconomyOps.shopPlaceDebug(player,
        "shop place: terminal @" .. x .. "," .. y .. "," .. z .. " sprite=" .. tostring(usedSprite) .. " cap=" .. tostring(cap))
    return obj
end

function IKST_EconomyOps.findShopKitItem(player, itemId)
    local inv = player and type(player.getInventory) == "function" and player:getInventory()
    if not inv then
        return nil
    end
    if itemId and inv.getItemById then
        local item = inv:getItemById(itemId)
        if item and type(item.getFullType) == "function" and item:getFullType() == IKST_Economy.SHOP_KIT_TYPE then
            return item
        end
    end
    if inv.getFirstTypeRecurse then
        return inv:getFirstTypeRecurse(IKST_Economy.SHOP_KIT_TYPE)
    end
    return nil
end

function IKST_EconomyOps.placeShopTerminal(player, x, y, z, itemId)
    if not IKST_Access.canUseEconomy(player) then
        return false, "unavailable"
    end
    if not IKST_Economy.playerNearCoord(player, x, y, z, IKST_Economy.shopMaxDistance() + 2) then
        return false, "too far"
    end
    local sq = IKST_Grid.getSquare(x, y, z)
    if not sq then
        return false, "bad square"
    end
    local blocked, reason = IKST_EconomyOps.placementBlocked(player, x, y, z)
    if blocked then
        return false, reason or "square protected"
    end
    if IKST_EconomyOps.findShopTileOnSquare(sq) then
        return false, "shop terminal already here"
    end
    local kit = IKST_EconomyOps.findShopKitItem(player, itemId)
    if not kit then
        return false, "need shop terminal kit"
    end
    local obj = IKST_EconomyOps.spawnShopTerminalObject(sq, IKST_Economy.accountName(player), player)
    if not obj then
        IKST_EconomyOps.shopPlaceDebug(player, "shop place: failed @" .. x .. "," .. y .. "," .. z)
        return false, "could not place terminal"
    end
    local inv = player:getInventory()
    if inv and inv.Remove then
        inv:Remove(kit)
        IKST_EconomyOps.syncRemove(inv, kit)
        IKST_EconomyOps.markDirty(inv)
    end
    IKST_EconomyOps.shopPlaceDebug(player, "shop place: kit consumed, ready to claim")
    return true, "shop terminal placed"
end
