if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISInventoryPane"
require "TimedActions/ISGrabItemAction"
require "TimedActions/ISInventoryTransferAction"
require "IKST_Shared"
require "IKST_ContainerRules"
require "IKST_TransferRules"
require "IKST_TileCheck"
require "IKST_Access"
require "IKST_Chrome"

IKST_GuardHooks = IKST_GuardHooks or {}
IKST_GuardHooks._shApplied = IKST_GuardHooks._shApplied or {}
IKST_GuardHooks._shLastTick = 0
IKST_GuardHooks._shBorderOn = false
IKST_GuardHooks._shBordersSnapshot = false
IKST_GuardHooks._shBordersSynced = false
IKST_GuardHooks.SH_THROTTLE_MS = 400
IKST_GuardHooks.SH_VIEW_RANGE = 90

function IKST_GuardHooks.wrapTransfer()
    if IKST_GuardHooks.transferWrapped then
        return
    end
    IKST_GuardHooks.transferWrapped = true

    local vanillaTransfer = ISInventoryTransferAction.isValid
    ISInventoryTransferAction.isValid = function(self)
        if self and self.item and self.srcContainer and self.destContainer and self.character then
            if IKST_TransferRules and not IKST_TransferRules.transferAllowed(self.item, self.srcContainer, self.destContainer, self.character, false) then
                if self.stop then
                    self:stop()
                end
                return false
            end
        end
        return vanillaTransfer(self)
    end

    if ISGrabItemAction and ISGrabItemAction.isValid then
        local vanillaGrab = ISGrabItemAction.isValid
        ISGrabItemAction.isValid = function(self)
            if self and self.item and self.character then
                local worldItem = self.item
                local item = worldItem.getItem and worldItem:getItem() or worldItem
                local src = item and item.getContainer and item:getContainer() or nil
                local dest = self.character.getInventory and self.character:getInventory() or nil
                if item and IKST_TransferRules and not IKST_TransferRules.transferAllowed(item, src, dest, self.character, false) then
                    if self.stop then
                        self:stop()
                    end
                    return false
                end
            end
            return vanillaGrab(self)
        end
    end
end

function IKST_GuardHooks.safehouseActionBlocked(player, square, action, messageKey, fallback)
    if not player or not square or not action then
        return false
    end
    if IKST_Access.canUseTools(player) then
        return false
    end
    if not IKST_SafehouseClaim or not IKST_SafehouseClaim.canAtSquare then
        return false
    end
    local allowed = IKST_SafehouseClaim.canAtSquare(player, square, action)
    if allowed == false then
        IKST.notify(player, IKST.text(messageKey, fallback), false)
        return true
    end
    return false
end

function IKST_GuardHooks.applyCatchSync(player, args)
    if not player or not args then
        return
    end
    local md = player:getModData()
    md.IKST_caught = args.caught == true
    if md.IKST_caught then
        md.IKST_catchX = tonumber(args.x)
        md.IKST_catchY = tonumber(args.y)
        md.IKST_catchZ = tonumber(args.z) or 0
    else
        md.IKST_catchX = nil
        md.IKST_catchY = nil
        md.IKST_catchZ = nil
    end
    if player.setBlockMovement then
        player:setBlockMovement(md.IKST_caught)
    end
end

function IKST_GuardHooks.onPlayerUpdate(player)
    if not player or not player.isLocalPlayer or not player:isLocalPlayer() then
        return
    end
    local md = player:getModData()
    if md and md.IKST_caught then
        if player.setBlockMovement then
            player:setBlockMovement(true)
        end
        if md.IKST_catchX and md.IKST_catchY then
            if math.abs(player:getX() - md.IKST_catchX) > 0.3 or math.abs(player:getY() - md.IKST_catchY) > 0.3 then
                player:setX(md.IKST_catchX)
                player:setY(md.IKST_catchY)
                player:setZ(md.IKST_catchZ or 0)
            end
        end
    end
end

function IKST_GuardHooks.isBordersEnabled()
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        if not IKST_GuardHooks._shBordersSynced then
            return false
        end
        return IKST_GuardHooks._shBordersSnapshot == true
    end
    local data = ModData.getOrCreate("IKST_WorldRules")
    return data.showSafehouseBorders == true
