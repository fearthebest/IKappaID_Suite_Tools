-- Server ModData: protected tiles, vehicles, dropboxes, readonly containers.

require "IKST_Shared"
require "IKST_Grid"

IKST_TileProtect = IKST_TileProtect or {}

function IKST_TileProtect.store()
    local data = ModData.getOrCreate("IKST_Protect")
    data.tiles = data.tiles or {}
    data.vehicles = data.vehicles or {}
    data.dropboxes = data.dropboxes or {}
    data.readonly = data.readonly or {}
    return data
end

function IKST_TileProtect.key(x, y, z)
    return tostring(math.floor(tonumber(x) or 0)) .. ":"
        .. tostring(math.floor(tonumber(y) or 0)) .. ":"
        .. tostring(tonumber(z) or 0)
end

function IKST_TileProtect.isTileProtected(x, y, z)
    local data = IKST_TileProtect.store()
    return data.tiles[IKST_TileProtect.key(x, y, z)] ~= nil
end

function IKST_TileProtect.protectTile(x, y, z, label)
    local data = IKST_TileProtect.store()
    local k = IKST_TileProtect.key(x, y, z)
    data.tiles[k] = { label = label or "protected", x = math.floor(x), y = math.floor(y), z = z }
    return true
end

function IKST_TileProtect.unprotectTile(x, y, z)
    local data = IKST_TileProtect.store()
    local k = IKST_TileProtect.key(x, y, z)
    if data.tiles[k] then
        data.tiles[k] = nil
        return true
    end
    return false
end

function IKST_TileProtect.protectRadius(cx, cy, cz, radius)
    local squares = IKST_Grid.squaresInRadius(cx, cy, cz, radius)
    local n = 0
    for _, sq in ipairs(squares) do
        if IKST_TileProtect.protectTile(sq:getX(), sq:getY(), sq:getZ(), "radius") then
            n = n + 1
        end
    end
    return n
end

function IKST_TileProtect.unprotectRadius(cx, cy, cz, radius)
    local squares = IKST_Grid.squaresInRadius(cx, cy, cz, radius)
    local n = 0
    for _, sq in ipairs(squares) do
        if IKST_TileProtect.unprotectTile(sq:getX(), sq:getY(), sq:getZ()) then
            n = n + 1
        end
    end
    return n
end

function IKST_TileProtect.listNearby(cx, cy, cz, radius)
    local out = {}
    local data = IKST_TileProtect.store()
    radius = tonumber(radius) or 30
    for _, entry in pairs(data.tiles) do
        if entry and entry.x then
            local dist = IKST.distance2d(cx, cy, entry.x, entry.y)
            if dist <= radius then
                out[#out + 1] = entry
            end
        end
    end
    table.sort(out, function(a, b)
        return IKST.distance2d(cx, cy, a.x, a.y) < IKST.distance2d(cx, cy, b.x, b.y)
    end)
    return out
end

function IKST_TileProtect.count()
    local n = 0
    for _ in pairs(IKST_TileProtect.store().tiles) do
        n = n + 1
    end
    return n
end

function IKST_TileProtect.isVehicleProtected(vehicleId)
    if vehicleId == nil then
        return false
    end
    return IKST_TileProtect.store().vehicles[tostring(vehicleId)] == true
end

function IKST_TileProtect.protectVehicle(vehicleId)
    if vehicleId == nil then
        return false
    end
    IKST_TileProtect.store().vehicles[tostring(vehicleId)] = true
    return true
end

function IKST_TileProtect.unprotectVehicle(vehicleId)
    if vehicleId == nil then
        return false
    end
    local k = tostring(vehicleId)
    if IKST_TileProtect.store().vehicles[k] then
        IKST_TileProtect.store().vehicles[k] = nil
        return true
    end
    return false
end

function IKST_TileProtect.setDropbox(x, y, z, owner)
    local k = IKST_TileProtect.key(x, y, z)
    if owner and owner ~= "" then
        IKST_TileProtect.store().dropboxes[k] = owner
    else
        IKST_TileProtect.store().dropboxes[k] = nil
    end
end

function IKST_TileProtect.getDropboxOwner(x, y, z)
    return IKST_TileProtect.store().dropboxes[IKST_TileProtect.key(x, y, z)]
end

function IKST_TileProtect.setReadonly(x, y, z, on)
    local k = IKST_TileProtect.key(x, y, z)
    if on then
        IKST_TileProtect.store().readonly[k] = true
    else
        IKST_TileProtect.store().readonly[k] = nil
    end
end

function IKST_TileProtect.isReadonly(x, y, z)
    return IKST_TileProtect.store().readonly[IKST_TileProtect.key(x, y, z)] == true
end
