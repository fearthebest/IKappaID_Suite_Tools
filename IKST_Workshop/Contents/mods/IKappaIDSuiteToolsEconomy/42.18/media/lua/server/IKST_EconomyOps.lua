if type(isClient) == "function" and isClient() and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_Access"
require "IKST_Economy"
require "IKST_EconomyBridge"
require "IKST_Identity"
require "IKST_Grid"
require "IKST_StaffOps"
require "IKST_WorldOps"

IKST_EconomyOps = IKST_EconomyOps or {}

local function syncAdd(inv, item)
    if item and sendAddItemToContainer then
        sendAddItemToContainer(inv, item)
    end
end

local function syncRemove(inv, item)
    if item and sendRemoveItemFromContainer then
        sendRemoveItemFromContainer(inv, item)
    end
end

local function markDirty(inv)
    if inv and inv.setDrawDirty then
        inv:setDrawDirty(true)
    end
end

function IKST_EconomyOps.findPlayerByUsername(username)
    if IKST_Identity and IKST_Identity.findPlayerByUsername then
        return IKST_Identity.findPlayerByUsername(username)
    end
    if not username or username == "" then
        return nil
    end
    local list = getOnlinePlayers and getOnlinePlayers()
    if not list or not list.size then
        return nil
    end
    for i = 0, list:size() - 1 do
        local p = list:get(i)
        if p and p.getUsername and p:getUsername() == username then
            return p
        end
    end
    return nil
end

function IKST_EconomyOps.findPlayerByAccountKey(key)
    if IKST_Identity and IKST_Identity.findPlayerByAccountKey then
        return IKST_Identity.findPlayerByAccountKey(key)
    end
    return nil
end

function IKST_EconomyOps.sendSnapshot(player, extra)
    local snap = IKST_Economy.snapshot(player)
    if extra then
        for k, v in pairs(extra) do
            snap[k] = v
        end
    end
    if IKST.deliverClientCommand then
        IKST.deliverClientCommand(player, IKST.CMD.economySnapshotResult, snap)
    end
end

function IKST_EconomyOps.sendVendList(player, x, y, z, entries)
    local payload = {
        x = x, y = y, z = z,
        entries = entries or {},
        owner = IKST_EconomyOps.vendOwnerAt(x, y, z),
    }
    if IKST.deliverClientCommand then
        IKST.deliverClientCommand(player, IKST.CMD.economyVendListResult, payload)
    end
end

function IKST_EconomyOps.bankGate(player, x, y, z, action)
    if IKST_Economy.atmRequiredForBank() and not IKST_Economy.isAtmSquare(x, y, z) then
        return false, "use an ATM"
    end
    if IKST_Economy.isAtmSquare(x, y, z) and not IKST_Economy.atmAllows(x, y, z, action) then
        return false, "ATM action disabled"
    end
    if not IKST_Economy.playerNearCoord(player, x, y, z, IKST_Economy.shopMaxDistance() + 2) then
        return false, "too far"
    end
    if IKST_Economy.idCardBanking and IKST_Economy.idCardBanking() then
        if not IKST_Identity.hasValidIdCard(player) then
            return false, "present your bank ID card"
        end
    end
    return true
end

function IKST_EconomyOps.findShopTileOnSquare(sq)
    if not sq or not sq.getObjects then
        return nil
    end
    local anyContainer = nil
    for i = 0, sq:getObjects():size() - 1 do
        local obj = sq:getObjects():get(i)
        if obj and obj.getContainer and obj:getContainer() then
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
    return obj and obj.getContainer and obj:getContainer() ~= nil
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
    if container.getType and container:getType() == "fridge" and container.getCapacity then
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
            syncRemove(container, item)
            removed = removed + 1
        end
    end
    if removed > 0 then
        markDirty(container)
    end
    return removed
end

function IKST_EconomyOps.replaceShopContainer(obj, targetCap, migrateItems)
    if not obj or not ItemContainer or not ItemContainer.new then
        return false
    end
    local square = obj.getSquare and obj:getSquare() or nil
    local oldContainer = obj.getContainer and obj:getContainer() or nil
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
    if not obj or not obj.getContainer then
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
        if obj and obj.getModData then
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
        if adj and adj.isSolidFloor and adj:isSolidFloor() then
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
            if obj and IKST_Economy.isAtmTileObject(obj) and obj.getModData then
                local md = obj:getModData()
                md[IKST_Economy.ATM_TAG] = true
                if obj.transmitModData then
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
            "atm place: failed — enable IKappaID Suite Tools - World Edit (Tiles) so ikst_economy_01 sprites load")
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
    local x = square.getX and square:getX() or "?"
    local y = square.getY and square:getY() or "?"
    local z = square.getZ and square:getZ() or "?"
    IKST_EconomyOps.shopPlaceDebug(player,
        "atm place: fixture @" .. x .. "," .. y .. "," .. z .. " sprite=" .. tostring(usedSprite))
    return obj
