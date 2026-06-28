if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Access"
require "IKST_Chrome"

IKST_GuardHooks = IKST_GuardHooks or {}
IKST_GuardHooks._shApplied = IKST_GuardHooks._shApplied or {}
IKST_GuardHooks._shLastTick = 0
IKST_GuardHooks._shBorderOn = false
IKST_GuardHooks.SH_THROTTLE_MS = 400
IKST_GuardHooks.SH_VIEW_RANGE = 90

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
    local data = ModData.getOrCreate("IKST_WorldRules")
    return data.showSafehouseBorders == true
end

function IKST_GuardHooks.setBordersEnabled(on)
    local data = ModData.getOrCreate("IKST_WorldRules")
    data.showSafehouseBorders = on == true
    IKST_GuardHooks.forceSafehouseRefresh()
end

function IKST_GuardHooks.forceSafehouseRefresh()
    IKST_GuardHooks._shLastTick = 0
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

if Events then
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