end

function IKST_GuardHooks.setBordersEnabled(on)
    IKST_GuardHooks._shBordersSnapshot = on == true
    IKST_GuardHooks._shBordersSynced = true
    IKST_GuardHooks.forceSafehouseRefresh()
end

function IKST_GuardHooks.applyWorldRulesSnapshot(data)
    if not data then
        return
    end
    if data.showSafehouseBorders ~= nil then
        IKST_GuardHooks._shBordersSnapshot = data.showSafehouseBorders == true
        IKST_GuardHooks._shBordersSynced = true
    end
end

function IKST_GuardHooks.safehouseStillListed(sh)
    if not sh or not SafeHouse or not SafeHouse.getSafehouseList then
        return false
    end
    local list = SafeHouse.getSafehouseList()
    if list and list.contains and list:contains(sh) then
        return true
    end
    local onlineId = sh.getOnlineID and sh:getOnlineID()
    if onlineId and SafeHouse.getSafeHouse then
        local byId = SafeHouse.getSafeHouse(onlineId)
        if byId then
            return true
        end
    end
    return false
end

function IKST_GuardHooks.findSafehouseForRemoval(args)
    if not SafeHouse or not args then
        return nil
    end
    local onlineId = tonumber(args.removedOnlineId)
    if onlineId and SafeHouse.getSafeHouse then
        local byId = SafeHouse.getSafeHouse(onlineId)
        if byId then
            return byId
        end
    end
    local x = math.floor(tonumber(args.x) or 0)
    local y = math.floor(tonumber(args.y) or 0)
    local w = math.floor(tonumber(args.w) or 0)
    local h = math.floor(tonumber(args.h) or 0)
    if w > 0 and h > 0 and SafeHouse.getSafeHouse then
        return SafeHouse.getSafeHouse(x, y, w, h)
    end
    return nil
end

-- MP: server SafeHouse mutations do not push SyncSafehousePacket; mirror idempotently on clients.
function IKST_GuardHooks.applyVanillaSafehouseAdded(args)
    if not IKST or not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        return false
    end
    if not SafeHouse or not SafeHouse.addSafeHouse or not args then
        return false
    end
    local owner = args.owner
    if not owner or owner == "" then
        return false
    end
    local x = math.floor(tonumber(args.x) or 0)
    local y = math.floor(tonumber(args.y) or 0)
    local w = math.floor(tonumber(args.w) or 0)
    local h = math.floor(tonumber(args.h) or 0)
    if w < 1 or h < 1 then
        return false
    end
    local onlineId = tonumber(args.onlineId)
    if onlineId and SafeHouse.getSafeHouse then
        local byId = SafeHouse.getSafeHouse(onlineId)
        if byId then
            return true
        end
    end
    if SafeHouse.getSafeHouse then
        local existing = SafeHouse.getSafeHouse(x, y, w, h)
        if existing then
            return true
        end
    end
    local sh = SafeHouse.addSafeHouse(x, y, w, h, owner)
    if sh and args.title and args.title ~= "" and sh.setTitle then
        sh:setTitle(tostring(args.title))
    end
    if SafeHouse.updateSafehousePlayersConnected then
        SafeHouse.updateSafehousePlayersConnected()
    end
    IKST_GuardHooks.forceSafehouseRefresh()
    if not IKST_Debug then
        require "IKST_Debug"
    end
    if IKST_Debug and IKST_Debug.logEffect then
        local detail = "onlineId=" .. tostring(args.onlineId) .. " @" .. tostring(x) .. "," .. tostring(y)
        IKST_Debug.logEffect("safehouse", "clientVanillaAdd", detail, nil)
    end
    return sh ~= nil
end