end

function IKST_EconomyOps.findAtmKitItem(player, itemId)
    local inv = player and player.getInventory and player:getInventory()
    if not inv then
        return nil
    end
    if itemId and inv.getItemById then
        local item = inv:getItemById(itemId)
        if item and item.getFullType and item:getFullType() == IKST_Economy.ATM_KIT_TYPE then
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
            syncRemove(inv, kit)
            markDirty(inv)
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
    local container = obj.getContainer and obj:getContainer() or nil
    local cleared = IKST_EconomyOps.clearContainerItems(container)
    if cleared > 0 then
        IKST_EconomyOps.shopPlaceDebug(player, "shop place: cleared " .. tostring(cleared) .. " procedural item(s)")
    end
    IKST_EconomyOps.transmitWorldObject(obj)
    local signSquare = IKST_EconomyOps.findSignSquare(square) or square
    IKST_EconomyOps.spawnDecorSprite(signSquare, IKST_Economy.shopTerminalSignSprite())
    local x = square.getX and square:getX() or "?"
    local y = square.getY and square:getY() or "?"
    local z = square.getZ and square:getZ() or "?"
    local cap = IKST_Economy.shopContainerCapacity()
    IKST_EconomyOps.shopPlaceDebug(player,
        "shop place: terminal @" .. x .. "," .. y .. "," .. z .. " sprite=" .. tostring(usedSprite) .. " cap=" .. tostring(cap))
    return obj
end

function IKST_EconomyOps.findShopKitItem(player, itemId)
    local inv = player and player.getInventory and player:getInventory()
    if not inv then
        return nil
    end
    if itemId and inv.getItemById then
        local item = inv:getItemById(itemId)
        if item and item.getFullType and item:getFullType() == IKST_Economy.SHOP_KIT_TYPE then
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
        syncRemove(inv, kit)
        markDirty(inv)
    end
    IKST_EconomyOps.shopPlaceDebug(player, "shop place: kit consumed, ready to claim")
    return true, "shop terminal placed"
end

function IKST_EconomyOps.findVendObject(x, y, z)
    local sq = IKST_Grid.getSquare(x, y, z)
    if not sq or not sq.getObjects then
        return nil
    end
    for i = 0, sq:getObjects():size() - 1 do
        local obj = sq:getObjects():get(i)
        if obj and obj.getContainer and obj:getContainer() then
            local md = obj.getModData and obj:getModData()
            if md and md[IKST_Economy.VEND_TAG] then
                return obj
            end
        end
    end
    return nil
end

function IKST_EconomyOps.vendOwnerAt(x, y, z)
    local obj = IKST_EconomyOps.findVendObject(x, y, z)
    if not obj then
        return nil
    end
    local md = obj:getModData()
    return md and md[IKST_Economy.VEND_OWNER]
end

function IKST_EconomyOps.collectVendList(x, y, z, includeAll)
    local obj = IKST_EconomyOps.findVendObject(x, y, z)
    if not obj then
        return {}
    end
    local container = obj:getContainer()
    if not container or not container.getItems then
        return {}
    end
    local shopMd = obj:getModData() or {}
    local items = container:getItems()
    local groups = {}
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and item.getFullType and item.getID then
            local itemType = item:getFullType()
            local price = IKST_Economy.effectiveVendPrice(shopMd, item)
            if includeAll then
                local label = item.getDisplayName and item:getDisplayName() or itemType
                table.insert(groups, {
                    itemType = itemType,
                    itemId = item:getID(),
                    label = label .. IKST_Economy.freshnessSuffix(item),
                    price = price,
                    count = IKST_Economy.itemCount(item),
                    sellable = IKST_Economy.canSellInShop(item),
                })
            else
                local groupKey = IKST_Economy.vendListGroupKey(item, itemType)
                local row = groups[groupKey]
                if not row then
                    local label = item.getDisplayName and item:getDisplayName() or itemType
                    row = {
                        itemType = itemType,
                        itemId = item:getID(),
                        label = label .. IKST_Economy.freshnessSuffix(item),
                        price = price,
                        count = 0,
                        sellable = IKST_Economy.canSellInShop(item),
                    }
                    groups[groupKey] = row
                end
                row.count = row.count + IKST_Economy.itemCount(item)
                if price > row.price then
                    row.price = price
                end
                if not row.itemId then
                    row.itemId = item:getID()
                end
                if IKST_Economy.canSellInShop(item) then
                    row.sellable = true
                end
            end
        end
    end
    local out = {}
    if includeAll then
        for _, row in ipairs(groups) do
            table.insert(out, row)
        end
    else
        for _, row in pairs(groups) do
            if row.price > 0 and row.sellable ~= false then
                table.insert(out, row)
            end
        end
    end
    table.sort(out, function(a, b)
        return tostring(a.label) < tostring(b.label)
    end)
    return out
