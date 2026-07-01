-- Shared command argument helpers (Tier C input hygiene).

require "IKST_Shared"
require "IKST_Access"

IKST_Args = IKST_Args or {}

function IKST_Args.readCoord(args, key)
    if not args then
        return nil
    end
    local v = tonumber(args[key])
    if v == nil then
        return nil
    end
    return math.floor(v)
end

function IKST_Args.mapSquareExists(x, y, z)
    if x == nil or y == nil then
        return false
    end
    if not getCell then
        return true
    end
    local cell = getCell()
    if not cell or not cell.getGridSquare then
        return true
    end
    z = tonumber(z) or 0
    return cell:getGridSquare(x, y, z) ~= nil
end

function IKST_Args.readRadius(args, key, default)
    default = default or IKST.RADIUS_PRESETS.M
    local r = tonumber(args and args[key or "radius"]) or default
    return IKST.clampRadius(r)
end

function IKST_Args.readAmount(args, key, minVal, maxVal)
    minVal = minVal or 0
    maxVal = maxVal or 999999999
    local v = tonumber(args and args[key or "amount"])
    if v == nil then
        return nil
    end
    v = math.floor(v)
    if v < minVal or v > maxVal then
        return nil
    end
    return v
end

function IKST_Args.readUsername(args, key)
    if not args then
        return nil
    end
    local name = args[key or "username"]
    if name == nil then
        return nil
    end
    name = tostring(name)
    name = string.gsub(name, "^%s*(.-)%s*$", "%1")
    if name == "" or #name > 64 then
        return nil
    end
    return name
end

function IKST_Args.readItemType(args, key)
    if not args then
        return nil
    end
    local t = args[key or "type"]
    if t == nil then
        return nil
    end
    t = tostring(t)
    if t == "" or #t > 128 then
        return nil
    end
    if string.find(t, "%.%.") or string.find(t, "^%.") then
        return nil
    end
    if getScriptManager and getScriptManager().FindItem then
        local item = getScriptManager():FindItem(t)
        if not item then
            return nil
        end
    end
    return t
end

function IKST_Args.readVehicleId(args, key)
    if not args then
        return nil
    end
    local id = tonumber(args[key or "vehicleId"])
    if id == nil or id < 0 or id > 2147483647 then
        return nil
    end
    return math.floor(id)
end

function IKST_Args.readPassword(args, key)
    if not args then
        return nil
    end
    local p = args[key or "password"]
    if p == nil then
        p = args.pass
    end
    if p == nil then
        return nil
    end
    p = tostring(p)
    if p == "" or #p > 32 then
        return nil
    end
    return p
end

function IKST_Args.staffZSpan(player)
    if player and IKST_Access and IKST_Access.canUseTools and IKST_Access.canUseTools(player) then
        return 4
    end
    return 1
end

function IKST_Args.actorNearCoord(player, x, y, z, maxDist)
    if not player or x == nil or y == nil then
        return false
    end
    maxDist = tonumber(maxDist) or 12
    z = tonumber(z) or 0
    local px = player:getX()
    local py = player:getY()
    local pz = player:getZ() or 0
    if math.abs(pz - z) > IKST_Args.staffZSpan(player) then
        return false
    end
    return IKST.distance2d(px, py, x, y) <= maxDist
end

function IKST_Args.summarize(args, command)
    if not args or type(args) ~= "table" then
        return ""
    end
    local parts = {}
    local skip = {
        password = true,
        pass = true,
    }
    local keys = { "x", "y", "z", "radius", "amount", "type", "count", "target", "username", "owner", "vehicleId", "preset", "hour", "kit", "scope", "itemId", "itemType" }
    for _, k in ipairs(keys) do
        if args[k] ~= nil and not skip[k] then
            parts[#parts + 1] = k .. "=" .. tostring(args[k])
        end
    end
    if command == IKST.CMD.lockTryUnlock or command == IKST.CMD.lockInstallKeypad or command == IKST.CMD.lockSetPassword then
        parts[#parts + 1] = "password=<redacted>"
    end
    return table.concat(parts, " ")
end