-- MP: server removeSafeHouse does not push SyncSafehousePacket; mirror removal locally.
function IKST_GuardHooks.applyVanillaSafehouseRemoved(args)
    if not IKST or not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        return false
    end
    if not SafeHouse or not SafeHouse.removeSafeHouse then
        return false
    end
    local sh = IKST_GuardHooks.findSafehouseForRemoval(args)
    if not sh then
        return false
    end
    SafeHouse.removeSafeHouse(sh)
    if SafeHouse.updateSafehousePlayersConnected then
        SafeHouse.updateSafehousePlayersConnected()
    end
    IKST_GuardHooks.forceSafehouseRefresh()
    if not IKST_Debug then
        require "IKST_Debug"
    end
    if IKST_Debug and IKST_Debug.logEffect then
        local detail = "onlineId=" .. tostring(args and args.removedOnlineId)
        if args and args.x then
            detail = detail .. " @" .. tostring(args.x) .. "," .. tostring(args.y)
        end
        IKST_Debug.logEffect("safehouse", "clientVanillaRemove", detail, nil)
    end
    return true
end

function IKST_GuardHooks.closeStaleSafehouseUIs()
    if ISSafehouseUI and ISSafehouseUI.OnSafehousesChanged then
        ISSafehouseUI.OnSafehousesChanged()
    end
    if ISSafehousesList and ISSafehousesList.OnSafehousesChanged then
        ISSafehousesList.OnSafehousesChanged()
    end
    if ISAdminPanelUI and ISAdminPanelUI.OnSafehousesChanged then
        ISAdminPanelUI.OnSafehousesChanged()
    end
end

function IKST_GuardHooks.applyVanillaSafehouseMirror(args)
    if not args then
        return false
    end
    if args.action == "add" then
        return IKST_GuardHooks.applyVanillaSafehouseAdded(args)
    end
    if args.action == "remove" or args.removedOnlineId then
        return IKST_GuardHooks.applyVanillaSafehouseRemoved(args)
    end
    return false
end

function IKST_GuardHooks.forceSafehouseRefresh(args)
    IKST_GuardHooks._shLastTick = 0
    if not SafeHouse then
        return
    end
    if args then
        IKST_GuardHooks.applyVanillaSafehouseMirror(args)
    end
    if SafeHouse.updateSafehousePlayersConnected then
        SafeHouse.updateSafehousePlayersConnected()
    end
    local player = getPlayer and getPlayer()
    if player and SafeHouse.hasSafehouse then
        local mine = SafeHouse.hasSafehouse(player)
        if mine and not IKST_GuardHooks.safehouseStillListed(mine) then
            if SafeHouse.updateSafehousePlayersConnected then
                SafeHouse.updateSafehousePlayersConnected()
            end
        end
    end
    IKST_GuardHooks.closeStaleSafehouseUIs()
end

function IKST_GuardHooks.iterSafehouses(visitor)
    if not SafeHouse or not SafeHouse.getSafehouseList then
        return
    end
    local list = SafeHouse.getSafehouseList()
    if not list then
        return
    end
    if list.iterator then
        local it = list:iterator()
        if it and it.hasNext and it.next then
            while it:hasNext() do
                local sh = it:next()
                if sh then
                    visitor(sh)
                end
            end
        end
        return
    end
    if list.size and list.get then
        for i = 0, list:size() - 1 do
            local sh = list:get(i)
            if sh then
                visitor(sh)
            end
        end
    end
end

function IKST_GuardHooks.clearSafehouseHighlights()
    local cell = getCell and getCell()
    for key, floor in pairs(IKST_GuardHooks._shApplied) do
        if floor and floor.setHighlighted then
            floor:setHighlighted(false)
        end
        if cell and cell.getGridSquare then
            local sx, sy, sz = string.match(key, "^(%-?%d+),(%-?%d+),(%-?%d+)$")
            if sx and sy and sz then
                local sq = cell:getGridSquare(tonumber(sx), tonumber(sy), tonumber(sz))
                if sq and sq.setHighlight then
                    sq:setHighlight(false)
                end
            end
        end
    end
    IKST_GuardHooks._shApplied = {}
end

function IKST_GuardHooks.highlightSquare(cell, tx, ty, z, r, g, b, a)
    if not cell then
        return
    end
    local sq = cell:getGridSquare(tx, ty, z)
    if not sq or not sq.getFloor then
        return
    end
    local floor = sq:getFloor()
    if not floor then
        return
    end
    if floor.setHighlightColor then
        floor:setHighlightColor(r, g, b, a)
    end
    if floor.setHighlighted then
        floor:setHighlighted(true, false)
    end
    if sq.setHighlight then
        sq:setHighlight(true)
    end
    IKST_GuardHooks._shApplied[tostring(tx) .. "," .. tostring(ty) .. "," .. tostring(z)] = floor