end

function IKST_EconomyOps.findItemByType(container, itemType)
    return IKST_EconomyOps.findSellableItem(container, itemType, nil)
end

function IKST_EconomyOps.findSellableItem(container, itemType, itemId)
    if not container then
        return nil
    end
    if itemId then
        local byId = IKST_EconomyOps.findItemInContainer(container, itemId)
        if byId and IKST_Economy.canSellInShop(byId) then
            return byId
        end
        return nil
    end
    if not itemType or itemType == "" then
        return nil
    end
    local items = container.getItems and container:getItems()
    if not items then
        return nil
    end
    local best = nil
    local bestAge = -1
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and item.getFullType and item:getFullType() == itemType and IKST_Economy.canSellInShop(item) then
            local age = item.getAge and tonumber(item:getAge()) or 0
            if age >= bestAge then
                bestAge = age
                best = item
            end
        end
    end
    return best
end

function IKST_EconomyOps.splitOneFromStack(item)
    if not item or not item.getFullType or not instanceItem then
        return nil
    end
    local count = IKST_Economy.itemCount(item)
    if count <= 1 then
        return nil
    end
    local one = instanceItem(item:getFullType())
    if not one then
        return nil
    end
    if instanceof and instanceof(item, "Food") and one.copyFoodFromSplit then
        one:copyFoodFromSplit(item, 1)
    else
        item:setCount(count - 1)
        if one.setCount then
            one:setCount(1)
        end
        if one.inheritFoodAgeFrom then
            one:inheritFoodAgeFrom(item)
        elseif one.setAge and item.getAge then
            one:setAge(item:getAge())
        end
        if item.syncItemFields then
            item:syncItemFields()
        end
    end
    if one.syncItemFields then
        one:syncItemFields()
    end
    return one
end

function IKST_EconomyOps.clearLegacyItemPrices(container, itemType)
    if not container or not itemType or not container.getItems then
        return
    end
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and item.getFullType and item:getFullType() == itemType and item.getModData then
            local md = item:getModData()
            md[IKST_Economy.VEND_PRICE] = nil
            if item.syncItemFields then
                item:syncItemFields()
            end
        end
    end
end

function IKST_EconomyOps.transferOneToPlayer(container, player, item)
    if not container or not player or not item then
        return false
    end
    local inv = player:getInventory()
    if not inv then
        return false
    end
    if not IKST_Economy.canSellInShop(item) then
        return false
    end
    local count = IKST_Economy.itemCount(item)
    if count <= 1 then
        container:Remove(item)
        syncRemove(container, item)
        inv:AddItem(item)
        syncAdd(inv, item)
        markDirty(container)
        markDirty(inv)
        return true
    end
    local one = IKST_EconomyOps.splitOneFromStack(item)
    if not one then
        return false
    end
    inv:AddItem(one)
    syncAdd(inv, one)
    markDirty(container)
    markDirty(inv)
    if item.syncItemFields then
        item:syncItemFields()
    end
    return true
end

function IKST_EconomyOps.findItemInContainer(container, itemId)
    if not container or not itemId then
        return nil
    end
    local items = container.getItems and container:getItems()
    if not items then
        return nil
    end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and item.getID and item:getID() == itemId then
            return item
        end
    end
    return nil
end