end

function IKST_GuardHooks.rebuildSafehouseHighlights()
    IKST_GuardHooks.clearSafehouseHighlights()
    if not IKST_GuardHooks.isBordersEnabled() then
        return
    end
    local player = getPlayer and getPlayer()
    if not player then
        return
    end
    local px, py = player:getX(), player:getY()
    local cell = getCell and getCell()
    if not cell then
        return
    end
    local c = IKST_Chrome.colors.accent
    local r, g, b, a = c.r, c.g, c.b, 0.55

    IKST_GuardHooks.iterSafehouses(function(sh)
        if not sh.getX or not sh.getY or not sh.getW or not sh.getH then
            return
        end
        local x = sh:getX()
        local y = sh:getY()
        local w = sh:getW()
        local h = sh:getH()
        if w < 1 or h < 1 then
            return
        end
        local cx = x + (w * 0.5)
        local cy = y + (h * 0.5)
        if IsoUtils and IsoUtils.DistanceTo then
            if IsoUtils.DistanceTo(px, py, cx, cy) > IKST_GuardHooks.SH_VIEW_RANGE then
                return
            end
        end
        local x2 = x + w - 1
        local y2 = y + h - 1
        local borderOnly = (w * h) > 400
        local z = 0
        for ty = y, y2 do
            for tx = x, x2 do
                if not borderOnly or tx == x or tx == x2 or ty == y or ty == y2 then
                    IKST_GuardHooks.highlightSquare(cell, tx, ty, z, r, g, b, a)
                end
            end
        end
    end)
end

function IKST_GuardHooks.onTickSafehouses()
    local now = 0
    if getTimestampMs then
        now = getTimestampMs()
    end
    if now > 0 and (now - IKST_GuardHooks._shLastTick) < IKST_GuardHooks.SH_THROTTLE_MS then
        return
    end
    IKST_GuardHooks._shLastTick = now

    local enabled = IKST_GuardHooks.isBordersEnabled()
    if not enabled then
        if IKST_GuardHooks._shBorderOn then
            IKST_GuardHooks.clearSafehouseHighlights()
            IKST_GuardHooks._shBorderOn = false
        end
        return
    end
    IKST_GuardHooks._shBorderOn = true
    IKST_GuardHooks.rebuildSafehouseHighlights()
end

function IKST_GuardHooks.onRenderTickSafehouses()
    if not IKST_GuardHooks._shBorderOn then
        return
    end
    local c = IKST_Chrome.colors.accent
    local r, g, b, a = c.r, c.g, c.b, 0.55
    for _, floor in pairs(IKST_GuardHooks._shApplied) do
        if floor and floor.setHighlighted then
            floor:setHighlighted(true, false)
            if floor.setHighlightColor then
                floor:setHighlightColor(r, g, b, a)
            end
        end
    end
end

function IKST_GuardHooks.drawSafehouseBorders()
    IKST_GuardHooks.onTickSafehouses()
end

function IKST_GuardHooks.init()
    IKST_GuardHooks.wrapTransfer()
    if IKST_EnforcementTiles and IKST_EnforcementTiles.init then
        IKST_EnforcementTiles.init()
    end
end

if Events then
    if Events.OnGameBoot then
        Events.OnGameBoot.Add(IKST_GuardHooks.init)
    end
    if Events.OnPlayerUpdate then
        Events.OnPlayerUpdate.Add(IKST_GuardHooks.onPlayerUpdate)
    end
    if Events.OnTick then
        Events.OnTick.Add(IKST_GuardHooks.onTickSafehouses)
    end
    if Events.OnRenderTick then
        Events.OnRenderTick.Add(IKST_GuardHooks.onRenderTickSafehouses)
    end
    if Events.OnSafehousesChanged then
        Events.OnSafehousesChanged.Add(IKST_GuardHooks.forceSafehouseRefresh)
    end
end