function IKST_EconomyOps.creditSeller(sellerKey, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or not sellerKey or sellerKey == "" then
        return
    end
    if not IKST_Identity.isAccountKey(sellerKey) then
        sellerKey = IKST_Identity.keyForLegacyName(sellerKey) or sellerKey
    end
    local online = IKST_EconomyOps.findPlayerByAccountKey(sellerKey)
    if online then
        IKST_Economy.addBank(online, amount)
        return
    end
    IKST_Economy.addPending(sellerKey, amount)
end

function IKST_EconomyOps.applyTax(amount)
    local pct = IKST_Economy.salesTaxPercent()
    if pct <= 0 then
        return 0
    end
    local tax = math.floor(amount * pct / 100)
    if tax <= 0 then
        return 0
    end
    local receiver = IKST_Economy.taxReceiver()
    local store = IKST_Economy.getStore()
    if receiver and store then
        local row = store.accounts[receiver]
        if not row then
            row = { bank = 0, pending = 0 }
            store.accounts[receiver] = row
        end
        row.bank = math.floor((tonumber(row.bank) or 0) + tax)
    elseif store then
        store.taxPool = math.floor((tonumber(store.taxPool) or 0) + tax)
    end
    IKST_Economy.persistStore()
    return tax
end

function IKST_EconomyOps.deposit(player, amount, x, y, z)
    amount = IKST.parseAmount(amount)
    if amount <= 0 then
        return false, "invalid amount"
    end
    local gateOk, gateMsg = IKST_EconomyOps.bankGate(player, x, y, z, "deposit")
    if not gateOk then
        return false, gateMsg or "use an ATM to deposit"
    end
    if IKST_Economy.idCardBanking and IKST_Economy.idCardBanking() then
        return false, "funds are already in your bank account"
    end
    local ok, err = IKST_EconomyBridge.payCash(player, amount)
    if not ok then
        return false, err or "not enough cash"
    end
    IKST_Economy.addBank(player, amount)
    return true, "Deposited " .. IKST_Economy.formatAmount(amount)
end

function IKST_EconomyOps.withdraw(player, amount, x, y, z)
    amount = IKST.parseAmount(amount)
    if amount <= 0 then
        return false, "invalid amount"
    end
    local gateOk, gateMsg = IKST_EconomyOps.bankGate(player, x, y, z, "withdraw")
    if not gateOk then
        return false, gateMsg or "use an ATM to withdraw"
    end
    if IKST_Economy.idCardBanking and IKST_Economy.idCardBanking() then
        return false, "withdraw disabled — use wire or shop"
    end
    if not IKST_Economy.takeBank(player, amount) then
        return false, "not enough in bank"
    end
    if not IKST_EconomyBridge.giveCash(player, amount) then
        IKST_Economy.addBank(player, amount)
        return false, "could not give cash"
    end
    return true, "Withdrew " .. IKST_Economy.formatAmount(amount)
end

function IKST_EconomyOps.wire(player, targetId, amount)
    amount = IKST.parseAmount(amount)
    if amount <= 0 then
        return false, "invalid amount"
    end
    local minAmt = IKST_Economy.wireMinAmount()
    if amount < minAmt then
        return false, "amount below minimum"
    end
    local target = IKST_StaffOps.findPlayerByOnlineID(targetId)
    if not target then
        return false, "player not found"
    end
    if target == player then
        return false, "cannot wire yourself"
    end
    local dist = IKST_Economy.wireMaxDistance()
    if not IKST_Economy.playerNearCoord(player, target:getX(), target:getY(), target:getZ(), dist) then
        return false, "too far to wire cash"
    end
    local feePct = IKST_Economy.wireFeePercent()
    local fee = math.floor(amount * feePct / 100)
    local receive = amount - fee
    if receive <= 0 then
        return false, "fee exceeds amount"
    end
    if IKST_Economy.idCardBanking and IKST_Economy.idCardBanking() then
        if not IKST_Economy.takeBank(player, amount) then
            return false, "not enough in bank"
        end
        IKST_Economy.addBank(target, receive)
    else
        local ok, err = IKST_EconomyBridge.payCash(player, amount)
        if not ok then
            return false, err or "not enough cash"
        end
        if not IKST_EconomyBridge.giveCash(target, receive) then
            IKST_EconomyBridge.giveCash(player, amount)
            return false, "wire failed"
        end
    end
    if fee > 0 then
        local store = IKST_Economy.getStore()
        if store then
            store.taxPool = math.floor((tonumber(store.taxPool) or 0) + fee)
            IKST_Economy.persistStore()
        end
    end
    local label = IKST_StaffOps.playerLabel and IKST_StaffOps.playerLabel(target) or "player"
    local msg = "Wired " .. IKST_Economy.formatAmount(receive) .. " to " .. label
    if fee > 0 then
        msg = msg .. " (fee " .. IKST_Economy.formatAmount(fee) .. ")"
    end
    return true, msg
end

function IKST_EconomyOps.countPlayerItems(player, itemType)
    return IKST_Economy.countPlayerItems(player, itemType)
end

function IKST_EconomyOps.removeAllPlayerItems(player, itemType)
    if not player or not itemType then
        return 0
    end
    local inv = player:getInventory()
    if not inv then
        return 0
    end
    local removed = 0
    local function removeOne(item)
        if not item then
            return
        end
        local container = item.getContainer and item:getContainer() or inv
        local n = IKST_Economy.itemCount(item)
        container:Remove(item)
        syncRemove(container, item)
        removed = removed + n
    end
    if inv.getItemsFromTypeRecurse then
        local items = inv:getItemsFromTypeRecurse(itemType, true)
        if items then
            for i = items:size() - 1, 0, -1 do
                removeOne(items:get(i))
            end
        end
    elseif inv.getItems then
        local items = inv:getItems()
        for i = items:size() - 1, 0, -1 do
            local item = items:get(i)
            if item and item.getFullType and item:getFullType() == itemType then
                removeOne(item)
            end
        end
    end
    if removed > 0 then
        markDirty(inv)
    end
    return removed
end

function IKST_EconomyOps.playerIdCardReissue(player, x, y, z)
    if not IKST_Economy.idCardBanking or not IKST_Economy.idCardBanking() then
        return false, "ID card banking is off"
    end
    if not IKST_Economy.idCardPlayerReissue or not IKST_Economy.idCardPlayerReissue() then
        return false, "bank ID replacement disabled"
    end
    if not IKST_Economy.isAtmSquare(x, y, z) then
        return false, "use an ATM to replace your bank ID"
    end
    if not IKST_Economy.atmAllows(x, y, z, "deposit") and not IKST_Economy.atmAllows(x, y, z, "withdraw") then
        return false, "ATM cannot replace bank ID"
    end
    local remain = IKST_Economy.idCardReissueCooldownRemainMs(player)
    if remain > 0 then
        local hours = math.ceil(remain / 3600000)
        return false, "wait " .. tostring(hours) .. "h before replacing bank ID again"
    end
    local fee = IKST_Economy.idCardReissueFee()
    if fee > 0 then
        if not IKST_Economy.takeBank(player, fee) then
            return false, "need " .. IKST_Economy.formatAmount(fee) .. " in bank for replacement fee"
        end
    end
    local ok, msg = IKST_Identity.reissueIdCard(player, { recordCooldown = true, bumpSerial = true, notifyPlayer = true })
    if not ok and fee > 0 then
        IKST_Economy.addBank(player, fee)
    end
    if ok then
        local out = "Bank ID replaced"
        if fee > 0 then
            out = out .. " (fee " .. IKST_Economy.formatAmount(fee) .. ")"
        end
        return true, out
    end
    return false, msg or "replacement failed"
end

function IKST_EconomyOps.exchangeGate(player, x, y, z)
    if IKST_Economy.atmRequiredForBank() and not IKST_Economy.isAtmSquare(x, y, z) then
        return false, "use an ATM"
    end
    if not IKST_Economy.atmAllows(x, y, z, "valuables") then
        return false, "ATM cannot exchange valuables"
    end
    if IKST_Economy.idCardBanking and IKST_Economy.idCardBanking() then
        if not IKST_Identity.hasValidIdCard(player) then
            return false, "present your bank ID card"
        end
    end
    return true
end

function IKST_EconomyOps.exchange(player, itemType, x, y, z)
    if not IKST_Economy.valuablesEnabled() then
        return false, "valuables exchange disabled"
    end
    local gateOk, gateMsg = IKST_EconomyOps.exchangeGate(player, x, y, z)
    if not gateOk then
        return false, gateMsg
    end
    local entry = IKST_Economy.valuableEntry(itemType)
    if not entry then
        return false, "not a valuable"
    end
    if not PhoneShop.findItem or not IKST_EconomyBridge.giveCash then
        return false, "PhoneShop missing"
    end
    local inv, item = PhoneShop.findItem(player, itemType)
    if not inv or not item then
        return false, "item not found"
    end
    local count = IKST_Economy.itemCount(item)
    local payout = entry.price * count
    inv:Remove(item)
    syncRemove(inv, item)
    markDirty(player:getInventory())
    if not IKST_EconomyBridge.giveCash(player, payout) then
        if inv:AddItem(item) then
            markDirty(inv)
        elseif count > 1 and inv.AddItems then
            inv:AddItems(itemType, count)
            markDirty(inv)
        else
            inv:AddItem(itemType)
            markDirty(inv)
        end
        return false, "payout failed"
    end
    return true, "Exchanged for " .. IKST_Economy.formatAmount(payout)
end

function IKST_EconomyOps.exchangeAll(player, x, y, z)
    if not IKST_Economy.valuablesEnabled() then
        return false, "valuables exchange disabled"
    end
    local gateOk, gateMsg = IKST_EconomyOps.exchangeGate(player, x, y, z)
    if not gateOk then
        return false, gateMsg
    end
    if not IKST_EconomyBridge.giveCash then
        return false, "PhoneShop missing"
    end
    local data = IKST_Economy.loadValuables()
    local totalPayout = 0
    local totalItems = 0
    for _, entry in ipairs(data.list) do
        local n = IKST_EconomyOps.removeAllPlayerItems(player, entry.itemType)
        if n > 0 then
            totalItems = totalItems + n
            totalPayout = totalPayout + (n * entry.price)
        end
    end
    if totalItems <= 0 then
        return false, "no valuables in inventory"
    end
    if not IKST_EconomyBridge.giveCash(player, totalPayout) then
        return false, "payout failed"
    end
    return true, "Sold " .. tostring(totalItems) .. " items for " .. IKST_Economy.formatAmount(totalPayout)
end

function IKST_EconomyOps.vendClaim(player, x, y, z)
    if not IKST_Economy.playerNearCoord(player, x, y, z, IKST_Economy.shopMaxDistance()) then
        return false, "too far from shop terminal"
    end
    local sq = IKST_Grid.getSquare(x, y, z)
    if not sq then
        return false, "bad square"
    end
    local obj = IKST_EconomyOps.findShopTileOnSquare(sq)
    if not obj then
        if IKST_Economy.shopTilesRequired() then
            return false, "use a shop terminal tile (vending machine)"
        end
        return false, "no shop terminal here"
    end
    if IKST_Economy.isVendObject(obj) then
        local owner = IKST_Economy.vendOwnerOfObject(obj)
        if owner and owner ~= "" then
            if IKST_Identity.playerOwnsKey(player, owner) then
                return false, "you already own this shop"
            end
            return false, "shop already claimed by someone else"
        end
    end
    local ok, msg = IKST_EconomyOps.vendEnable(player, x, y, z, IKST_Economy.accountName(player))
    if ok then
        return true, "shop opened"
    end
    return ok, msg
end

function IKST_EconomyOps.vendEnable(player, x, y, z, ownerName)
    local sq = IKST_Grid.getSquare(x, y, z)
    if not sq then
        return false, "bad square"
    end
    local obj = IKST_EconomyOps.findShopTileOnSquare(sq)
    if not obj then
        if IKST_Economy.shopTilesRequired() then
            return false, "use a shop terminal tile (vending machine)"
        end
        return false, "no container here"
    end
    local md = obj:getModData()
    md[IKST_Economy.VEND_TAG] = true
    md[IKST_Economy.VEND_OWNER] = ownerName or IKST_Economy.accountName(player)
    if IKST_Economy.shopProtectEnabled() then
        md[IKST_Economy.VEND_PROTECT] = true
    end
    IKST_EconomyOps.ensureShopContainerCapacity(obj)
    if obj.transmitModData then
        obj:transmitModData()
    end
    return true, "Shop terminal enabled"
end

function IKST_EconomyOps.vendDisable(player, x, y, z)
    if not IKST_Economy.playerNearCoord(player, x, y, z, IKST_Economy.shopMaxDistance() + 2) then
        return false, "too far"
    end
    local obj = IKST_EconomyOps.findVendObject(x, y, z)
    if not obj then
        return false, "not a shop"
    end
    local md = obj:getModData()
    md[IKST_Economy.VEND_TAG] = nil
    md[IKST_Economy.VEND_OWNER] = nil
    md[IKST_Economy.VEND_PRICES] = nil
    md[IKST_Economy.VEND_PROTECT] = nil
    if obj.transmitModData then
        obj:transmitModData()
    end
    return true, "Shop disabled"
end

function IKST_EconomyOps.applyStackPrice(item, price)
    if not item or not item.getModData then
        return false
    end
    local md = item:getModData()
    if price <= 0 then
        md[IKST_Economy.VEND_PRICE] = nil
    else
        md[IKST_Economy.VEND_PRICE] = price
    end
    if item.syncItemFields then
        item:syncItemFields()
    end
    return true
end

function IKST_EconomyOps.applyTypePrice(shopMd, container, itemType, price)
    if not shopMd or not itemType or itemType == "" then
        return false
    end
    local catalog = IKST_Economy.getShopPriceTable(shopMd)
    if price <= 0 then
        catalog[itemType] = nil
    else
        catalog[itemType] = price
    end
    if container and container.getItems then
        local items = container:getItems()
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if item and item.getFullType and item:getFullType() == itemType and item.getModData then
                item:getModData()[IKST_Economy.VEND_PRICE] = nil
                if item.syncItemFields then
                    item:syncItemFields()
                end
            end
        end
    end
    IKST_EconomyOps.clearLegacyItemPrices(container, itemType)
    return true
end

function IKST_EconomyOps.vendSetPrice(player, x, y, z, args)
    args = args or {}
    if not IKST_Economy.playerNearCoord(player, x, y, z, IKST_Economy.shopMaxDistance() + 2) then
        return false, "too far"
    end
    local price = math.floor(tonumber(args.price) or 0)
    if price < 0 or price > IKST_Economy.maxVendPrice() then
        return false, "invalid price"
    end
    local scope = args.scope or "type"
    local obj = IKST_EconomyOps.findVendObject(x, y, z)
    if not obj then
        return false, "not a shop"
    end
    local owner = IKST_EconomyOps.vendOwnerAt(x, y, z)
    local me = IKST_Economy.accountName(player)
    if owner and not IKST_Identity.playerOwnsKey(player, owner) and not IKST_Access.canUseTools(player) then
        return false, "not your shop"
    end
    local container = obj:getContainer()
    local shopMd = obj:getModData() or {}
    local itemId = args.itemId
    local itemType = args.itemType
    local itemIds = args.itemIds
    local touched = 0

    if scope == "one" then
        local item = IKST_EconomyOps.findItemInContainer(container, itemId)
        if not item and itemType and itemType ~= "" then
            item = IKST_EconomyOps.findSellableItem(container, itemType, itemId)
        end
        if not item then
            return false, "pick a stock row"
        end
        if price <= 0 then
            IKST_EconomyOps.applyStackPrice(item, 0)
            return true, "Price cleared for stack"
        end
        IKST_EconomyOps.applyStackPrice(item, price)
        if obj.transmitModData then
            obj:transmitModData()
        end
        return true, "Price set for 1 stack: " .. IKST_Economy.formatAmount(price)
    end

    if scope == "selected" then
        if type(itemIds) ~= "table" or #itemIds == 0 then
            return false, "pick one or more stock rows"
        end
        for i = 1, #itemIds do
            local item = IKST_EconomyOps.findItemInContainer(container, itemIds[i])
            if item then
                if price <= 0 then
                    IKST_EconomyOps.applyStackPrice(item, 0)
                else
                    IKST_EconomyOps.applyStackPrice(item, price)
                end
                touched = touched + 1
            end
        end
        if touched <= 0 then
            return false, "selected stock not found"
        end
        if obj.transmitModData then
            obj:transmitModData()
        end
        if price <= 0 then
            return true, "Cleared price on " .. tostring(touched) .. " stacks"
        end
        return true, "Price set on " .. tostring(touched) .. " stacks: " .. IKST_Economy.formatAmount(price)
    end

    if scope == "all" then
        local types = {}
        if container and container.getItems then
            local items = container:getItems()
            for i = 0, items:size() - 1 do
                local item = items:get(i)
                if item and item.getFullType then
                    types[item:getFullType()] = true
                end
            end
        end
        for t, _ in pairs(types) do
            IKST_EconomyOps.applyTypePrice(shopMd, container, t, price)
            touched = touched + 1
        end
        if touched <= 0 then
            return false, "shop is empty"
        end
        if obj.transmitModData then
            obj:transmitModData()
        end
        if price <= 0 then
            return true, "Cleared prices on all stocked types"
        end
        return true, "Price set on all stocked types (" .. tostring(touched) .. "): " .. IKST_Economy.formatAmount(price)
    end

    if not itemType or itemType == "" then
        local item = IKST_EconomyOps.findItemInContainer(container, itemId)
        if item and item.getFullType then
            itemType = item:getFullType()
        end
    end
    if not itemType or itemType == "" then
        return false, "pick an item type"
    end
    if not IKST_EconomyOps.findItemByType(container, itemType) then
        return false, "item not in shop"
    end
    IKST_EconomyOps.applyTypePrice(shopMd, container, itemType, price)
    if obj.transmitModData then
        obj:transmitModData()
    end
    return true, price > 0
        and ("Price set for all " .. itemType .. ": " .. IKST_Economy.formatAmount(price))
        or "Price cleared for " .. itemType
end

function IKST_EconomyOps.vendBuy(player, x, y, z, itemId, itemType)
    if not IKST_Economy.playerNearCoord(player, x, y, z, IKST_Economy.shopMaxDistance()) then
        return false, "too far from shop"
    end
    local obj = IKST_EconomyOps.findVendObject(x, y, z)
    if not obj then
        return false, "not a shop"
    end
    local container = obj:getContainer()
    local shopMd = obj:getModData() or {}
    local item = nil
    if itemId then
        item = IKST_EconomyOps.findSellableItem(container, itemType, itemId)
    end
    if not item and itemType and itemType ~= "" then
        item = IKST_EconomyOps.findSellableItem(container, itemType, nil)
    end
    if not item then
        return false, "sold out or rotten"
    end
    if not itemType or itemType == "" then
        itemType = item:getFullType()
    end
    local price = IKST_Economy.effectiveVendPrice(shopMd, item)
    if price <= 0 then
        return false, "not for sale — owner must set a price"
    end
    local seller = IKST_EconomyOps.vendOwnerAt(x, y, z)
    if seller and IKST_Identity.playerOwnsKey(player, seller) then
        return false, "cannot buy your own listing"
    end
    if not IKST_EconomyBridge.canAfford(player, price) then
        return false, "not enough money (cash + bank)"
    end
    local okPay, err = IKST_EconomyBridge.pay(player, price)
    if not okPay then
        return false, err or "cannot pay"
    end
    if not IKST_EconomyOps.transferOneToPlayer(container, player, item) then
        IKST_EconomyBridge.giveCash(player, price)
        return false, "could not take item from shop"
    end
    local tax = IKST_EconomyOps.applyTax(price)
    local payout = price - tax
    IKST_EconomyOps.creditSeller(seller, payout)
    return true, "Purchased 1 for " .. IKST_Economy.formatAmount(price)
end

function IKST_EconomyOps.configureAtm(player, x, y, z, cfg)
    if not IKST_Access.canUseTools(player) then
        return false, "admin only"
    end
    local sq = IKST_Grid.getSquare(x, y, z)
    if not sq then
        return false, "bad square"
    end
    if IKST_Economy.isAtmSquare(x, y, z) then
        return IKST_EconomyOps.enableAtmAt(player, x, y, z, cfg)
    end
    if not IKST_Economy.findAtmObjectOnSquare(sq) then
        return false, "no bank ATM fixture on this square"
    end
    return IKST_EconomyOps.enableAtmAt(player, x, y, z, cfg)
end

function IKST_EconomyOps.handle(command, player, args)
    if not IKST_Economy.isEnabled() then
        return false, "economy disabled or PhoneShop missing"
    end
    args = args or {}
    local x = math.floor(tonumber(args.x) or player:getX())
    local y = math.floor(tonumber(args.y) or player:getY())
    local z = math.floor(tonumber(args.z) or player:getZ())

    if command == IKST.CMD.economySnapshot then
        IKST_EconomyOps.sendSnapshot(player)
        return true, "ok"
    end

    if command == IKST.CMD.economyDeposit then
        return IKST_EconomyOps.deposit(player, args.amount, x, y, z)
    end
    if command == IKST.CMD.economyWithdraw then
        return IKST_EconomyOps.withdraw(player, args.amount, x, y, z)
    end
    if command == IKST.CMD.economyWire then
        return IKST_EconomyOps.wire(player, args.target, args.amount)
    end
    if command == IKST.CMD.economyExchange then
        return IKST_EconomyOps.exchange(player, args.itemType, x, y, z)
    end
    if command == IKST.CMD.economyExchangeAll then
        return IKST_EconomyOps.exchangeAll(player, x, y, z)
    end
    if command == IKST.CMD.economyIdCardReissue then
        return IKST_EconomyOps.playerIdCardReissue(player, x, y, z)
    end
    if command == IKST.CMD.economyVendList then
        if not IKST_Economy.playerNearCoord(player, x, y, z, IKST_Economy.shopMaxDistance()) then
            return false, "too far"
        end
        IKST_EconomyOps.sendVendList(player, x, y, z, IKST_EconomyOps.collectVendList(x, y, z, args.manage == true))
        return true, "listed"
    end
    if command == IKST.CMD.economyVendBuy then
        return IKST_EconomyOps.vendBuy(player, x, y, z, args.itemId, args.itemType)
    end
    if command == IKST.CMD.economyVendSetPrice then
        return IKST_EconomyOps.vendSetPrice(player, x, y, z, args)
    end
    if command == IKST.CMD.economyVendClaim then
        return IKST_EconomyOps.vendClaim(player, x, y, z)
    end
    if command == IKST.CMD.economyShopPlace then
        return IKST_EconomyOps.placeShopTerminal(player, x, y, z, args.itemId)
    end
    if command == IKST.CMD.economyVendEnable then
        if not IKST_Access.canUseStaffTools(player) then
            return false, "admin only"
        end
        local ownerKey = args.owner
        if ownerKey and ownerKey ~= "" then
            local found = IKST_Identity.findPlayerByUsername(ownerKey)
            if not found then
                found = IKST_Identity.findPlayerByAccountKey(ownerKey)
            end
            if found then
                ownerKey = IKST_Identity.accountKey(found)
            else
                ownerKey = IKST_Identity.resolveWhitelistKey(ownerKey)
            end
        else
            ownerKey = IKST_Economy.accountName(player)
        end
        return IKST_EconomyOps.vendEnable(player, x, y, z, ownerKey)
    end
    if command == IKST.CMD.economyVendDisable then
        local owner = IKST_EconomyOps.vendOwnerAt(x, y, z)
        if owner and not IKST_Identity.playerOwnsKey(player, owner) and not IKST_Access.canUseTools(player) then
            return false, "not your shop"
        end
        return IKST_EconomyOps.vendDisable(player, x, y, z)
    end
    if command == IKST.CMD.economyAtmConfigure then
        return IKST_EconomyOps.configureAtm(player, x, y, z, args)
    end
    if command == IKST.CMD.economyAtmPlace then
        return IKST_EconomyOps.placeAtmTerminal(player, x, y, z, args.itemId)
    end

    return false, "unknown economy command"
end
